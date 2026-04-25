# Developer Guide

Project: Payday Financial Control System

This guide explains the current Flutter project structure and the safe way to continue development.

## Current Setup

- Flutter app root: `lib/main.dart`
- App shell: `lib/app/app.dart`
- Bottom navigation: `lib/app/main_navigation.dart`
- App logo asset: `assets/images/app_logo.png`
- Android app name: `Payday Financial Control System`
- Supabase package: `supabase_flutter`
- Supabase initialization is in `lib/main.dart`

## Important Rules

- Make small, focused changes.
- Do not rewrite full files unless required.
- Do not change unrelated screens, widgets, routes, or state.
- Keep existing UI and logic unless a change is requested.
- Do not edit system or junction-linked folders:
  - `C:\Users\Lenovo\.android\avd`
  - `C:\Users\Lenovo\.gradle`
- Do not add packages unless they are needed for the requested feature.

## Folder Structure

The app uses a feature-first structure.

```text
lib/
  main.dart
  app/
  core/
  shared/
  features/
```

Use these folders like this:

- `app/`
  App-level setup, theme, routing, and navigation.

- `core/`
  Shared technical code such as constants, database setup, errors, and utilities.

- `shared/`
  Reusable models and widgets used by many features.

- `features/`
  Main app features. Each feature should keep its own screens, widgets, controllers, models, and repositories.

## Feature Folder Pattern

Each feature should follow this pattern:

```text
features/
  feature_name/
    presentation/
      screens/
      widgets/
    application/
    domain/
    data/
```

Use each layer like this:

- `presentation/screens/`
  Full screens shown to the user.

- `presentation/widgets/`
  Smaller UI pieces used by screens.

- `application/`
  Controllers and app logic.

- `domain/`
  Feature models and business objects.

- `data/`
  Repository classes and Supabase/database access.

## Current Main Screens

The first working screens are:

- `DashboardScreen`
- `TransactionsScreen`
- `CategoriesScreen`
- `SettingsScreen`

The bottom navigation currently lives in:

```text
lib/app/main_navigation.dart
```

When adding a screen to the bottom navigation, update only `main_navigation.dart` unless routing is added later.

## Supabase

Supabase is initialized in:

```text
lib/main.dart
```

Use this pattern when accessing Supabase:

```dart
final supabase = Supabase.instance.client;
```

Recommended place for Supabase queries:

```text
lib/features/<feature_name>/data/<feature_name>_repository.dart
```

Avoid putting database queries directly inside widgets unless it is only a quick temporary test.

## Assets

Registered assets are listed in:

```text
pubspec.yaml
```

Current logo:

```text
assets/images/app_logo.png
```

Use it in Flutter with:

```dart
Image.asset('assets/images/app_logo.png')
```

After adding new assets, run:

```powershell
flutter pub get
```

## Manual Commands

Run these commands manually from the project root:

```powershell
D:\Documents\Website Project\Flutter Projet\Andoid project\personal_tracker_expenses
```

### After Changing Dart Code

Format only the Dart files inside `lib/`:

```powershell
dart format lib
```

Check for Dart and Flutter errors:

```powershell
flutter analyze
```

Use `flutter analyze` most of the time because this is a Flutter app. It checks Dart code with Flutter-specific rules and project setup.

Optional Dart-only analyzer check:

```powershell
dart analyze
```

Run `dart analyze` only when you want a Dart-only check, usually after changing plain Dart logic files such as:

- `lib/core/utils/date_formatter.dart`
- `lib/core/utils/validators.dart`
- `lib/features/transactions/domain/transaction.dart`
- `lib/features/transactions/data/transaction_repository.dart`

You do not need to run `dart analyze` every time if you already run `flutter analyze`.

Run the app on the connected device or emulator:

```powershell
flutter run
```

### After Changing `pubspec.yaml`

Run this after adding packages, removing packages, or adding assets:

```powershell
flutter pub get
```

Then run:

```powershell
flutter analyze
flutter run
```

### When The App Acts Weird After Package Or Native Changes

Clean build files:

```powershell
flutter clean
```

Get packages again:

```powershell
flutter pub get
```

Run the app again:

```powershell
flutter run
```

Use `flutter clean` only when needed. It can make the next build slower.

### When The App Icon Or App Name Does Not Update

Uninstall the app from the emulator or phone first.

Then run:

```powershell
flutter run
```

Android may cache the old launcher icon or app name.

### When You Only Want To Check Formatting

This checks formatting without changing files:

```powershell
dart format lib --set-exit-if-changed
```

This is useful before committing code.

### When You Want To See Installed Packages

Show the package dependency tree:

```powershell
flutter pub deps
```

Use this only when debugging package issues.

### Common Safe Command Order

For normal Dart code changes:

```powershell
dart format lib
flutter analyze
flutter run
```

For dependency or asset changes:

```powershell
flutter pub get
dart format lib
flutter analyze
flutter run
```

For strange build/cache issues:

```powershell
flutter clean
flutter pub get
flutter run
```

## Development Workflow

1. Pick one feature or one bug.
2. Edit only the related file or folder.
3. Keep the UI unchanged unless the task asks for design changes.
4. Run formatting if Dart code changed:

```powershell
dart format lib
```

5. Run analyzer:

```powershell
flutter analyze
```

6. Run the app:

```powershell
flutter run
```

## Adding A New Feature

Create files inside the matching feature folder.

Example for a new reports feature:

```text
lib/features/reports/
  presentation/
    screens/
      reports_screen.dart
    widgets/
  application/
    reports_controller.dart
  domain/
    report.dart
  data/
    reports_repository.dart
```

Do not place feature-specific code in `shared/` unless more than one feature truly needs it.

## Naming Guide

- Screen files: `feature_screen.dart`
- Widget files: `feature_widget.dart`
- Controller files: `feature_controller.dart`
- Repository files: `feature_repository.dart`
- Model files: use the model name, for example `transaction.dart`

Use clear class names:

```dart
class TransactionsScreen extends StatelessWidget {}
class TransactionRepository {}
class TransactionController {}
```

## Commit Message Examples

```text
feat: add transaction form
fix: correct transaction navigation callback
docs: add developer guide
chore: format lib files
```

## Notes For Future Developers

- Keep the project beginner-friendly.
- Prefer readable code over complex patterns.
- Add comments only when they explain something non-obvious.
- Keep Supabase keys for client apps limited to publishable or anon keys.
- Never use a secret Supabase key inside Flutter app code.
