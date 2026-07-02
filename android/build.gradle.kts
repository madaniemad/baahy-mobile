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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
