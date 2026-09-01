# Design System & UI/UX Guidelines

## 1. Visual Language & Aesthetics
- **Theme Style:** Modern Material 3 with vibrant accents, clean cards, subtle micro-elevations, and glassmorphism touches for premium feel.
- **Support:** Full Light and Dark Mode support with adaptive contrasts.
- **Corner Radii:**
  - Card & Container Radii: `16.0px`
  - Button Radii: `12.0px`
  - Chip Radii: `8.0px`
  - Modal/Sheet Top Corners: `24.0px`

---

## 2. Color Palette (Tokens)

### Light Theme
- **Primary:** `#2563EB` (Electric Blue - Trustworthy & Modern)
- **Primary Container:** `#DBEAFE`
- **Secondary:** `#0D9488` (Teal Accent)
- **Secondary Container:** `#CCFBF1`
- **Surface / Background:** `#F8FAFC` (Slate 50)
- **Surface Card:** `#FFFFFF` (Pure White)
- **Success / Size Decreased:** `#16A34A` (Emerald Green)
- **Warning / Alert:** `#EA580C` (Amber / Orange)
- **Text Primary:** `#0F172A` (Slate 900)
- **Text Secondary:** `#64748B` (Slate 500)

### Dark Theme
- **Primary:** `#3B82F6` (Vibrant Blue)
- **Primary Container:** `#1E3A8A`
- **Secondary:** `#14B8A6` (Vibrant Teal)
- **Secondary Container:** `#134E4A`
- **Surface / Background:** `#0B0F17` (Deep Dark Slate)
- **Surface Card:** `#161E2E` (Dark Card Surface)
- **Success:** `#22C55E`
- **Warning:** `#F97316`
- **Text Primary:** `#F8FAFC`
- **Text Secondary:** `#94A3B8`

---

## 3. Typography Hierarchy
- **Display / App Title:** `GoogleFonts.outfit` or `Roboto`, Bold, 24sp
- **Headline / Screen Header:** SemiBold, 20sp
- **Title / Card Titles:** Medium, 16sp
- **Body / Normal Text:** Regular, 14sp
- **Caption / Metadata / File Sizes:** Regular, 12sp (Monospace/Numerals styled)

---

## 4. Key UI Components & Layouts

### 4.1 Home Screen Layout
```
┌──────────────────────────────────────────────┐
│  Image Tools ⚡                     [ 🌙 / ⚙️ ]│
│  Fast, Offline & Privacy-First Optimizer     │
├──────────────────────────────────────────────┤
│  🇮🇳 EXAM & GOVT PRESETS                       │
│  ┌───────────┐ ┌───────────┐ ┌────────────┐  │
│  │ SSC Photo │ │ Vyapam    │ │ Passport   │  │
│  │ 20-50 KB  │ │ 50 KB     │ │ 3.5x4.5 cm │  │
│  └───────────┘ └───────────┘ └────────────┘  │
├──────────────────────────────────────────────┤
│  QUICK TOOLS                                 │
│  ┌────────────────────┐ ┌──────────────────┐ │
│  │  🖼️ Resize         │ │  🔄 Convert      │ │
│  │  Custom Dimensions │ │  JPG, PNG, WebP  │ │
│  └────────────────────┘ └──────────────────┘ │
│  ┌────────────────────┐ ┌──────────────────┐ │
│  │  📦 Compress       │ │  ✂️ Crop          │ │
│  │  Target Size (KB)  │ │  Aspect Ratios   │ │
│  └────────────────────┘ └──────────────────┘ │
│  ┌─────────────────────────────────────────┐ │
│  │  ⚡ Batch Processing (Multi-Select)     │ │
│  └─────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│  🕒 RECENT FILES                             │
│  ┌─────────────────────────────────────────┐ │
│  │ [Thumbnail] photo_compressed.jpg        │ │
│  │ 2.4 MB ➔ 48 KB (-98%) · 2 mins ago     │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### 4.2 Compressor / Target Size Screen
- **Image Preview Card:** Shows current file size, resolution, and format.
- **Target Size Input Section:**
  - Numeric input field (e.g. `[ 50 ] KB / MB toggle`).
  - Quick Choice Chips: `[ 20 KB ]` `[ 50 KB ]` `[ 100 KB ]` `[ 200 KB ]` `[ 500 KB ]`.
- **Quality vs Speed Selector:** Balanced / Best Quality.
- **Action Button:** Large gradient button `[ ⚡ Compress Image ]`.

### 4.3 Result & Comparison Screen
- **Before / After Card:** Toggle between Original ($2.8\text{ MB}$) vs Optimized ($48\text{ KB}$).
- **Details Table:** Resolution changes, Format, Exact byte count.
- **Primary Actions:**
  - `[ 💾 Save to Gallery ]` (Green filled button)
  - `[ 📤 Share to WhatsApp / Apps ]` (Outlined/Tonal button)
  - `[ 🔄 Process Another ]`

---

## 5. Micro-Interactions & Motion
- **Button Pressed State:** Subtle scale down to `0.97` on tap.
- **Compressing State:** Animated circular progress indicator with simulated step status (*"Decoding image...", "Optimizing dimensions...", "Encoding output..."*).
- **Success State:** Pop animation with Confetti/Checkmark icon + Haptic buzz.
