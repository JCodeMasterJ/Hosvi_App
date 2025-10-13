/*
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hosvi.app"
    compileSdk = 36 //34

    defaultConfig {
        applicationId = "com.hosvi.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }
}

flutter { source = "../.." }

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
*/
plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // FlutterFire
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hosvi.app"

    compileSdk = 36

    defaultConfig {
        applicationId = "com.hosvi.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    // Usamos la firma debug mientras no tengas release keystore
    signingConfigs {
        getByName("debug")
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false        // <-- desactiva R8 proguard
            isShrinkResources = false      // <-- no recortar recursos
        }
        maybeCreate("profile").apply {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
