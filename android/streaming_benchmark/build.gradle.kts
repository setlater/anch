import java.util.Properties

plugins {
    id("com.android.application")
}

val validationSigningPropertiesFile = rootProject.file("validation-signing.properties")
if (!validationSigningPropertiesFile.isFile) {
    throw GradleException(
        "Missing local validation signing config: android/validation-signing.properties",
    )
}

val validationSigningProperties = Properties().apply {
    validationSigningPropertiesFile.inputStream().use(::load)
}

fun requiredValidationSigningProperty(name: String): String {
    return validationSigningProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing validation signing property: $name")
}

android {
    namespace = "icu.codealive.anch.streamingbenchmark"
    compileSdk = 36

    defaultConfig {
        applicationId = "icu.codealive.anch.benchmark"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0-benchmark"
    }

    signingConfigs {
        create("validation") {
            storeFile = rootProject.file(requiredValidationSigningProperty("storeFile"))
            storePassword = requiredValidationSigningProperty("storePassword")
            keyAlias = requiredValidationSigningProperty("keyAlias")
            keyPassword = requiredValidationSigningProperty("keyPassword")
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("validation")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
