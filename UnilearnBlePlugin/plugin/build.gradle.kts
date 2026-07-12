plugins {
    id("com.android.library")
    kotlin("android")
}

val pluginName = "UnilearnBLE"
val pluginPackageName = "com.unilearn.ble"

android {
    namespace = pluginPackageName
    compileSdk = 35

    defaultConfig {
        minSdk = 23
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.6.0.stable")
}

val copyDebugAar by tasks.registering(Copy::class) {
    dependsOn("assembleDebug")
    from(layout.buildDirectory.file("outputs/aar/plugin-debug.aar"))
    into(layout.projectDirectory.dir("export_scripts_template/bin/debug"))
    rename { "$pluginName-debug.aar" }
}

val copyReleaseAar by tasks.registering(Copy::class) {
    dependsOn("assembleRelease")
    from(layout.buildDirectory.file("outputs/aar/plugin-release.aar"))
    into(layout.projectDirectory.dir("export_scripts_template/bin/release"))
    rename { "$pluginName-release.aar" }
}

tasks.register("packagePlugin") {
    dependsOn(copyDebugAar, copyReleaseAar)
}
