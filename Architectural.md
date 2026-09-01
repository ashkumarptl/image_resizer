# Architecture Specification Document

## 1. Architectural Philosophy
- **Offline-First & Privacy-Focused:** No backend servers, zero network dependencies for core features.
- **Isolate-Driven Computation:** Heavy image decoding, processing, and encoding must NEVER block the UI thread (`main isolate`). Everything is delegated to background worker isolates or `compute()`.
- **Clean Layered Architecture:** Clear separation between Presentation (UI/Widgets), Domain (Business logic/Use cases), Data (File I/O, Preferences), and Services (Image Processing Engine).
- **State Management:** Riverpod for predictable, testable, and reactive state management.

---

## 2. System Architecture Diagram

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│  - Screens: Home, Resizer, Compressor, Converter, Crop │
│  - Widgets: BeforeAfterCard, SizeBadge, PresetChips    │
│  - State: Riverpod Notifiers / StateProviders          │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                      Domain Layer                      │
│  - UseCases: CompressToTargetSize, ConvertFormat,      │
│              ResizeDimensions, CropImageUseCase        │
│  - Models: ImageProcessTask, ProcessResult, Preset     │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                     Service Layer                      │
│  - ImageProcessingService (Runs inside Worker Isolate) │
│    ├── pure Dart 'image' package engine                │
│    ├── Binary Search Quality & Dimension Scaler        │
│    └── Format Encoders (JPG, PNG, WebP)                │
│  - StorageService (Local Cache, Gallery Saver)         │
│  - PresetService (Bundled + User Custom Presets)       │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                   Data & Platform Layer                │
│  - Local Storage: SharedPreferences / Hive             │
│  - Platform Channels: ImagePicker, ImageCropper, Gal   │
│  - Device File System: getApplicationDocumentsDirectory│
└────────────────────────────────────────────────────────┘
```

---

## 3. Directory Structure

```
lib/
├── app/
│   ├── app.dart               # MaterialApp entry, theme, routes
│   └── routes.dart            # Named routes or go_router configuration
├── core/
│   ├── constants/             # App colors, dimensions, preset constants
│   ├── error/                 # Failure & Exception classes
│   ├── extensions/            # FileSize, Context, String helper extensions
│   ├── theme/                 # Material 3 light & dark theme definitions
│   └── utils/                 # File helpers, platform helpers
├── data/
│   ├── models/                # PresetModel, HistoryItemModel, ProcessOptions
│   └── repositories/          # HistoryRepository, PresetRepository
├── domain/
│   ├── models/                # Pure business entities
│   └── usecases/              # High-level business actions
├── services/
│   ├── image_service/         # Image engine & isolate functions
│   │   ├── image_processor.dart
│   │   ├── target_size_optimizer.dart
│   │   └── format_converter.dart
│   ├── storage_service.dart   # File save, cache clean, gallery export
│   └── share_service.dart     # Native share operations
└── presentation/
    ├── home/                  # Home dashboard, quick tools grid, preset cards
    ├── resizer/               # Dimension/percentage resize screen
    ├── compressor/            # Target size & percentage compressor screen
    ├── converter/             # Format converter screen
    ├── cropper/               # Aspect ratio & custom crop screen
    ├── presets/               # Indian govt & exam presets hub
    ├── result/                # Before/After comparison & export screen
    └── widgets/               # Reusable UI cards, buttons, pickers, banners
```

---

## 4. Target Size Optimization Algorithm (Isolate Logic)

When a target file size $S_{\text{target}}$ (e.g. 50 KB = $51,200$ bytes) is requested:

1. **Step 1 - Initial Encoding:** Decode image into `img.Image` in background isolate.
2. **Step 2 - Format Default:** Standardize target format to JPG (or WebP).
3. **Step 3 - Binary Search on Quality ($Q \in [10, 95]$):**
   - Test midpoint quality $Q_{\text{mid}}$.
   - Encode to byte buffer.
   - If size $\le S_{\text{target}}$ and within 90% threshold, accept.
   - Else adjust search range.
4. **Step 4 - Dimension Scaling Fallback:**
   - If lowest quality ($Q=15$) still yields size $> S_{\text{target}}$, scale down dimensions by factor $F = \sqrt{\frac{S_{\text{target}}}{\text{CurrentSize}}} \times 0.95$.
   - Re-run quality optimization.
5. **Step 5 - Return Result:** Return encoded bytes, output file path, dimensions, and actual final size.

---

## 5. Security, Memory & Performance Guidelines
1. **Memory Safety:** Immediately release raw byte buffers and avoid retaining multiple large decoded bitmaps in heap memory.
2. **Isolate Communication:** Pass simple DTOs (file paths or lightweight byte references) across isolate boundaries to minimize serialization overhead.
3. **Cache Cleanup:** Temporary processed files stored in cache directory must be rotated or purged periodically on app launch.
