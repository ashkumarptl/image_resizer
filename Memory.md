# Project Memory & Context

## 1. Project Identity
- **Name:** Image Tools (Image Resizer)
- **Directory:** `/Users/ashpatel/development/flutter/others/image_resizer`
- **Primary Technology:** Flutter 3.29+, Dart 3.7+, Riverpod, `image` pure Dart engine.
- **Repository Initialized:** Git initialized on `master` branch.

---

## 2. Key Architecture & Business Decisions
- **100% Offline / No Backend:** No Firestore, Supabase, or external server needed for image processing. Full client privacy.
- **Isolate Offloading:** Heavy image decoding and iterative compression runs exclusively in worker isolates via `compute()` or `Isolate.run()`.
- **Target Size Algorithm:** Combines binary search on encoder quality (JPG/WebP) with intelligent proportional dimension scaling fallback to hit exact KB targets (e.g. $\le 20\text{ KB}$, $\le 50\text{ KB}$).
- **Indian Niche Positioning:** First-class presets for Indian online government examination forms (SSC, UPSC, CG Vyapam, IBPS, Railways), State PSCs, PAN card, and Passport photos.

---

## 3. Tech Stack Matrix
| Component | Choice | Rationale |
| :--- | :--- | :--- |
| Framework | Flutter (Android & iOS) | High-performance cross-platform UI |
| Image Processing | `image` (pub.dev/packages/image) | Pure Dart, multi-platform, isolate-safe |
| Image Cropper | `image_cropper` | Native UI for smooth multi-ratio crop |
| Image Picker | `image_picker` | Standard platform gallery & camera picker |
| Gallery Export | `gal` | Modern scoped media saving on Android 14+ and iOS |
| State Management | `flutter_riverpod` | Robust, type-safe, reactive state |
| Local Preferences | `shared_preferences` | Lightweight history & setting store |
| Sharing | `share_plus` | Cross-platform file sharing sheet |

---

## 4. Current State & History Log
- **2026-09-01:** Project initialized with Git. Created specifications: `PRD.md`, `Architectural.md`, `Rules.md`, `Phases.md`, `Design.md`, `Memory.md`, `FEATURES.md`, `TASKS.md`.
