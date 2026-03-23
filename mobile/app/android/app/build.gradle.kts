import com.android.build.api.dsl.SigningConfig
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // START: FlutterFire Configuration (disabled for debug and profile builds -- end of file)
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
}

fun loadPropertiesOrThrow(path: String): Properties {
    val props = Properties()
    val file = rootProject.file(path)

    if (!file.exists()) {
        throw GradleException("Missing $path. This file is required for requested build.")
    }

    file.inputStream().use { props.load(it) }
    return props
}

fun SigningConfig.applyFromPropertiesFile(propsPath: String) {
    val props = loadPropertiesOrThrow(propsPath)
    val storeFilePath = props.getProperty("storeFile")
        ?: throw GradleException("Missing 'storeFile' in signing properties")

    val resolvedStoreFile = file(storeFilePath)
    if (!resolvedStoreFile.exists()) {
        throw GradleException("Key store file does not exist at path $storeFilePath")
    }

    storeFile = resolvedStoreFile
    storePassword = props.getProperty("storePassword")
        ?: throw GradleException("Missing 'storePassword' in signing properties")

    keyAlias = props.getProperty("keyAlias")
        ?: throw GradleException("Missing 'keyAlias' in signing properties")

    keyPassword = props.getProperty("keyPassword")
        ?: throw GradleException("Missing 'keyPassword' in signing properties")
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_21
    }
}

android {
    signingConfigs {
        create("release") {
            applyFromPropertiesFile("release.properties")
        }

        create("debugTeam") {
            applyFromPropertiesFile("debug.properties")
        }
    }
    // Print values during configuration phase
    println("Flutter Compile SDK Version: ${flutter.compileSdkVersion}")
    println("Flutter Target SDK Version: ${flutter.targetSdkVersion}")
    println("Flutter Min SDK Version: ${flutter.minSdkVersion}")
    println("Flutter NDK Version: ${flutter.ndkVersion}")
    println("Flutter Version Code: ${flutter.versionCode}")
    println("Flutter Version Name: ${flutter.versionName}")

    namespace = "com.sesori.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // Required by flutter_local_notifications for java.time APIs on Android API < 26
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.sesori.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            resValue("string", "app_name", "Sesori")

            proguardFiles.add(getDefaultProguardFile("proguard-android-optimize.txt"))
//            proguardFiles.add(getDefaultProguardFile("proguard-rules.pro"))
            isMinifyEnabled = true
        }

        debug {
            signingConfig = signingConfigs.getByName("debugTeam")
            applicationIdSuffix = ".debug"
            resValue("string", "app_name", "Sesori DEBUG")

            isMinifyEnabled = false
        }

        getByName("profile") {
            signingConfig = signingConfigs.getByName("debugTeam")
            applicationIdSuffix = ".profile"
            resValue("string", "app_name", "Sesori PROFILE")

            proguardFiles.add(getDefaultProguardFile("proguard-android-optimize.txt"))
//            proguardFiles.add(getDefaultProguardFile("proguard-rules.pro"))
            isMinifyEnabled = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications for java.time APIs on Android API < 26
    // https://mvnrepository.com/artifact/com.android.tools/desugar_jdk_libs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // https://developer.android.com/jetpack/androidx/versions/all-channel
//    implementation("androidx.core:core-splashscreen:1.2.0")
//    implementation("androidx.constraintlayout:constraintlayout:2.2.1")
    implementation("androidx.activity:activity-ktx:1.13.0")
}

// Only profile builds are excluded from Firebase on Android.
tasks.matching { task ->
    task.name == "processProfileGoogleServices" ||
        (task.name.contains("Crashlytics") && !task.name.contains("Release"))
}.configureEach {
    enabled = false
}
