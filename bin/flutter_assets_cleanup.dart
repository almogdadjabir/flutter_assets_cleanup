import 'dart:io';
import 'dart:math';

const String kVersion = '1.0.0';
const String kPackageName = 'Flutter Asset Cleaner';

final class Config {
  static const assetDirs = ['assets'];
  static const codeRoots = ['lib', 'test', 'integration_test', 'bin'];
  static const ignoreDirs = {
    '.git',
    '.dart_tool',
    'build',
    'ios/Pods',
    'android/.gradle',
    'android/build'
  };
  static const assetExts = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.svg',
    '.json',
    '.gif'
  };
}

final class CliArgs {
  final bool delete;
  final bool writeScript;
  final bool noColor;
  final bool quiet;
  final int progressBarWidth;

  const CliArgs({
    required this.delete,
    required this.writeScript,
    required this.noColor,
    required this.quiet,
    required this.progressBarWidth,
  });

  factory CliArgs.parse(List<String> args) {
    final delete = args.contains('--delete');
    final writeScript = args.contains('--write-script') || !delete;
    final noColor =
        args.contains('--no-color') || Platform.environment.containsKey('NO_COLOR');
    final quiet = args.contains('--quiet');

    int barWidth = 50;
    for (final arg in args) {
      if (arg.startsWith('--bar=')) {
        final value = int.tryParse(arg.split('=').last);
        if (value != null && value >= 10 && value <= 200) {
          barWidth = value;
        }
      }
    }

    return CliArgs(
      delete: delete,
      writeScript: writeScript,
      noColor: noColor,
      quiet: quiet,
      progressBarWidth: barWidth,
    );
  }
}

final class TerminalUI {
  final bool _enableColor;
  final bool _quiet;
  final int _barWidth;

  const TerminalUI(this._enableColor, this._quiet, this._barWidth);

  String get _reset => _enableColor ? '\x1B[0m' : '';
  String _style(String text, String code) =>
      _enableColor ? '\x1B[${code}m$text$_reset' : text;

  String bold(String text) => _style(text, '1');
  String dim(String text) => _style(text, '2');
  String green(String text) => _style(text, '32');
  String cyan(String text) => _style(text, '36');
  String yellow(String text) => _style(text, '33');

  void header() {
    if (_quiet) return;
    stdout.writeln('\n${bold(kPackageName)} ${dim('v$kVersion')}\n');
  }

  void progressBar(String label, int current, int total, {String? unit}) {
    final progress = total == 0 ? 1.0 : (current / total).clamp(0.0, 1.0);
    final filled = (_barWidth * progress).floor();
    final empty = _barWidth - filled;

    final bar = '━' * filled + dim('━' * empty);
    final percentage = (progress * 100).toStringAsFixed(0).padLeft(3);
    final counter = unit != null ? '$current $unit' : '$current/$total';

    stdout.write('\r  ${label.padRight(22)} $bar ${dim(percentage)}% ${dim('·')} ${cyan(counter)}   ');
    if (current >= total) stdout.writeln();
  }

  void result(String label, String value) {
    stdout.writeln('  ${label.padRight(22)} ${cyan(value)}');
  }

  void success(String message) {
    stdout.writeln('  ${green('✓')} $message');
  }

  void warning(String message) {
    stdout.writeln('  ${yellow('!')} $message');
  }

  void spacer() {
    stdout.writeln();
  }

  void summary(Map<String, String> data) {
    stdout.writeln('\n${bold('Summary')}');
    final maxKeyLength = data.keys.map((k) => k.length).reduce(max);

    for (final entry in data.entries) {
      final key = entry.key.padRight(maxKeyLength);
      final isHighlight = entry.key.contains('Reclaim') || entry.key.contains('Unused');
      final value = isHighlight ? green(entry.value) : entry.value;
      stdout.writeln('  ${dim(key)}  $value');
    }
    stdout.writeln();
  }
}

final class AssetReference {
  final String identifier;
  final String filePath;
  final Set<String> referencedInFiles = {};
  int occurrenceCount = 0;
  int sizeBytes = 0;

