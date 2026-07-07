import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // Crashlytics stays disabled until firebase_crashlytics is enabled in pubspec
    // id("com.google.firebase.crashlytics")
}

// Release signing — reads android/key.properties (git-ignored). If it's absent
// (local dev, CI without secrets) the release build falls back to the debug key
// so `flutter run --release` still works. Play Store uploads MUST use the real key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Fail fast: never let a Play Store bundle (bundleRelease) be produced with the debug
// fallback key. `flutter run --release` (assembleRelease) is unaffected, so local release
// testing without the keystore still works.
gradle.taskGraph.whenReady {
    if (!hasReleaseKeystore && allTasks.any { it.name.contains("bundleRelease") }) {
        throw GradleException(
            "Refusing to build a store bundle without the release keystore — android/key.properties " +
            "is missing, so this AAB would be signed with the debug key. See android/key.properties.example."
        )
    }
}

android {
    namespace = "com.baahy.baahyapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time APIs on older Android).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.baahy.baahyapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback so `flutter run --release` works without the upload key.
                // Do NOT ship a store build produced with this fallback.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // Enables core library desugaring required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
