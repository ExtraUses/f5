buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Kotlin 2.1.0 — must match the version in settings.gradle.kts
        // (org.jetbrains.kotlin.android version "2.1.0"). A mismatch
        // between the Kotlin Gradle plugin and the Kotlin Compose compiler
        // plugin causes "Plugin version mismatch" build failures.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

plugins {
    // Compose compiler plugin version MUST match the Kotlin version (2.1.0).
    // In Kotlin 2.0+, the Compose compiler is bundled with the Kotlin
    // Gradle plugin, so both versions must be identical.
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val alignJvm: Project.() -> Unit = {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "11"; targetCompatibility = "11"
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) }
        }
    }
    if (state.executed) alignJvm() else afterEvaluate { alignJvm() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
