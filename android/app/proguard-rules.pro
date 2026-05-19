# ProGuard Rules for LinkMind
# Optimise bundle size & performance

# Keep Flutter core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Keep Firebase
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Dart/Kotlin runtime
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }
-dontwarn kotlin.**

# Keep Riverpod
-keep class riverpod.** { *; }
-keep class flutter_riverpod.** { *; }
-dontwarn riverpod.**
-dontwarn flutter_riverpod.**

# Keep Retrofit
-keepattributes Signature
-keep class retrofit.** { *; }
-keep interface retrofit.** { *; }
-dontwarn retrofit.**

# Keep JSON serialization
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Aggressive optimizations (safe for Flutter)
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
}

# Keep view constructors for inflation
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Preserve native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Disable unused code warning (already handled by Flutter)
-dontnote **
