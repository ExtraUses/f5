pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.13.0 — bumped from 8.9.1 to satisfy Flutter 3.47.7's minimum
    // requirement of AGP 8.11.1. Going to 8.13.0 (latest stable 8.x as of
    // Q4 2025) gives headroom above the minimum so the next Flutter point
    // release won't break CI again.
    //
    // AGP 8.13 requires Gradle 8.13+ — our gradle-wrapper.properties pins
    // Gradle 8.14.3, which satisfies this constraint.
    //
    // DO NOT upgrade to AGP 9.x — that requires the new Android DSL and
    // a separate migration. Stay on AGP 8.x until the project is ready.
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
