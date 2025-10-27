/*
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // FlutterFire
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
// --- Cargar MAPS_API_KEY de local.properties / env / -P ---
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) {
        FileInputStream(f).use { fis -> this.load(fis) }
    }
}

val mapsKey: String = (
        localProps.getProperty("MAPS_API_KEY")
            ?: System.getenv("MAPS_API_KEY")
            ?: (project.findProperty("MAPS_API_KEY") as String?)
            ?: ""
        )


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
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
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
*/
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // FlutterFire
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
// --- Cargar MAPS_API_KEY de local.properties / env / -P ---
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) {
        FileInputStream(f).use { fis -> this.load(fis) }
    }
}

val mapsKey: String = (
        localProps.getProperty("MAPS_API_KEY")
            ?: System.getenv("MAPS_API_KEY")
            ?: (project.findProperty("MAPS_API_KEY") as String?)
            ?: ""
        )


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
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
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
