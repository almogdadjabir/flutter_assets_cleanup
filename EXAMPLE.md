# 📚 Usage Examples

## Basic Workflow

### 1. Initial Scan

```bash
flutter_asset_cleaner
```

**Output:**

```
Flutter Asset Cleaner v1.0.0

  Indexing assets      ━━━━━━━━━━━━━━━ 100% · 210 files
  Indexing code        ━━━━━━━━━━━━━━━ 100% · 809 files

  Parsing constants    ━━━━━━━━━━━━━━━ 100% · 345 identifiers

  Scanning references  ━━━━━━━━━━━━━━━ 100% · 809 files

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

### 2. Review Generated Report

Open `build/unused_assets_report.md`:

```markdown
# 🧹 Asset Cleanup Report

## 📊 Overview

| Metric                   |        Value |
| :----------------------- | -----------: |
| Total Assets             |          210 |
| ✅ Used                  |          204 |
| ❌ Unused                |            6 |
| 💾 Total Size            |      25.3 MB |
| ✓ Used Size              |      25.1 MB |
| 🎯 **Potential Savings** | **184.1 KB** |
```

### 3. Review Deletion Script

Check `delete_unused_assets.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Deleting 6 unused asset files..."
echo ""
echo "    50.2 KB  assets/images/unused_banner.png"
echo "    34.8 KB  assets/icons/old_icon.svg"
...
```

### 4. Delete Unused Assets

**Option A: Manual (Recommended)**

```bash
./delete_unused_assets.sh
```

**Option B: Automatic**

```bash
flutter_asset_cleaner --delete
```

## 🎯 Common Scenarios

### CI/CD Integration

**.github/workflows/asset_check.yml**

```yaml
name: Asset Check

on: [push, pull_request]

jobs:
  check-assets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1

      - name: Install Flutter Asset Cleaner
        run: dart pub global activate flutter_asset_cleaner

      - name: Run asset scan
        run: flutter_asset_cleaner --no-color --quiet

      - name: Upload report
        uses: actions/upload-artifact@v3
        with:
          name: asset-report
          path: build/unused_assets_report.md
```

### Pre-commit Hook

**.git/hooks/pre-commit**

```bash
#!/bin/bash

echo "Checking for unused assets..."
flutter_asset_cleaner --quiet

# Read unused count from output
# Fail if too many unused assets
```

### Weekly Cleanup Script

**scripts/weekly_cleanup.sh**

```bash
#!/bin/bash

echo "=== Weekly Asset Cleanup ==="
date

# Run scan
flutter_asset_cleaner

# Send report to Slack
curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"Asset cleanup report generated\"}" \
  $SLACK_WEBHOOK_URL

echo "Report available at build/unused_assets_report.md"
```

## 🏢 Team Workflow

### Development Team

1. **Developer** runs scan before PR:

   ```bash
   flutter_asset_cleaner
   ```

2. **Review** unused assets in report

3. **Commit** deletion script:

   ```bash
   git add delete_unused_assets.sh
   git commit -m "chore: add unused assets cleanup script"
   ```

4. **Team Lead** reviews and approves

5. **Execute** cleanup:
   ```bash
   ./delete_unused_assets.sh
   git add -A
   git commit -m "chore: remove unused assets"
   ```

## 🎨 Asset Organization Examples

### Recommended Structure

```dart
// lib/constants/app_assets.dart

class AppIcons {
  static const String logo = 'assets/icons/logo.svg';
  static const String home = 'assets/icons/home.svg';
  static const String profile = 'assets/icons/profile.svg';
}

class Images {
  static const String background = 'assets/images/bg.png';
  static const String placeholder = 'assets/images/placeholder.png';
}

class LottieAnimations {
  static const String loading = 'assets/animations/loading.json';
  static const String success = 'assets/animations/success.json';
}

// Aliases for convenience
class AppAssets {
  static const String logo = AppIcons.logo;
  static const String loadingAnimation = LottieAnimations.loading;
}
```

### Usage in Code

```dart
// Direct constant usage
Image.asset(AppIcons.logo)

// Through alias
SvgPicture.asset(AppAssets.logo)

// Literal path (also detected)
Image.asset('assets/images/background.png')
```

## 🔧 Advanced Usage

### Custom Bar Width

For different terminal sizes:

```bash
# Narrow terminals
flutter_asset_cleaner --bar=30

# Wide terminals
flutter_asset_cleaner --bar=80
```

### Quiet Mode for Scripts

```bash
flutter_asset_cleaner --quiet > scan.log
```

### No Color for Logs

```bash
flutter_asset_cleaner --no-color >> build.log
```

### Combine Options

```bash
flutter_asset_cleaner --quiet --no-color --bar=40
```

## 📱 Real-World Example

### Before Cleanup

```
app.apk size: 15.2 MB
- 210 assets (25.3 MB uncompressed)
- Including 6 unused assets (184 KB)
```

### After Cleanup

```bash
flutter_asset_cleaner --delete
flutter build apk --release
```

```
app.apk size: 15.1 MB  ✓ (-100 KB)
- 204 assets (25.1 MB uncompressed)
- 0 unused assets
```

## 🎓 Tips & Tricks

### 1. Run Regularly

```bash
# Add to package.json scripts or Makefile
make clean-assets:
	flutter_asset_cleaner
```

### 2. Check Before Releases

```bash
# Pre-release checklist
flutter_asset_cleaner
flutter analyze
flutter test
```

### 3. Archive Unused Assets

Instead of deleting, archive them:

```bash
mkdir -p archive/unused_assets_$(date +%Y%m%d)
# Modify delete script to move instead of rm
```

### 4. Compare Between Branches

```bash
git checkout main
flutter_asset_cleaner > main_report.txt

git checkout feature/new-ui
flutter_asset_cleaner > feature_report.txt

diff main_report.txt feature_report.txt
```

## 🚨 Important Notes

### What Gets Detected

✅ Static constant references

```dart
Image.asset(AppIcons.logo)
```

✅ Literal string paths

```dart
Image.asset('assets/images/bg.png')
```

✅ Aliased references

```dart
SvgPicture.asset(AppAssets.logo)
```

### What Doesn't Get Detected

❌ Dynamic path construction

```dart
Image.asset('assets/images/$imageName.png')
```

❌ Native code references (Android/iOS)

```kotlin
R.drawable.splash_screen
```

❌ Assets loaded from network/backend configuration

### Handling Edge Cases

If you have dynamically loaded assets, add them to an exclusion list:

```dart
// Keep these assets even if unused in Dart code
class KeepAssets {
  static const dynamicAssets = [
    'assets/images/dynamic_1.png',
    'assets/images/dynamic_2.png',
  ];
}
```

## 💡 Best Practices

1. ✅ Run scan before every release
2. ✅ Commit deletion scripts for team review
3. ✅ Keep assets organized in const classes
4. ✅ Use version control before `--delete`
5. ✅ Document why certain "unused" assets should be kept
6. ✅ Archive instead of delete for important projects
7. ✅ Run in CI/CD to catch asset bloat early

---

Need more examples? Check the [GitHub repository](https://github.com/yourusername/flutter_asset_cleaner) or open an issue!
