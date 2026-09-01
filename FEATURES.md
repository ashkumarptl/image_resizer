# Features Specification

## 1. Feature Matrix & Priority

| Feature Name | Priority | Status | Description |
| :--- | :---: | :---: | :--- |
| **Smart Target Size Compressor** | ⭐⭐⭐⭐⭐ (P0) | 📋 Planned | Compress image to exact $\le X\text{ KB}$ (e.g. 20 KB, 50 KB, 100 KB, 200 KB) with iterative quality & dimension optimization. |
| **Format Converter** | ⭐⭐⭐⭐⭐ (P0) | 📋 Planned | Convert images between JPG, PNG, WebP with adjustable output compression quality. |
| **Dimension Resizer** | ⭐⭐⭐⭐⭐ (P0) | 📋 Planned | Resize by exact pixel dimensions ($W \times H$) with aspect ratio lock/unlock, or by percentage ($25\%, 50\%, 75\%$). |
| **Aspect Ratio Cropper** | ⭐⭐⭐⭐ (P1) | 📋 Planned | Native crop with standard presets ($1:1, 3:4, 4:3, 16:9$, Passport size $3.5 \times 4.5\text{ cm}$). |
| **Indian Govt & Exam Presets** | ⭐⭐⭐⭐⭐ (P0) | 📋 Planned | 1-tap presets for SSC, UPSC, CG Vyapam, IBPS, Railways, PAN Card, Aadhaar, Passport. |
| **Interactive Before/After Screen** | ⭐⭐⭐⭐⭐ (P0) | 📋 Planned | Visual side-by-side / toggle comparison showing exact bytes saved and percentage reduction. |
| **Direct Save to Gallery & Share** | ⭐⭐⭐⭐⭐ (P0) | 📋 Planned | Save output directly into Android/iOS Photos/Gallery and share via WhatsApp/Gmail. |
| **Recent Files History** | ⭐⭐⭐⭐ (P1) | 📋 Planned | Persistent list of recently processed files with thumbnail, original size, and compressed size. |
| **Batch Processing** | ⭐⭐⭐⭐ (P1) | 📋 Planned | Select multiple photos and compress/convert in one batch operation with zip export. |
| **B&W Signature Enhancer** | ⭐⭐⭐ (P2) | 📋 Planned | High-contrast black & white threshold filter to clean up scanned signatures for online forms. |
| **Name & Date Stamp on Photo** | ⭐⭐⭐ (P2) | 📋 Planned | Stamp candidate name & date of photo at bottom of passport picture (standard SSC/Govt exam requirement). |
| **AdMob & Pro In-App Purchase** | ⭐⭐⭐ (P2) | 📋 Planned | Banner/Interstitial ads + Lifetime Pro upgrade to remove ads and unlock batch limits. |

---

## 2. Detailed Feature Breakdown

### 2.1 Smart Target Size Compressor
- **Input:** Any supported image file (up to 50 MB / 4K resolution).
- **Target Size Options:**
  - Quick Chips: `20 KB`, `50 KB`, `100 KB`, `200 KB`, `500 KB`.
  - Custom Input: Numeric text field with `KB` / `MB` unit toggle.
- **Processing Logic:**
  - Background isolate decodes image without main thread hitching.
  - Automatically iterates encoder quality and scales down image resolution if needed.
  - Guarantees final size is within target limit (within 1% tolerance).
- **Output:** New compressed file in app cache.

### 2.2 Format Converter
- **Supported Input Formats:** JPG, JPEG, PNG, WebP, BMP, GIF.
- **Supported Output Formats:** JPG, PNG, WebP.
- **Quality Control:** 10% to 100% slider (with default 85% recommended value).

### 2.3 Indian Govt & Exam Presets Hub
| Preset Name | Target Size | Recommended Dimensions | Recommended Format |
| :--- | :--- | :--- | :--- |
| **SSC Photo** | $20\text{ KB} - 50\text{ KB}$ | $3.5\text{ cm} \times 4.5\text{ cm}$ ($132 \times 170\text{ px}$) | JPG |
| **SSC Signature** | $10\text{ KB} - 20\text{ KB}$ | $4.0\text{ cm} \times 2.0\text{ cm}$ ($151 \times 75\text{ px}$) | JPG |
| **UPSC Photo** | $20\text{ KB} - 300\text{ KB}$ | $350 \times 350\text{ px}$ | JPG |
| **UPSC Signature** | $20\text{ KB} - 300\text{ KB}$ | $350 \times 350\text{ px}$ | JPG |
| **CG Vyapam Photo** | $\le 50\text{ KB}$ | $3.5\text{ cm} \times 4.5\text{ cm}$ | JPG |
| **CG Vyapam Signature**| $\le 20\text{ KB}$ | $4.0\text{ cm} \times 2.0\text{ cm}$ | JPG |
| **IBPS Photo** | $20\text{ KB} - 50\text{ KB}$ | $200 \times 230\text{ px}$ | JPG |
| **IBPS Signature** | $10\text{ KB} - 20\text{ KB}$ | $140 \times 60\text{ px}$ | JPG |
| **Passport Photo (Indian)** | $\le 100\text{ KB}$ | $3.5\text{ cm} \times 4.5\text{ cm}$ | JPG |
| **PAN Card Form** | $\le 200\text{ KB}$ | Standard A4 / Card Ratio | JPG / PNG |

---

## 3. Non-Functional Requirements
- **Performance:** App launch < 1.0s, processing operation < 1.5s for 1080p image.
- **Offline Reliability:** 100% functional in Airplane mode.
- **Storage Consumption:** Efficient cache management, total app install size < 30 MB.
