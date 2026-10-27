import java.util.Properties

plugins {
    id("com.android.application")
    id("com.android.built-in-kotlin")
    // The Flutter Gradle Plugin must be applied after the Android plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation("androidx.biometric:biometric:1.1.0")
}

val contributorBuild = providers.gradleProperty("anchContributor").orNull == "true"
val validationSigningPropertiesFile = rootProject.file("validation-signing.properties")
if (!contributorBuild && !validationSigningPropertiesFile.isFile) {
    throw GradleException(
        "Missing local validation signing config: android/validation-signing.properties",
    )
}

val validationSigningProperties = Properties().apply {
    if (!contributorBuild) {
        validationSigningPropertiesFile.inputStream().use(::load)
    }
}

val releaseSigningPropertiesFile = rootProject.file("release-signing.properties")
val releaseSigningRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (contributorBuild && releaseSigningRequested) {
    throw GradleException("Contributor builds support Debug and Profile only")
}
if (releaseSigningRequested && !releaseSigningPropertiesFile.isFile) {
    throw GradleException(
        "Missing local release signing config: android/release-signing.properties",
    )
}

val releaseSigningProperties = Properties().apply {
    if (!contributorBuild && releaseSigningPropertiesFile.isFile) {
        releaseSigningPropertiesFile.inputStream().use(::load)
    }
}

fun requiredValidationSigningProperty(name: String): String {
    return validationSigningProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing validation signing property: $name")
}

fun requiredReleaseSigningProperty(name: String): String {
    return releaseSigningProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing release signing property: $name")
}

fun requiredReleaseSigningFile(name: String): File {
    val file = rootProject.file(requiredReleaseSigningProperty(name))
    if (!file.isFile) {
        throw GradleException("Missing release signing file configured by: $name")
    }
    return file
}

fun requiredReleaseSigningPassword(): String {
    val password = requiredReleaseSigningFile("passwordFile").readText().trim()
    if (password.isEmpty()) {
        throw GradleException("Release signing password file is empty")
    }
    return password
}

android {
    namespace = "icu.codealive.anch"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (contributorBuild) "icu.codealive.anch.contributor" else "icu.codealive.anch"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!contributorBuild) create("validation") {
            storeFile = rootProject.file(requiredValidationSigningProperty("storeFile"))
            storePassword = requiredValidationSigningProperty("storePassword")
            keyAlias = requiredValidationSigningProperty("keyAlias")
            keyPassword = requiredValidationSigningProperty("keyPassword")
        }
        if (!contributorBuild && releaseSigningPropertiesFile.isFile) {
            create("release") {
                storeFile = requiredReleaseSigningFile("storeFile")
                storePassword = requiredReleaseSigningPassword()
                keyAlias = requiredReleaseSigningProperty("keyAlias")
                keyPassword = requiredReleaseSigningPassword()
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName(if (contributorBuild) "debug" else "validation")
        }
        getByName("profile") {
            signingConfig = signingConfigs.getByName(if (contributorBuild) "debug" else "validation")
        }
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

androidComponents {
    beforeVariants(selector().withBuildType("release")) { variant ->
        if (contributorBuild) variant.enable = false
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
