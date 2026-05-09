# ─── Meitorrent Release Proguard Rules ──────────────────────────────────────────

# Keep generic signature information (critical for Gson TypeTokens serialization in flutter_local_notifications)
-keepattributes Signature, InnerClasses, EnclosingMethod

# Keep annotations to prevent reflection failures
-keepattributes *Annotation*

# Prevent Gson classes from being obfuscated or stripped
-keep class com.google.gson.** { *; }

# Keep all classes under flutter_local_notifications to avoid deserialization crashes
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Keep Meitorrent custom native Kotlin classes & method channel handlers intact
-keep class com.meigaming.meitorrent.** { *; }
