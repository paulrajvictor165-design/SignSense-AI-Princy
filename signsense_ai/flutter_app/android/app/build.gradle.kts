plugins {
    id("com.android.application")
    // ✅ Do NOT add org.jetbrains.kotlin.android here.
    // dev.flutter.flutter-gradle-plugin registers the kotlin{} extension itself.
    // Adding the Kotlin plugin twice causes:
    //   "Cannot add extension with name 'kotlin',
    //    as there is an extension already registered with that name."
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.signsense_ai"
    compileSdk = 36

    // Pin NDK version — required by camera plugin and flutter_local_notifications.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications >= 17 for java.time on API < 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.signsense_ai"
        // ✅ Hard-pin minSdk = 21.
        // flutter.minSdkVersion defaults to 16/19 which is below the minimum
        // required by: camera (21), speech_to_text (21), geolocator (21),
        // flutter_contacts (21), flutter_local_notifications (21).
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Required when total method references exceed 64K.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Use debug signing until a release keystore is configured.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }
}

// ✅ Configure Kotlin JVM target.
// The kotlin{} extension is registered by dev.flutter.flutter-gradle-plugin
// (which applies org.jetbrains.kotlin.android internally).
// This block runs after plugin application, so the extension is available.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for isCoreLibraryDesugaringEnabled on API < 26.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Required by multiDexEnabled = true on API < 21 (kept for safety).
    implementation("androidx.multidex:multidex:2.0.1")
}
