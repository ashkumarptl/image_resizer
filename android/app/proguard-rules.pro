# ==============================================================================
# Flutter Platform & Engine Rules
# Flutter Gradle Plugin automatically provides consumer rules for Flutter engine.
# We retain only the essential plugin registry and platform channel bindings.
# ==============================================================================
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class com.ashspark.image_resizer.MainActivity { *; }
-dontwarn io.flutter.**

# ==============================================================================
# Google Play Core (In-App Update & Review)
# ==============================================================================
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.review.** { *; }
-dontwarn com.google.android.play.core.**

# ==============================================================================
# Firebase & Google Play Services
# Note: Official Firebase & GMS AARs bundle their own consumer ProGuard rules.
# Blanket keep rules are removed to allow R8 full shrinking and optimization.
# ==============================================================================
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Firebase Component Registrars (Required for runtime DI used by ML Kit & Firebase)
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
    void <init>();
}

# ==============================================================================
# Google ML Kit
# ML Kit Android libraries bundle their own consumer rules.
# We retain Flutter plugin method channel bridges and suppress internal warnings.
# ==============================================================================
-keep class com.google_mlkit_subject_segmentation.** { *; }
-keep class com.google_mlkit_document_scanner.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**

# ==============================================================================
# UCrop (image_cropper native library)
# ==============================================================================
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# ==============================================================================
# Gal (Native media saving library)
# ==============================================================================
-keep class com.radzima.gal.** { *; }
-dontwarn com.radzima.gal.**

