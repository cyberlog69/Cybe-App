allprojects {
    repositories {
        google()
        mavenCentral()
    }
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-deprecation", "-Xlint:-options"))
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

    // Auto-patch legacy pub-cache plugins that contain jcenter(), rootProject.allprojects, or stray braces
    val buildGradleFile = file("build.gradle")
    if (buildGradleFile.exists()) {
        var content = buildGradleFile.readText()
        var changed = false
        if (content.contains("jcenter()")) {
            content = content.replace("jcenter()", "mavenCentral()")
            changed = true
        }
        if (content.contains("rootProject.allprojects")) {
            content = content.replace(Regex("""rootProject\.allprojects\s*\{[\s\S]*?\}"""), "")
            changed = true
        }
        // Fix connectivity_plus malformed build.gradle (stray closing brace after buildscript block)
        if (content.contains(Regex("""}\n{2,}}\n\napply plugin"""))) {
            content = content.replace(Regex("""}\n{2,}}\n\napply plugin"""), "}\n\napply plugin")
            changed = true
        }
        if (changed) {
            buildGradleFile.writeText(content)
        }
    }

    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
