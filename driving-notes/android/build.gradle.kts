allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// whisper_ggml's own Android module is published compiled against
// android-34, but its ffmpeg_kit_flutter_new_min dependency requires
// compileSdk 35+. Force every Android library module (all Flutter plugins,
// not just our app) to compile against the same, newer SDK so they match.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { android ->
            if ((android.compileSdk ?: 0) < 36) {
                android.compileSdk = 36
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
