# Add to proguard-rules.pro for Google Sign-In and Firebase

# Google Sign-In
-keepclassmembers class * {
    @com.google.android.gms.common.api.internal.* <methods>;
}
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase Auth
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Keep model classes
-keep class com.coopvestafrica.app.data.models.** { *; }
-keep class com.coopvestafrica.app.data.repositories.** { *; }

# Retrofit
-keepattributes Signature
-keepattributes Exceptions
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn retrofit2.KotlinExtensions
-dontwarn retrofit2.KotlinExtensions$*

# Dio
-dontwarn dio.**
-keep class dio.** { *; }

# JSON Serializable
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Riverpod
-keep class riverpod.** { *; }
-keep class * extends riverpod.StateNotifier { *; }

# Hive
-keep class org.hive.** { *; }
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @flutter.HiveDataType *;
}

# Encryption
-keep class encrypt.** { *; }
-keep class javax.crypto.** { *; }

# JWT
-keep class dart_jsonwebtoken.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**
