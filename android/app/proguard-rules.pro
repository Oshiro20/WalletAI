# Google ML Kit - keep all classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Flutter local notifications + Gson (CRITICO para notificaciones programadas en release)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# General
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