  AssetReference(this.identifier, this.filePath, {this.sizeBytes = 0});

  bool get isUsed => occurrenceCount > 0;
}

final class AssetScanner {
  final TerminalUI _ui;

  const AssetScanner(this._ui);

  List<String> scanAssetFiles() {
    final assets = <String>[];

    for (final dir in Config.assetDirs) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        final path = entity.path.replaceAll('\\', '/');
        final extension = path.substring(path.lastIndexOf('.')).toLowerCase();

        if (Config.assetExts.contains(extension)) {
          assets.add(path);
        }
      }
    }

    return assets..sort();
  }

  List<String> scanCodeFiles() {
    final codeFiles = <String>[];

    bool shouldSkip(String path) =>
        Config.ignoreDirs.any((dir) => path.contains('/$dir/'));

    for (final root in Config.codeRoots) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        final path = entity.path.replaceAll('\\', '/');
        if (shouldSkip(path)) continue;

        if (path.endsWith('.dart') ||
            path.endsWith('.yaml') ||
            path.endsWith('.md')) {
          codeFiles.add(path);
        }
      }
    }

    return codeFiles..sort();
  }

  Future<Map<String, String>> parseAssetConstants() async {
    final definitionFiles = await _findAssetDefinitionFiles();
    final identifierToPath = <String, String>{};
    final directPathMap = <String, String>{};
    final aliasMap = <String, String>{};

    const directClasses = {'AppIcons', 'Images', 'LottieAnimations'};
    const aliasClasses = {'AppAssets'};

    for (final file in definitionFiles) {
      final content = await File(file).readAsString();

      for (final className in directClasses) {
        final classPattern =
        RegExp(r'class\s+' + className + r'\b[^{]*\{([\s\S]*?)\}', multiLine: true);
        final classMatch = classPattern.firstMatch(content);
        if (classMatch == null) continue;

        final classBody = classMatch.group(1)!;
        final fieldPattern =
        RegExp(r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']+)';");

        for (final fieldMatch in fieldPattern.allMatches(classBody)) {
          final fieldName = fieldMatch.group(1)!;
          final assetPath = fieldMatch.group(2)!;

          if (assetPath.startsWith('assets/')) {
            directPathMap['$className.$fieldName'] = assetPath;
          }
        }
      }

      for (final className in aliasClasses) {
        final classPattern =
        RegExp(r'class\s+' + className + r'\b[^{]*\{([\s\S]*?)\}', multiLine: true);
        final classMatch = classPattern.firstMatch(content);
        if (classMatch == null) continue;

        final classBody = classMatch.group(1)!;
        final aliasPattern = RegExp(
            r"static\s+const\s+String\s+(\w+)\s*=\s*(AppIcons|Images|LottieAnimations)\.(\w+);");

        for (final aliasMatch in aliasPattern.allMatches(classBody)) {
          final aliasName = aliasMatch.group(1)!;
          final targetClass = aliasMatch.group(2)!;
          final targetField = aliasMatch.group(3)!;
          aliasMap['$className.$aliasName'] = '$targetClass.$targetField';
        }
      }
    }

    for (final entry in aliasMap.entries) {
      final targetPath = directPathMap[entry.value];
      if (targetPath != null) {
        identifierToPath[entry.key] = targetPath;
      }
    }

    identifierToPath.addAll(directPathMap);
    return identifierToPath;
  }

  Future<List<String>> _findAssetDefinitionFiles() async {
    final files = <String>[];
    final libDirectory = Directory('lib');
    if (!libDirectory.existsSync()) return files;

    for (final entity in libDirectory.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final content = await File(entity.path).readAsString();
      if (content.contains('class AppAssets') ||
          content.contains('class AppIcons') ||
          content.contains('class Images') ||
          content.contains('class LottieAnimations')) {
        files.add(entity.path.replaceAll('\\', '/'));
      }
    }

    return files;
  }
}

final class UsageAnalyzer {
  final TerminalUI _ui;

  const UsageAnalyzer(this._ui);

