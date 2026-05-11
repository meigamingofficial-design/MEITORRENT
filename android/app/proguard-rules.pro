# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Keep our native libtorrent symbols for crash reporting
-keep class com.meigaming.meitorrent.** { *; }
-keep class com.frostwire.jlibtorrent.** { *; }

# Drift/SQLite
-keep class * extends androidx.room.RoomDatabase
-dontwarn net.sqlcipher.**

# Flutter Local Notifications (Fixes "Missing type parameter" crash)
-keepattributes Signature
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * extends com.google.gson.reflect.TypeToken
-keep public class com.google.gson.internal.bind.TypeAdapters
