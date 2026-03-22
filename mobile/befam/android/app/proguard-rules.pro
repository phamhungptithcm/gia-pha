# -----------------------------------------------
# Flutter & Dart
# -----------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# -----------------------------------------------
# Firebase
# -----------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# -----------------------------------------------
# BeFam app classes
# -----------------------------------------------
-keep class com.familyclanapp.befam.** { *; }

# -----------------------------------------------
# Kotlin
# -----------------------------------------------
-keep class kotlin.** { *; }
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# -----------------------------------------------
# JSON serialization (json_serializable / freezed)
# -----------------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# -----------------------------------------------
# AndroidX
# -----------------------------------------------
-keep class androidx.** { *; }
-dontwarn androidx.**

# -----------------------------------------------
# Firebase Crashlytics
# -----------------------------------------------
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# -----------------------------------------------
# Firebase Performance Monitoring
# -----------------------------------------------
-keep class com.google.firebase.perf.** { *; }
-dontwarn com.google.firebase.perf.**

# -----------------------------------------------
# Firebase App Check
# -----------------------------------------------
-keep class com.google.firebase.appcheck.** { *; }
-dontwarn com.google.firebase.appcheck.**

# -----------------------------------------------
# OkHttp (used by Firebase SDKs)
# -----------------------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