  Future<void> analyzeUsage(
      List<String> codeFiles,
      Map<String, AssetReference> references,
      Map<String, Set<String>> pathToIdentifiers,
      ) async {
    final identifierPrefixes = [
      'AppAssets.',
      'AppIcons.',
      'Images.',
      'LottieAnimations.'
    ];

    final identifiers =
    references.keys.where((key) => !key.startsWith('PATH::')).toList();

    final identifierRegexMap = <String, RegExp>{
      for (final id in identifiers) id: RegExp(r'\b' + RegExp.escape(id) + r'\b')
    };

    final literalPaths = references.entries
        .where((entry) => entry.key.startsWith('PATH::'))
        .map((entry) => entry.value.filePath)
        .toList();

    final literalPathRegexMap = <String, RegExp>{
      for (final path in literalPaths) path: RegExp(RegExp.escape(path))
    };

    int processedCount = 0;

    for (final codeFile in codeFiles) {
      final content = await File(codeFile).readAsString();

      if (identifierPrefixes.any((prefix) => content.contains(prefix))) {
        for (final identifier in identifiers) {
          final className = identifier.split('.').first;
          if (!content.contains(className)) continue;

          final regex = identifierRegexMap[identifier]!;
          final matches = regex.allMatches(content);

          if (matches.isNotEmpty) {
            final ref = references[identifier]!;
            ref.occurrenceCount += matches.length;
            ref.referencedInFiles.add(codeFile);
          }
        }
      }

      if (content.contains('assets/')) {
        for (final path in literalPaths) {
          if (!content.contains(path)) continue;

          final regex = literalPathRegexMap[path]!;
          final matchCount = regex.allMatches(content).length;

          if (matchCount > 0) {
            final ref = references['PATH::$path']!;
            ref.occurrenceCount += matchCount;
            ref.referencedInFiles.add(codeFile);
          }
        }
      }

      processedCount++;
      if (processedCount % 50 == 0 || processedCount == codeFiles.length) {
        _ui.progressBar('Scanning references', processedCount, codeFiles.length, unit: 'files');
      }
    }
  }
}

final class ReportGenerator {
  final TerminalUI _ui;

  const ReportGenerator(this._ui);

