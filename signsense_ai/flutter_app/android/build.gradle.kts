// ✅ Root build.gradle.kts — AGP 9 compatible.
// Repository declarations have moved to settings.gradle.kts
// under dependencyResolutionManagement{} (the AGP 9 standard).
// The allprojects{repositories{}} block is intentionally removed to avoid
// the "Build was configured to prefer settings repositories" warning.

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
