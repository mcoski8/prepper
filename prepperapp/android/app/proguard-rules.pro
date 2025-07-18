# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Preserve line number information for debugging stack traces.
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to hide the original source file name.
-renamesourcefileattribute SourceFile

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Tantivy JNI bridge
-keep class com.prepperapp.TantivyBridge { *; }
-keep class com.prepperapp.TantivyBridge$* { *; }

# Keep data classes used by JNI
-keep class com.prepperapp.SearchResult { *; }
-keep class com.prepperapp.SearchResultNative { *; }
-keep class com.prepperapp.SearchResultsNative { *; }
-keep class com.prepperapp.IndexStats { *; }

# Kotlin
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**