  Future<String> generateMarkdownReport({
    required Set<String> unusedFiles,
    required Set<String> usedFiles,
    required Map<String, Set<String>> pathToIdentifiers,
    required Map<String, int> fileSizes,
    required int totalBytes,
    required int usedBytes,
    required int unusedBytes,
  }) async {
    final buildDir = Directory('build')..createSync(recursive: true);
    final reportFile = File('build/unused_assets_report.md');

    final heaviestUnused = unusedFiles.toList()
      ..sort((a, b) => (fileSizes[b] ?? 0).compareTo(fileSizes[a] ?? 0));

    final byExtension = <String, Map<String, int>>{};
    for (final path in [...unusedFiles, ...usedFiles]) {
      final ext = _getExtension(path);
      byExtension.putIfAbsent(ext, () => {'count': 0, 'bytes': 0});
      byExtension[ext]!['count'] = byExtension[ext]!['count']! + 1;
      byExtension[ext]!['bytes'] = byExtension[ext]!['bytes']! + (fileSizes[path] ?? 0);
    }

    final buffer = StringBuffer()
      ..writeln('# 🧹 Asset Cleanup Report')
      ..writeln()
      ..writeln('Generated by **$kPackageName v$kVersion**')
      ..writeln()
      ..writeln('## 📊 Overview')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|:---|---:|')
      ..writeln('| Total Assets | ${unusedFiles.length + usedFiles.length} |')
      ..writeln('| ✅ Used | ${usedFiles.length} |')
      ..writeln('| ❌ Unused | ${unusedFiles.length} |')
      ..writeln('| 💾 Total Size | ${_formatBytes(totalBytes)} |')
      ..writeln('| ✓ Used Size | ${_formatBytes(usedBytes)} |')
      ..writeln('| 🎯 **Potential Savings** | **${_formatBytes(unusedBytes)}** |')
      ..writeln()
      ..writeln('## 📁 Breakdown by Extension')
      ..writeln()
      ..writeln('| Extension | Files | Size |')
      ..writeln('|:---|---:|---:|');

    final sortedExtensions = byExtension.keys.toList()..sort();
    for (final ext in sortedExtensions) {
      final data = byExtension[ext]!;
      buffer.writeln(
          '| `$ext` | ${data['count']} | ${_formatBytes(data['bytes']!)} |');
    }

    buffer
      ..writeln()
      ..writeln('## 🏋️ Top 20 Heaviest Unused Files')
      ..writeln()
      ..writeln('| File | Size | Identifiers |')
      ..writeln('|:---|---:|:---|');

    for (final path in heaviestUnused.take(20)) {
      final identifiers = pathToIdentifiers[path]?.join(', ') ?? '—';
      buffer.writeln(
          '| `$path` | ${_formatBytes(fileSizes[path] ?? 0)} | $identifiers |');
    }

    buffer
      ..writeln()
      ..writeln('## 📝 Complete Unused Files List')
      ..writeln()
      ..writeln('> Total: **${unusedFiles.length}** files')
      ..writeln();

    final sortedUnused = unusedFiles.toList()..sort();
    for (final path in sortedUnused) {
      final identifiers = pathToIdentifiers[path];
      final note =
      identifiers != null && identifiers.isNotEmpty ? ' _(${identifiers.join(', ')})_' : '';
      buffer.writeln('- `$path`$note');
    }

    buffer
      ..writeln()
      ..writeln('## ℹ️ Notes')
      ..writeln()
      ..writeln(
          '- **Used** assets are referenced via identifiers (AppAssets/AppIcons/Images/LottieAnimations) or literal `assets/...` paths in your codebase.')
      ..writeln('- Asset class definitions are not counted as usage.')
      ..writeln(
          '- If you reference assets from native code (Android/iOS), manage them manually.')
      ..writeln('- Review the delete script before execution: `./delete_unused_assets.sh`');

    await reportFile.writeAsString(buffer.toString());
    return reportFile.path;
  }

  String generateDeleteScript(
      Set<String> unusedFiles,
      Map<String, int> fileSizes,
      ) {
    final script = StringBuffer()
      ..writeln('#!/usr/bin/env bash')
      ..writeln('set -euo pipefail')
      ..writeln('#')
      ..writeln('# Asset Cleanup Script')
      ..writeln('# Generated by $kPackageName v$kVersion')
      ..writeln('#')
      ..writeln('# ⚠️  REVIEW BEFORE RUNNING')
      ..writeln('# Run from project root directory')
      ..writeln('#')
      ..writeln()
      ..writeln('echo "🧹 Deleting ${unusedFiles.length} unused asset files..."')
      ..writeln('echo ""');

    final sortedBySize = unusedFiles.toList()
      ..sort((a, b) => (fileSizes[b] ?? 0).compareTo(fileSizes[a] ?? 0));

    for (final path in sortedBySize) {
      final size = _formatBytes(fileSizes[path] ?? 0).padLeft(10);
      script
        ..writeln('echo "  $size  $path"')
        ..writeln('rm -f ${_escapeShellArg(path)}');
    }

    script
      ..writeln()
      ..writeln('echo ""')
      ..writeln('echo "✓ Cleanup complete!"');

    return script.toString();
  }

  String _getExtension(String path) {
    final index = path.lastIndexOf('.');
    return index >= 0 ? path.substring(index).toLowerCase() : '';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB'];
    final magnitude = (log(bytes) / log(1024)).floor();
    final value = bytes / pow(1024, magnitude);

    return '${value.toStringAsFixed(magnitude == 0 ? 0 : 1)} ${units[magnitude]}';
  }

  String _escapeShellArg(String arg) {
    if (Platform.isWindows) return arg;
    return arg.replaceAll("'", r"'\''");
  }
}

