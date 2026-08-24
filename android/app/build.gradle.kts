plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.anna_salon_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.anna_salon_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("brimoonRelease") {
            val signingKeyPath = System.getenv("BRIMOON_SIGNING_KEY_PATH")
                ?: "C:/projects/.signing/brimoon-signing-key.keystore"
            storeFile = file(signingKeyPath)
            storePassword = System.getenv("BRIMOON_SIGNING_STORE_PASSWORD") ?: "android"
            keyAlias = System.getenv("BRIMOON_SIGNING_KEY_ALIAS") ?: "androiddebugkey"
            keyPassword = System.getenv("BRIMOON_SIGNING_KEY_PASSWORD") ?: "android"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("brimoonRelease")
        }
    }
}

flutter {
    source = "../.."
}
