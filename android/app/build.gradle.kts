import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply the Google Services plugin only once google-services.json is present.
// This lets the app build before Firebase credentials are supplied (the config
// gate falls back to the native game).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.embervault.blazebound"

    // targetSdk = 36, minSdk = 26 (Android 8.0), compileSdk = 36 for plugin
    // compatibility (see gray_part_pitfalls.md §2/§19).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications 18+ (java.time.*).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.embervault.blazebound"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
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

// ─────────────────────────────────────────────────────────────
// Native config transport (Rust / wreq / BoringSSL)
// ─────────────────────────────────────────────────────────────
// The .so files live in src/main/jniLibs/<abi>/libblazebound_relay.so and
// AGP packs that directory automatically — a normal `flutter build` needs
// nothing here. Rebuild the .so with:
//   powershell android/rust/build_android.ps1
// To fold the Rust build into Gradle, pass `-Prelay.cargo=true`; this stays
// OPT-IN so a machine without the Rust/NDK toolchain can still build the app
// from the committed jniLibs.
if (project.hasProperty("relay.cargo")) {
    val cargoRelay = tasks.register<Exec>("cargoBuildRelay") {
        workingDir = rootProject.projectDir.parentFile
        val script = "android/rust/build_android.ps1"
        commandLine("powershell", "-ExecutionPolicy", "Bypass", "-File", script)
    }
    tasks.matching { it.name == "preBuild" }.configureEach {
        dependsOn(cargoRelay)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