void main(List<String> arguments) async {
  final args = CliArgs.parse(arguments);
  final ui = TerminalUI(!args.noColor, args.quiet, args.progressBarWidth);
  final scanner = AssetScanner(ui);
  final analyzer = UsageAnalyzer(ui);
  final reporter = ReportGenerator(ui);

  final totalStopwatch = Stopwatch()..start();

  ui.header();

  final assetFiles = scanner.scanAssetFiles();
  ui.progressBar('Indexing assets', assetFiles.length, assetFiles.length, unit: 'files');

  final codeFiles = scanner.scanCodeFiles();
  ui.progressBar('Indexing code', codeFiles.length, codeFiles.length, unit: 'files');

  ui.spacer();

  final fileSizes = <String, int>{
    for (final path in assetFiles) path: File(path).lengthSync()
  };

  final identifierToPath = await scanner.parseAssetConstants();
  final pathToIdentifiers = <String, Set<String>>{};

  for (final entry in identifierToPath.entries) {
    pathToIdentifiers.putIfAbsent(entry.value, () => <String>{}).add(entry.key);
  }

  ui.progressBar('Parsing constants', identifierToPath.length, identifierToPath.length, unit: 'identifiers');

  ui.spacer();

  final references = <String, AssetReference>{};
  for (final assetPath in assetFiles) {
    references['PATH::$assetPath'] = AssetReference(
      'PATH::$assetPath',
      assetPath,
      sizeBytes: fileSizes[assetPath] ?? 0,
    );

    final identifiers = pathToIdentifiers[assetPath];
    if (identifiers != null) {
      for (final id in identifiers) {
        references[id] = AssetReference(
          id,
          assetPath,
          sizeBytes: fileSizes[assetPath] ?? 0,
        );
      }
    }
  }

  await analyzer.analyzeUsage(codeFiles, references, pathToIdentifiers);

  final usedFiles = <String>{};
  final unusedFiles = <String>{};

  for (final assetPath in assetFiles) {
    final relatedRefs = <AssetReference>[
      references['PATH::$assetPath']!,
      ...?pathToIdentifiers[assetPath]?.map((id) => references[id]!),
    ];

    final isUsed = relatedRefs.any((ref) => ref.isUsed);
    (isUsed ? usedFiles : unusedFiles).add(assetPath);
  }

  ui.spacer();

  final usedBytes = usedFiles.fold<int>(0, (sum, path) => sum + (fileSizes[path] ?? 0));
  final unusedBytes = unusedFiles.fold<int>(0, (sum, path) => sum + (fileSizes[path] ?? 0));
  final totalBytes = usedBytes + unusedBytes;

  final reportPath = await reporter.generateMarkdownReport(
    unusedFiles: unusedFiles,
    usedFiles: usedFiles,
    pathToIdentifiers: pathToIdentifiers,
    fileSizes: fileSizes,
    totalBytes: totalBytes,
    usedBytes: usedBytes,
    unusedBytes: unusedBytes,
  );

  if (args.writeScript) {
    final scriptContent = reporter.generateDeleteScript(unusedFiles, fileSizes);
    final scriptFile = File('delete_unused_assets.sh')
      ..writeAsStringSync(scriptContent);

    try {
      Process.runSync('chmod', ['+x', scriptFile.path]);
    } catch (_) {}
  }

  if (args.delete && unusedFiles.isNotEmpty) {
    ui.warning('Deleting ${unusedFiles.length} unused files...');
    for (final path in unusedFiles) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
    ui.success('Files deleted');
  }

  final missingFiles = pathToIdentifiers.keys.where((path) => !File(path).existsSync()).toList();
  if (missingFiles.isNotEmpty) {
    ui.warning('${missingFiles.length} identifiers point to missing files');
  }

  ui.summary({
    'Total assets': '${assetFiles.length}',
    'Used': '${usedFiles.length}',
    'Unused': '${unusedFiles.length}',
    'Total size': reporter._formatBytes(totalBytes),
    'Used size': reporter._formatBytes(usedBytes),
    'Potential reclaim': reporter._formatBytes(unusedBytes),
    'Time': '${totalStopwatch.elapsed.inSeconds}s',
  });

  ui.success('Report saved to $reportPath');
  if (args.writeScript) {
    ui.success('Script saved to delete_unused_assets.sh');
  }
}