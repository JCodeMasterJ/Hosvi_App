// android/app/build.gradle.kts

import java.util.Properties
import java.io.FileInputStream

// ---------------------------------------------------------------------
// 1) Cargar key.properties (firma release)
// ---------------------------------------------------------------------
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        FileInputStream(f).use { load(it) }
    }
}

// ---------------------------------------------------------------------
// 2) Cargar MAPS_API_KEY desde local.properties / ENV / -P
// ---------------------------------------------------------------------
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) {
        FileInputStream(f).use { load(it) }
    }
}

val mapsKey: String = (
        localProps.getProperty("MAPS_API_KEY")
            ?: System.getenv("MAPS_API_KEY")
            ?: (project.findProperty("MAPS_API_KEY") as String?)
            ?: ""
        )

// ---------------------------------------------------------------------
// 3) Plugins
// ---------------------------------------------------------------------
plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------
// 4) Configuración Android
// ---------------------------------------------------------------------
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

        // Pasamos la API de Maps al manifest
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    // -----------------------------------------------------------------
    // 4.1 Firmas (debug + release con keystore)
    // -----------------------------------------------------------------
    signingConfigs {
        // Config debug por defecto
        getByName("debug")

        // Configuración de firma para release (usando key.properties)
        create("release") {
            val alias = keystoreProperties.getProperty("keyAlias") ?: ""
            val keyPass = keystoreProperties.getProperty("keyPassword") ?: ""
            val storePass = keystoreProperties.getProperty("storePassword") ?: ""
            val storePath = keystoreProperties.getProperty("storeFile")

            keyAlias = alias
            keyPassword = keyPass
            storePassword = storePass
            if (!storePath.isNullOrBlank()) {
                storeFile = file(storePath)
            }
        }
    }

    // -----------------------------------------------------------------
    // 4.2 Tipos de build
    // -----------------------------------------------------------------
    buildTypes {
        getByName("release") {
            // IMPORTANTE: usar la firma release
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false        // desactiva R8 / ProGuard
            isShrinkResources = false      // no recortar recursos
        }

        maybeCreate("profile").apply {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// ---------------------------------------------------------------------
// 5) Flutter
// ---------------------------------------------------------------------
flutter {
    source = "../.."
}

// ---------------------------------------------------------------------
// 6) Dependencias extra
// ---------------------------------------------------------------------
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
