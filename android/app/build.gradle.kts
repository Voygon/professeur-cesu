plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter doit être appliqué après Android et Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cesu.professeur.professeur_cesu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Active le desugaring — nécessaire pour flutter_local_notifications
        // Permet d'utiliser les APIs Java modernes sur tous les Androids
        isCoreLibraryDesugaringEnabled = true

        // On garde Java 17 qui est la version recommandée pour Flutter récent
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cesu.professeur.professeur_cesu"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signature debug pour l'instant — à changer avant publication
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Bibliothèque de desugaring — requise par flutter_local_notifications
    // En Kotlin DSL : parenthèses obligatoires, pas de guillemets simples
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}