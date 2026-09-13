# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Play Store Deferred Components (if play core is not included)
-dontwarn com.google.android.play.core.**

# Firebase & Google Play Services
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google ML Kit (Subject Segmentation, Document Scanner, Commons)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.android.gms.internal.mlkit_**
-keep class com.google_mlkit_subject_segmentation.** { *; }
-keep class com.google_mlkit_document_scanner.** { *; }
-keep class com.google_mlkit_commons.** { *; }

# Firebase Component Registrars (Used by ML Kit for Dependency Injection)
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
    void <init>();
}

# UCrop (image_cropper)
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# Gal library
-keep class com.radzima.gal.** { *; }
-dontwarn com.radzima.gal.**

