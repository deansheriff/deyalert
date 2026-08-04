plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = providers.gradleProperty("DEY_ALERT_KEYSTORE_PATH")
    .orElse(providers.environmentVariable("DEY_ALERT_KEYSTORE_PATH"))
    .orNull
val releaseStorePassword = providers.gradleProperty("DEY_ALERT_STORE_PASSWORD")
    .orElse(providers.environmentVariable("DEY_ALERT_STORE_PASSWORD"))
    .orNull
val releaseKeyAlias = providers.gradleProperty("DEY_ALERT_KEY_ALIAS")
    .orElse(providers.environmentVariable("DEY_ALERT_KEY_ALIAS"))
    .orNull
val releaseKeyPassword = providers.gradleProperty("DEY_ALERT_KEY_PASSWORD")
    .orElse(providers.environmentVariable("DEY_ALERT_KEY_PASSWORD"))
    .orNull
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseRequested && listOf(
        releaseKeystorePath,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).any { it.isNullOrBlank() }
) {
    throw GradleException("Release builds require all DEY_ALERT signing variables.")
}

android {
    namespace = "com.deyalert.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.deyalert.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            (project.findProperty("GOOGLE_MAPS_API_KEY") as String?) ?: ""
    }

    signingConfigs {
        if (releaseKeystorePath != null) {
            create("release") {
                storeFile = file(releaseKeystorePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
