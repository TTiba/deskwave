plugins {
    id("com.android.application")
}

android {
    namespace = "app.deskweave.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.deskweave.android"
        minSdk = 26
        targetSdk = 36
        versionCode = 6
        versionName = "0.3.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
