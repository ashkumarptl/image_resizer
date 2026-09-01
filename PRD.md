# Product Requirements Document (PRD)

## 1. Executive Summary & Overview
**Project Name:** Image Tools (Image Resizer & Optimizer)  
**Target Platform:** Android & iOS (Flutter Cross-Platform)  
**Positioning & Value Proposition:** A blazing-fast, 100% offline, privacy-first image utility app tailored for daily tasks, social media creators, and specifically optimized for **Indian Online Application Forms** (SSC, UPSC, CG Vyapam, IBPS, Railways, NTA, Passport, PAN & Aadhaar uploads) where strict file size (e.g. *under 20 KB*, *under 50 KB*) and dimension limits are mandated.

---

## 2. Problem Statement
1. **Strict File Size Constraints:** Candidates applying for government and competitive exams in India frequently face rejected uploads due to images exceeding 20 KB, 50 KB, or 100 KB limits.
2. **Complex / Ad-Spammed Tools:** Existing mobile apps are bloated with invasive popups, require internet uploads (compromising privacy of identity documents), or lack automated target file size algorithms.
3. **Privacy Concerns:** Uploading personal identity photos, signatures, and marksheets to random web servers poses significant privacy and data leakage risks.

---

## 3. Solution & Core Objectives
- **100% Client-Side Processing:** All compression, conversion, cropping, and resizing operations run strictly on the device via background isolates. Zero data leaves the user's device.
- **Smart Target File Size Optimization:** Automatically calculates the optimal dimension scaling and compression quality iteratively to reach user-specified sizes (e.g. "Target: 48 KB").
- **One-Tap Govt & Exam Presets:** Pre-configured presets for popular forms (SSC Photo/Signature, UPSC, CG Vyapam, PAN Card, US/Indian Passport).
- **Format Flexibility:** Support input formats (JPG, PNG, WebP, BMP, GIF) and export to standard formats (JPG, PNG, WebP).
- **High Retention & Monetization Readiness:** Clean Material 3 design, non-intrusive ad placements, and optional Pro upgrade for batch processing.

---

## 4. Target Audience & User Personas
1. **Govt Job / Exam Aspirants (Primary):** Need exact 20 KB/50 KB photo & signature resizing in seconds from mobile without a cyber café.
2. **General Mobile Users & Professionals:** Need quick image downsizing for email attachments, WhatsApp status optimization, and form submissions.
3. **Content Creators & Social Media Managers:** Need custom dimension resizing, WebP conversion, and aspect ratio cropping.

---

## 5. Key Feature Requirements (Scope)

### 5.1 MVP Scope
- **Image Resizer:** Resize by pixels (width x height with aspect ratio lock/unlock) and percentage (10% - 100%).
- **Format Converter:** Convert between JPG, PNG, WebP with custom quality slider.
- **Smart Compressor (Target File Size):** Enter desired target size (e.g. 50 KB) or select quick chips (20 KB, 50 KB, 100 KB, 200 KB).
- **Image Cropper:** Aspect ratio cropping (Free, 1:1, 3:4, 4:3, 16:9, Passport 3.5cm x 4.5cm).
- **Indian Exam Presets:** Dedicated pre-sets for SSC, UPSC, CG Vyapam, PAN, and Passport.
- **Result & Share:** Before/After size comparison, save to device gallery, instant share via WhatsApp/system sheet.
- **Recent History:** Local cache of recently processed images.

### 5.2 Post-MVP / Future Scope
- **Batch Processing:** Multi-image selection, batch resizing/compression, and zip export.
- **Text & Date on Photo:** Adding candidate name and date stamp on exam photos.
- **Signature Background Removal / Cleanup:** High-contrast thresholding for scanned signatures.
- **AdMob & In-App Purchase Integration:** Banner, interstitial, and Pro lifetime purchase.

---

## 6. Success Metrics (KPIs)
- **Zero Freeze Rate:** 100% of image compute operations executed off the main UI thread (60+ FPS maintained).
- **Target Accuracy:** Generated image size must be $\le$ Target Size in >98% of standard photo inputs.
- **Processing Time:** Single image compression < 1.5 seconds on mid-range Android devices.
- **App Size:** Lightweight release APK size < 25 MB.
