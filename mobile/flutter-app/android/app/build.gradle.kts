import java.util.Properties
import java.security.KeyStore

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties().apply {
    val source = rootProject.file("key.properties")
    if (source.isFile) source.inputStream().use { load(it) }
}
fun releaseSetting(environment: String, property: String): String? =
    System.getenv(environment)?.takeIf { it.isNotEmpty() } ?: releaseProperties.getProperty(property)

val releaseStorePath = releaseSetting("MYAAPTHA_ANDROID_KEYSTORE_FILE", "storeFile")
val releaseStorePassword = releaseSetting("MYAAPTHA_ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = releaseSetting("MYAAPTHA_ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = releaseSetting("MYAAPTHA_ANDROID_KEY_PASSWORD", "keyPassword")
val hasReleaseSigning = listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword)
    .all { !it.isNullOrBlank() }

// Debug builds remain usable without release credentials. Release builds never fall back to debug keys.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("release", ignoreCase = true) }) {
        if (!hasReleaseSigning) throw GradleException(
            "Release signing is required. Configure MYAAPTHA_ANDROID_KEYSTORE_FILE, KEYSTORE_PASSWORD, KEY_ALIAS and KEY_PASSWORD (each with the MYAAPTHA_ANDROID_ prefix), or android/key.properties."
        )
        val keyFile = rootProject.file(releaseStorePath!!)
        if (!keyFile.isFile) throw GradleException("The configured release keystore file is missing.")
        try {
            val store = KeyStore.getInstance(keyFile, releaseStorePassword!!.toCharArray())
            if (!store.isKeyEntry(releaseKeyAlias) || store.getKey(releaseKeyAlias, releaseKeyPassword!!.toCharArray()) == null)
                throw GradleException("The configured release alias must contain a private signing key.")
            val certificate = store.getCertificate(releaseKeyAlias) as? java.security.cert.X509Certificate
                ?: throw GradleException("The release signing certificate is missing.")
            certificate.checkValidity()
            if (releaseKeyAlias.equals("androiddebugkey", ignoreCase = true) ||
                certificate.subjectX500Principal.name.contains("CN=Android Debug", ignoreCase = true))
                throw GradleException("Android debug signing identities cannot be used for release builds.")
        } catch (error: GradleException) { throw error }
        catch (error: Exception) { throw GradleException("Release signing validation failed. Check the keystore, alias, passwords and certificate validity.") }
    }
}

android {
    namespace = "com.myaaptha.myaaptha_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.myaaptha.myaaptha_mobile"
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
                storeFile = rootProject.file(releaseStorePath!!)
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
