# Tasks & Action Items (TASKS.md)

## 📌 Legend
- `[ ]` Not Started
- `[/]` In Progress
- `[x]` Completed

---

## 🚀 Phase 1: Foundation & Dependencies Setup
- [ ] **Task 1.1:** Update `pubspec.yaml` with required packages (`image`, `image_picker`, `image_cropper`, `path_provider`, `share_plus`, `gal`, `flutter_riverpod`, `shared_preferences`, `google_fonts`, `flutter_svg`).
- [ ] **Task 1.2:** Configure Android `AndroidManifest.xml` (storage permissions, UCrop activity setup for `image_cropper`).
- [ ] **Task 1.3:** Configure iOS `Info.plist` (Photo library read & write permissions).
- [ ] **Task 1.4:** Setup Project folder architecture under `lib/` (core, data, domain, services, presentation).

---

## ⚡ Phase 2: Core Image Processing Service & Engine (Isolates)
- [ ] **Task 2.1:** Implement `ImageProcessor` isolate engine in `lib/services/image_service/`.
- [ ] **Task 2.2:** Implement `TargetSizeOptimizer` with binary search on encoder quality and intelligent dimension scaling.
- [ ] **Task 2.3:** Implement `FormatConverter` (JPG, PNG, WebP) with quality sliders.
- [ ] **Task 2.4:** Implement `DimensionResizer` (Exact pixels, aspect ratio lock, percentage scale).
- [ ] **Task 2.5:** Implement `StorageService` (Saving to app cache, saving to device gallery via `gal`, cleaning old temp cache).

---

## 🎨 Phase 3: Presentation & UI Layer
- [ ] **Task 3.1:** Implement Material 3 Theme (Light & Dark mode palettes, typography, card shapes).
- [ ] **Task 3.2:** Build **Home Screen** (App bar, Indian Presets Carousel, Quick Tools Grid, Recent Files List).
- [ ] **Task 3.3:** Build **Compressor Screen** (Target size input field, quick chips `20KB/50KB/100KB`, image preview card).
- [ ] **Task 3.4:** Build **Resizer Screen** (Width/Height input, Aspect ratio toggle, percentage chips `25%/50%/75%`).
- [ ] **Task 3.5:** Build **Format Converter Screen** (Input format badge, Target format choice chips, quality slider).
- [ ] **Task 3.6:** Build **Cropper Integration** (Aspect ratio selection: Free, 1:1, 3:4, 4:3, 16:9, Passport).
- [ ] **Task 3.7:** Build **Result & Comparison Screen** (Before/After comparison card, size reduction badge, Save to Gallery button, Share button).

---

## 🇮🇳 Phase 4: Indian Govt Presets & History State
- [ ] **Task 4.1:** Define preset data models and preset constants for SSC, UPSC, CG Vyapam, IBPS, Railways, PAN Card, Passport.
- [ ] **Task 4.2:** Build dedicated **Presets Detail Screen** with instant 1-tap processing.
- [ ] **Task 4.3:** Implement `HistoryRepository` with `shared_preferences` to persist processed images list.
- [ ] **Task 4.4:** Connect Recent Files section on Home Screen to load and display previous outputs.

---

## 🧪 Phase 5: Verification & Quality Assurance
- [ ] **Task 5.1:** Run `flutter analyze` and resolve all linter warnings.
- [ ] **Task 5.2:** Test target file size algorithm with multiple high-res test images.
- [ ] **Task 5.3:** Verify UI responsiveness on various screen sizes and dark mode.
- [ ] **Task 5.4:** Create initial git commit tracking all base files.
