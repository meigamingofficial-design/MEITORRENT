import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Suppress the "source/target value 8 is obsolete" warning that comes from
// the Flutter Gradle plugin's internal JavaCompile tasks.
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.addAll(listOf("-Xlint:-options"))
}

android {
    namespace = "com.meigaming.meitorrent"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.meigaming.meitorrent"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }

    // ─── Product Flavours ──────────────────────────────────────────────────
    // Each flavour gets a UNIQUE applicationId so all three can be installed
    // side-by-side on the same device.
    flavorDimensions.add("env")
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"       // com.meigaming.meitorrent.dev
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Meitorrent Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"   // com.meigaming.meitorrent.staging
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Meitorrent Staging")
        }
        create("prod") {
            dimension = "env"
            // No suffix – keeps the original com.meigaming.meitorrent
            resValue("string", "app_name", "Meitorrent")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// ─── 16 KB ELF alignment (Android 15+ / Google Play API 35+ requirement) ─────
// The libtorrent_flutter plugin ships pre-compiled .so files with 4 KB-aligned
// LOAD segments. Google Play now requires 16 KB alignment for all native libs.
// This hook runs after every merge*NativeLibs task and realigns any non-compliant
// .so files using the project's realign_elf.py script.
val realignScript = rootProject.file("../.16kb_fix/realign_elf.py")

tasks.configureEach {
    if (name.startsWith("merge") && name.endsWith("NativeLibs")) {
        doLast {
            if (!realignScript.exists()) {
                logger.warn("16KB-fix: realign_elf.py not found at $realignScript – skipping")
                return@doLast
            }

            val variant = name.removePrefix("merge").removeSuffix("NativeLibs")
                .replaceFirstChar { it.lowercase() }
            val libDir = project.layout.buildDirectory
                .dir("intermediates/merged_native_libs/$variant/$name/out/lib")
                .get().asFile

            if (!libDir.exists()) {
                logger.warn("16KB-fix: merged libs dir not found at $libDir – skipping")
                return@doLast
            }

            libDir.walkTopDown().filter { it.extension == "so" }.forEach { so ->
                logger.lifecycle("16KB-fix: processing ${so.name} (${so.parentFile.name})")
                val tmp = File(so.parent, "${so.name}.aligned")
                exec {
                    commandLine("python3", realignScript.absolutePath,
                                so.absolutePath, tmp.absolutePath)
                }
                if (tmp.exists() && tmp.length() > 0) {
                    so.delete()
                    tmp.renameTo(so)
                }
            }
        }
    }
}

