# =============================================
# FLUTTER SPECIFIC
# =============================================

# Keep Flutter engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Flutter embedding
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# =============================================
# APP SPECIFIC
# =============================================

# Keep our app classes
-keep class com.example.frontend.** { *; }

# Keep generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# =============================================
# JITSI MEET (Mobile SDK)
# =============================================

# Jitsi Meet core
-keep class org.jitsi.** { *; }

# WebRTC
-keep class org.webrtc.** { *; }

# Jitsi utils
-keep class org.jitsi.utils.** { *; }
-keep class org.jitsi.service.** { *; }

# Jitsi impl
-keep class org.jitsi.impl.** { *; }

# Keep Jitsi Meet SDK
-keep class com.jitsi.meet.** { *; }

# =============================================
# VERY_CUSTOM_JITSI_MEET (Web/Android)
# =============================================

# Keep very_custom_jitsi_meet classes
-keep class com.verycustom.jitsi.meet.** { *; }

# Keep Jitsi Meet external API (for web)
-keep class org.jitsi.meet.** { *; }

# =============================================
# PERMISSION_HANDLER
# =============================================

-keep class com.baseflow.permissionhandler.** { *; }

# =============================================
# DIO (HTTP Client)
# =============================================

-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# =============================================
# JSON PARSING (Gson)
# =============================================

-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.** { *; }

# =============================================
# JWT (Auth0)
# =============================================

-keep class com.auth0.jwt.** { *; }
-keep class com.auth0.jwt.algorithms.** { *; }

# =============================================
# SHARED PREFERENCES
# =============================================

-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }

# =============================================
# FIREBASE (if used)
# =============================================

-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# =============================================
# REFLECTION & ANNOTATIONS
# =============================================

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes EnclosingMethod

# Keep all annotations
-keep class * extends java.lang.annotation.Annotation { *; }

# =============================================
# NATIVE METHODS
# =============================================

-keepclasseswithmembernames class * {
    native <methods>;
}

# =============================================
# CUSTOM VIEW CONSTRUCTORS
# =============================================

-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# =============================================
# SERIALIZABLE CLASSES
# =============================================

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# =============================================
# PARCELABLE CLASSES
# =============================================

-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# =============================================
# DEX & R8 OPTIMIZATIONS
# =============================================

# Keep all classes in the main dex
-keep class ** { *; }

# Don't optimize any code
-dontoptimize

# Don't preverify
-dontpreverify

# =============================================
# WEBRTC SPECIFIC (for Jitsi)
# =============================================

-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

-keep class org.jitsi.** { *; }
-dontwarn org.jitsi.**

# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# =============================================
# EXCEPTIONS (Don't warn about missing classes)
# =============================================

-dontwarn javax.annotation.**
-dontwarn javax.inject.**
-dontwarn sun.misc.Unsafe

# =============================================
# ANDROIDX
# =============================================

-keep class androidx.** { *; }
-dontwarn androidx.**