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
