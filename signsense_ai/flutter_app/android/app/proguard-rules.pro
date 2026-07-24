# Flutter + SignSense AI ProGuard Rules
# Applied to release builds only (isMinifyEnabled = true).

# ─── Flutter ────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ─── Google Fonts (uses reflection for typeface loading) ────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── speech_to_text ─────────────────────────────────────────────────────────
-keep class com.csdcorp.speech_to_text.** { *; }

# ─── flutter_tts ────────────────────────────────────────────────────────────
-keep class com.tundralabs.fluttertts.** { *; }

# ─── geolocator ─────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ─── camera ─────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.camera.** { *; }

# ─── flutter_contacts ───────────────────────────────────────────────────────
-keep class co.quis.flutter_contacts.** { *; }

# ─── flutter_local_notifications ────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ─── permission_handler ─────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ─── share_plus ─────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ─── Kotlin coroutines ──────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ─── General Android ────────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
