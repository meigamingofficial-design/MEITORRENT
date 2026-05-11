
plugins {
    id("com.android.application")
    id("kotlin-android")
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

    kotlinOptions {
        jvmTarget = "17"
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

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
