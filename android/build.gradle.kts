allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// FIREBASE: the google-services plugin is declared in settings.gradle.kts (plugins block)
// and applied in app/build.gradle.kts. It must NOT be added here — a plugins {} block
// after allprojects {} above is invalid in a root build.gradle.kts.

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

// Some Flutter plugins (e.g. sentry_flutter's bundled Android SDK) still request
// Kotlin language/api version 1.6, which Kotlin 2.2 no longer supports. Raise any
// module that requests a version below 1.8 up to 1.8 — modern modules (which leave
// these unset) are left untouched.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            val min = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8
            if ((languageVersion.orNull ?: min) < min) languageVersion.set(min)
            if ((apiVersion.orNull ?: min) < min) apiVersion.set(min)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
