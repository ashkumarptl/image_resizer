# Development Rules & Coding Standards

## 1. Core Principles
1. **Zero UI Freeze:** No image decoding, resizing, compression, or file encoding can run directly on the UI/main thread. Always use `compute()` or dedicated Dart `Isolate`.
2. **Offline-First & Privacy First:** No user image, thumbnail, or metadata may ever be transmitted over network connections.
3. **No Unhandled Errors:** All file operations and image processing tasks must be wrapped in robust `try/catch` handlers with user-friendly error banners/snackbars.
4. **Clean Code & Strong Typing:** Avoid `dynamic` types. Always define explicit parameter models, return types, and immutable state classes.

---

## 2. Flutter & Dart Best Practices
- **Flutter Version Compatibility:** Target Flutter 3.29+ / Dart 3.7+ with strict null-safety.
- **Linter Adherence:** Zero warnings or errors against `flutter_lints` and `analysis_options.yaml`.
- **Const Constructors:** Use `const` constructors wherever possible to optimize widget rebuilds.
- **Naming Conventions:**
  - Files: `snake_case.dart`
  - Classes & Enums: `PascalCase`
  - Variables, Methods, Parameters: `camelCase`
  - Constants: `kCamelCase` or `kSCREAMING_SNAKE_CASE` (prefer `kCamelCase` for UI tokens).
- **Widgets Granularity:** Break large build methods into focused, reusable private or public widget classes instead of monolithic 500-line build trees.

---

## 3. UI/UX Rules
- **Material 3 Standards:** Use `ThemeData(useMaterial3: true)` with dynamic color schemes, consistent border radiuses (`12.0` - `16.0`), and proper elevation tokens.
- **Haptic Feedback:** Provide subtle tactile feedback (`HapticFeedback.lightImpact()`) on button clicks, slider adjustments, and completion states.
- **Responsive Layout:** Must support all phone screen sizes without `RenderFlex` overflows. Use `LayoutBuilder`, `SingleChildScrollView`, and adaptive spacing.
- **Clear Information Hierarchy:** Always show Original Size vs New Size side-by-side with clear color badges (e.g. Green for size reduced, Red/Amber for warnings).

---

## 4. File Management & Storage Rules
- **Non-Destructive Operations:** Never overwrite the user's original image file. Processed files must be created in app cache or output directories with unique filenames (e.g. `img_compressed_20260901_123456.jpg`).
- **Temporary Cache Cleanup:** Provide auto-cleanup for files older than 7 days in the temporary processing cache.
- **Scoped Storage & Permissions:** Ensure modern Android (Scoped Storage / Photo Picker / MediaStore) and iOS (Photo Library Add Only) permission guidelines are strictly followed.

---

## 5. Git & Commit Workflow
- Commit messages must follow Conventional Commits:
  - `feat: add target size compression algorithm`
  - `fix: prevent OOM crash on 4K image decoding`
  - `ui: polish before-after comparison card`
  - `refactor: extract isolate runner into separate helper`
