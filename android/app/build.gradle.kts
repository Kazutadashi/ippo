import java.io.FileInputStream
import java.util.Properties

// The release key's settings (where the key file is, and its
// passwords): a file named by the IPPO_KEY_PROPERTIES environment
// variable, or else android/key.properties. Neither is ever committed
// (android/.gitignore). Without one, release builds are signed with the
// debug key, which is fine for testing but not for sharing: see
// "Signing a release" in docs/development-setup.md.
val keyPropertiesFile: File? =
    (System.getenv("IPPO_KEY_PROPERTIES")?.let { file(it) } ?: rootProject.file("key.properties"))
        .takeIf { it.exists() }
val keyProperties = Properties().apply {
    keyPropertiesFile?.let { FileInputStream(it).use { stream -> load(stream) } }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.ippo.ippo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.ippo.ippo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile != null) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The release key when its settings are there, else the debug
            // key, so `flutter run --release` still works without one.
            signingConfig = if (keyPropertiesFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
