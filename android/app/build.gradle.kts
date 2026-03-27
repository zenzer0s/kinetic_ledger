plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.kinetic_ledger"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.kinetic_ledger"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

tasks.register<Exec>("uploadToTelegram") {
    group = "upload"
    description = "Uploads the release APK to Telegram."
    commandLine("python3", "${project.projectDir}/../upload_to_telegram.py")
}

afterEvaluate {
    tasks.findByName("assembleRelease")?.finalizedBy("uploadToTelegram")
}

flutter {
    source = "../.."
}
