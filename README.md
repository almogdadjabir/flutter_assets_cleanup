# 🧹 Flutter Assets Cleanup

[![pub package](https://img.shields.io/pub/v/flutter_assets_cleanup.svg)](https://pub.dev/packages/flutter_assets_cleanup)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A powerful command-line tool to detect and remove unused assets from your Flutter projects. Keep your app bundle size optimized by identifying assets that are no longer referenced in your codebase.

## ✨ Features

- 🔍 **Smart Detection** - Finds assets referenced via constants (`AppAssets`, `AppIcons`, `Images`, `LottieAnimations`) and literal paths
- 📊 **Detailed Reports** - Generates comprehensive Markdown reports with size breakdowns
- 🎯 **Safe Cleanup** - Creates deletion scripts for review before removing files
- ⚡ **Fast Performance** - Efficiently scans large codebases
- 🎨 **Beautiful Output** - Clean, colorful terminal interface with progress bars
- 📦 **Size Analysis** - Shows potential space savings

## 📸 Demo

```
Flutter Asset Cleaner v1.0.0

  Indexing assets      ━━━━━━━━━━━━━━━━━━━━━━━━━ 100% · 210 files
  Indexing code        ━━━━━━━━━━━━━━━━━━━━━━━━━ 100% · 809 files

  Parsing constants    ━━━━━━━━━━━━━━━━━━━━━━━━━ 100% · 345 identifiers

  Scanning references  ━━━━━━━━━━━━━━━━━━━━━━━━━ 100% · 809 files

Summary
  Total assets          210
  Used                  204
  Unused                6
  Total size            25.3 MB
  Used size             25.1 MB
  Potential reclaim     184.1 KB
  Time                  2s

  ✓ Report saved to build/unused_assets_report.md
  ✓ Script saved to delete_unused_assets.sh
```

## 🚀 Installation

### Global Installation (Recommended)

```bash
dart pub global activate flutter_assets_cleanup
```

### As Dev Dependency

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_assets_cleanup: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## 📖 Usage

### Basic Usage

```bash
# Navigate to your Flutter project
cd /path/to/your/flutter/project

# Run the scan
flutter_assets_cleanup
```

### Command Line Options

| Option           | Description                                     |
| ---------------- | ----------------------------------------------- |
| _(no flags)_     | Dry run - generates report without deleting     |
| `--delete`       | Actually delete unused files (⚠️ commit first!) |
| `--write-script` | Generate deletion script (default: true)        |
| `--no-color`     | Disable colored output (for CI/CD)              |
| `--quiet`        | Reduce console output                           |
| `--bar=N`        | Set progress bar width (10-200, default: 50)    |

### Examples

```bash
# Scan and generate report
flutter_assets_cleanup

# Custom progress bar width
flutter_assets_cleanup --bar=60

# Quiet mode for CI/CD
flutter_assets_cleanup --quiet --no-color

# Delete unused assets (after review!)
flutter_assets_cleanup --delete
```

## 🎯 How It Works

1. **Discovery** - Scans your `assets/` directory for all image and animation files
2. **Parsing** - Extracts asset constants from your code (AppAssets, AppIcons, Images, LottieAnimations)
3. **Analysis** - Scans your entire codebase for references to these assets
4. **Reporting** - Generates detailed reports and safe deletion scripts

### Supported Asset Patterns

**Constant-based references:**

```dart
class AppIcons {
  static const String logo = 'assets/icons/logo.svg';
}

// Usage
Image.asset(AppIcons.logo)
```

**Literal path references:**

```dart
Image.asset('assets/images/background.png')
```

**Alias references:**

```dart
class AppAssets {
  static const String logo = AppIcons.logo;
}
```

## 📊 Generated Output

### Markdown Report (`build/unused_assets_report.md`)

- Overview with statistics
- Size breakdown by file extension
- List of heaviest unused files
- Complete unused assets list with identifiers

### Deletion Script (`delete_unused_assets.sh`)

- Reviewable bash script
- Lists all files to be deleted with sizes
- Can be run manually or committed for team review

## 🔧 Project Structure

Your project should have:

```
your_flutter_app/
├── assets/
│   ├── icons/
│   ├── images/
│   └── animations/
├── lib/
│   └── constants/
│       └── app_assets.dart  # Your asset constants
└── pubspec.yaml
```

## 💡 Best Practices

1. ✅ **Always commit** your changes before using `--delete`
2. ✅ **Review the report** before deleting anything
3. ✅ **Use constants** for asset references (AppIcons, Images, etc.)
4. ✅ **Run regularly** to prevent asset bloat
5. ✅ **Check native code** - Assets used in Android/iOS won't be detected

## ⚠️ Important Notes

### What Gets Detected ✅

- Static constant references (AppIcons.logo)
- Literal string paths ('assets/images/bg.png')
- Aliased references

### What Doesn't Get Detected ❌

- Dynamic path construction (`'assets/$variable.png'`)
- Native code references (Android/iOS)
- Assets loaded from configuration/API

## 🤔 FAQ

**Q: Will this detect assets used in native code?**  
A: No, only Dart code is scanned. Keep native assets manually.

**Q: What about dynamically constructed paths?**  
A: Only literal strings and constants are detected.

**Q: Can I undo deletions?**  
A: Use version control (git). Always commit before using `--delete`.

## 📄 License

MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🐛 Issues

Found a bug? Have a feature request? Please open an issue on [GitHub]([https://github.com/almogdadjabir/flutter_assets_cleanup/issues).

## ⭐ Show Your Support

If this tool helps you, give it a ⭐ on GitHub!

---

Made with ❤️ for the Flutter community
