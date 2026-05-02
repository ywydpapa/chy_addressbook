plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    //id("com.google.gms.google-services")
}

dependencies {
    // Import the Firebase BoM
    //implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    // Add Firebase dependencies as needed
    //implementation("com.google.firebase:firebase-analytics")
    // implementation("com.google.firebase:firebase-auth") // 예시
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

android {
    namespace = "kr.swcore.chy_addressbook"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // 플러그인이 요구하는 NDK 버전

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            keyAlias = "coredjk-002"
            keyPassword = "Core2025%%"
            storeFile = file("E:/pondProject/chy_addressbook/my-release-key.jks")
            storePassword = "Core2025%%"
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.swcore.chy_addressbook"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = true
            isMinifyEnabled = true // 필요에 따라 설정
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
