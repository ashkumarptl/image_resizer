# Project Implementation Phases

## Overview & Roadmap
This document outlines the step-by-step development phases to build, test, and release the **Image Tools** application from scratch to production readiness.

---

## Phase 1: Foundation, Dependencies & Core Engine (Week 1)
- [ ] Setup `pubspec.yaml` with core dependencies (`image`, `image_picker`, `image_cropper`, `path_provider`, `share_plus`, `gal`, `flutter_riverpod`, `shared_preferences`).
- [ ] Configure Android permissions (Read/Write images, MediaStore) and iOS `Info.plist` usage descriptions.
- [ ] Implement Core Utilities & Extensions (FileSize formatting, string utils, color tokens).
- [ ] Build **ImageProcessingService** running inside background isolates:
  - Image decoding (JPG, PNG, WebP, BMP, GIF).
  - Dimension resize (pixels, percentage, aspect ratio).
  - Format converter (output to JPG, PNG, WebP).
  - Smart **Target File Size Optimizer** (Iterative binary search on quality + dimension fallback).
- [ ] Write Unit Tests for image processing algorithms.

---

## Phase 2: Design System & Core Tools UI (Week 2)
- [ ] Implement Material 3 Theme (Light & Dark mode palettes, typography, card shapes).
- [ ] Build **Home Dashboard Screen**:
  - Quick Tools Grid (Resize, Convert, Compress, Crop, Batch).
  - Indian Exam Presets Carousel/Banner.
  - Recent Processed Files Section.
- [ ] Build **Tool Screens**:
  - **Compressor Screen:** Target size input (KB/MB), quick chips (20 KB, 50 KB, 100 KB, 200 KB), quality slider.
  - **Resizer Screen:** Width/Height input with lock aspect ratio, percentage slider (25%, 50%, 75%).
  - **Format Converter Screen:** Source format detection, Target format selector (JPG, PNG, WebP), quality slider.
  - **Cropper Screen:** Native cropping integration with pre-configured aspect ratios.
- [ ] Build **Result & Comparison Screen**:
  - Before/After interactive preview.
  - Size reduction badge (`-78% (2.4 MB ➔ 52 KB)`).
  - Save to Gallery & Share to WhatsApp/System Sheet actions.

---

## Phase 3: Indian Exam Presets & Local History (Week 3)
- [ ] Build **Indian Govt & Exam Presets Hub**:
  - SSC CGL/CHSL/MTS (Photo: 20-50 KB, Signature: 10-20 KB).
  - UPSC Civil Services (Photo: 20-300 KB, Signature: 20-300 KB).
  - CG Vyapam / State PSCs (Photo: 50 KB, Signature: 20 KB).
  - IBPS / Banking (Photo: 20-50 KB, Signature: 10-20 KB).
  - Passport & Visa standard dimensions (3.5cm x 4.5cm, 2 inch x 2 inch).
  - PAN Card / Aadhaar Form requirements.
- [ ] Implement **Recent Files History Repository** (Persistent local history using `shared_preferences`).
- [ ] Implement Custom User Presets (Save favorite dimensions/target sizes).

---

## Phase 4: Batch Processing & Advanced Utilities (Week 4)
- [ ] Implement **Batch Processing Engine**:
  - Multi-image picker from gallery.
  - Batch resize/compress with progress indicator per image.
  - Batch export / Zip archive generation.
- [ ] Signature High-Contrast B&W filter tool (Thresholding filter for crisp scanned signatures).
- [ ] Add Name & Date Stamp tool for exam photo requirements.

---

## Phase 5: Monetization, Optimization & Launch Prep (Week 5)
- [ ] Setup Google Mobile Ads SDK (AdMob banner, interstitial on export with cooldown, rewarded for batch).
- [ ] Setup In-App Purchase (Pro Lifetime unlock to remove ads and unlock unlimited batch processing).
- [ ] Performance profiling: Memory consumption checks, isolate leak tests, 60 FPS UI audit.
- [ ] Play Store & App Store assets, screenshots, and metadata localization (English + Hindi keywords).
