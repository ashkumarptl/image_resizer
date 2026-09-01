# Tasks & Action Items (TASKS.md)

## 📌 Legend
- `[ ]` Not Started
- `[/]` In Progress
- `[x]` Completed

---

## 🚀 Phase 1: Foundation & Dependencies Setup
- [x] **Task 1.1:** Update `pubspec.yaml` with required packages (`image`, `image_picker`, `image_cropper`, `path_provider`, `share_plus`, `gal`, `flutter_riverpod`, `shared_preferences`, `google_fonts`, `intl`, `gap`, `path`).
- [x] **Task 1.2:** Configure Android `AndroidManifest.xml` (storage permissions, UCrop activity setup for `image_cropper`).
- [x] **Task 1.3:** Configure iOS `Info.plist` (Photo library read & write permissions, Camera permissions).
- [x] **Task 1.4:** Setup Project folder architecture under `lib/` (core, data, domain, services, presentation).

---

## ⚡ Phase 2: Core Image Processing Service & Engine (Isolates)
- [x] **Task 2.1:** Implement `ImageProcessor` isolate engine in `lib/services/image_service/`.
- [x] **Task 2.2:** Implement `TargetSizeOptimizer` with binary search on encoder quality and intelligent dimension scaling.
- [x] **Task 2.3:** Implement `FormatConverter` (JPG, PNG, WebP) with quality sliders.
- [x] **Task 2.4:** Implement `DimensionResizer` (Exact pixels, aspect ratio lock, percentage scale).
- [x] **Task 2.5:** Implement `StorageService` (Saving to app cache, saving to device gallery via `gal`, cleaning old temp cache).

---

## 🎨 Phase 3: Presentation & UI Layer
- [x] **Task 3.1:** Implement Material 3 Theme (Light & Dark mode palettes, typography, card shapes).
- [x] **Task 3.2:** Build **Home Screen** (App bar, Indian Presets Carousel, Quick Tools Grid, Recent Files List).
- [x] **Task 3.3:** Build **Compressor Screen** (Target size input field, quick chips `20KB/50KB/100KB`, image preview card).
- [x] **Task 3.4:** Build **Resizer Screen** (Width/Height input, Aspect ratio toggle, percentage chips `25%/50%/75%`).
- [x] **Task 3.5:** Build **Format Converter Screen** (Input format badge, Target format choice chips, quality slider).
- [x] **Task 3.6:** Build **Cropper Integration** (Aspect ratio selection: Free, 1:1, 3:4, 4:3, 16:9, Passport).
- [x] **Task 3.7:** Build **Result & Comparison Screen** (Before/After comparison card, size reduction badge, Save to Gallery button, Share button).

---

## ⚡ Phase 4: Batch Processing & Advanced Utilities
- [x] **Task 4.1:** Implement `BatchProcessor` engine with multi-image picker and `.zip` archive creation via `archive`.
- [x] **Task 4.2:** Build `BatchScreen` with live progress indicator, batch save to gallery, and zip sharing.
- [x] **Task 4.3:** Implement `SignatureEnhancer` isolate engine with grayscale & luminance binarization thresholding.
- [x] **Task 4.4:** Build `SignatureCleanerScreen` with shadow removal strength slider and strict `< 20 KB` preset.
- [x] **Task 4.5:** Implement `NameDateStamper` isolate engine with footer strip, candidate Name and Date of Photo (DOP) text rendering.
- [x] **Task 4.6:** Build `PhotoStampScreen` with live simulation preview and date picker.

---

## 🧪 Phase 5: Verification & Quality Assurance
- [x] **Task 5.1:** Run `flutter analyze` and resolve all linter warnings (0 issues).
- [x] **Task 5.2:** Test target file size, signature enhancer, batch processor, and date stamper unit tests (10/10 tests passed).
- [ ] **Task 5.3:** Run on physical Android/iOS device and verify UI flows.
