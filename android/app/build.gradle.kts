import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "io.studentry.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.studentry.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Production stays HTTPS-only. A release-signed APK may opt into
        // private-LAN HTTP for physical-device testing via the Gradle property
        // `allowLocalLanApi=true`.
        manifestPlaceholders["usesCleartextTraffic"] = "false"
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            val allowLocalLanApi = providers.gradleProperty("allowLocalLanApi")
                .orNull
                ?.toBooleanStrictOrNull()
                ?: false
            manifestPlaceholders["usesCleartextTraffic"] = allowLocalLanApi.toString()
            val releaseRequested = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            if (releaseRequested && !keystorePropertiesFile.exists()) {
                throw GradleException(
                    "Missing android/key.properties. Release artifacts must be signed with the production keystore."
                )
            }
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

// Flutter 3.44 can leave Android's generated registrant from a previous
// debug/integration-test run while correctly excluding dev plugins from the
// release Gradle dependencies. Remove only that stale dev-plugin block before
// release Java compilation; normal plugins and integration-test builds remain
// unchanged.
val filterDevPluginsFromReleaseRegistrant by tasks.registering {
    outputs.upToDateWhen { false }
    doLast {
        val registrant = file(
            "src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
        )
        if (!registrant.exists()) return@doLast

        var source = registrant.readText()
        val marker = "dev.flutter.plugins.integration_test.IntegrationTestPlugin"
        val markerIndex = source.indexOf(marker)
        if (markerIndex < 0) return@doLast

        val blockStart = source.lastIndexOf("    try {", markerIndex)
        val nextBlock = source.indexOf("    try {", markerIndex + marker.length)
        if (blockStart >= 0 && nextBlock > blockStart) {
            source = source.removeRange(blockStart, nextBlock)
            registrant.writeText(source)
        }
    }
}

tasks.matching { it.name == "compileReleaseJavaWithJavac" }.configureEach {
    dependsOn(filterDevPluginsFromReleaseRegistrant)
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.14.1"))
    implementation("com.google.firebase:firebase-messaging")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

}
