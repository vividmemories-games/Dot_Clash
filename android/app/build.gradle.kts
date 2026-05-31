import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Closed testing: flutter build ... --dart-define=BETA_ADS=true --android-project-arg=betaAds=true
val betaAds = project.findProperty("betaAds")?.toString() == "true"
val prodAdmobAppId = "ca-app-pub-6626056478655263~7661116755"
val testAdmobAppId = "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.vividmemories.dotclash"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ── Flavors ───────────────────────────────────────────────────────────────
    // Run with:  flutter run --flavor dev   (default for daily development)
    //            flutter run --flavor prod  (production build)
    // Both require --dart-define=FLAVOR=<flavor> for the Dart layer.
    // See SETUP.md §  "Running the app" for complete commands.
    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            // Uses google-services.json client for com.vividmemories.dotclash.dev
            // android/app/src/dev/google-services.json
        }
        create("prod") {
            dimension = "env"
            // uses android/app/src/prod/google-services.json (or fallback: android/app/)
        }
    }

    defaultConfig {
        applicationId = "com.vividmemories.dotclash"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] =
            if (betaAds) testAdmobAppId else prodAdmobAppId
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                println(
                    "WARNING: android/key.properties missing — release AAB is signed with debug. " +
                        "See SETUP.md §8 and android/key.properties.example before Play upload.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
