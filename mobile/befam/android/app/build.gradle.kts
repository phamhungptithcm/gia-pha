import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

fun envOrProperty(envName: String, propertyName: String): String? {
    val envValue = System.getenv(envName)?.trim()
    if (!envValue.isNullOrEmpty()) {
        return envValue
    }
    val propertyValue = (keystoreProperties.getProperty(propertyName) ?: "").trim()
    return propertyValue.ifEmpty { null }
}

val releaseStoreFilePath = envOrProperty("ANDROID_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = envOrProperty("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = envOrProperty("ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = envOrProperty("ANDROID_KEY_PASSWORD", "keyPassword")
val hasReleaseSigning =
    !releaseStoreFilePath.isNullOrEmpty() &&
    !releaseStorePassword.isNullOrEmpty() &&
    !releaseKeyAlias.isNullOrEmpty() &&
    !releaseKeyPassword.isNullOrEmpty() &&
    file(releaseStoreFilePath).exists()
val isReleaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true)
}
if (isReleaseTaskRequested && !hasReleaseSigning) {
    throw GradleException(
        "Missing Android release signing configuration. Set ANDROID_KEYSTORE_PATH, " +
            "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD " +
            "or configure android/key.properties before running release tasks.",
    )
}

android {
    namespace = "com.familyclanapp.befam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.familyclanapp.befam"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("androidx.browser:browser:1.8.0")
}

flutter {
    source = "../.."
}
