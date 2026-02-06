## APK for the app
https://drive.google.com/file/d/17ciC-lb76fR1Tpx6zoZ4Titohies0uje/view?usp=sharing

MedKnows System Installation Guide
================================

System Requirements
-----------------
- Flutter SDK (latest stable version)
- Firebase CLI
- Node.js (for Firebase CLI)
- Android Studio (latest version)
- Android SDK (API level 29 or higher)
- JDK version 11 or higher
- For Windows Development:
  * Windows 10 or later
  * Visual Studio Code

Required Flutter Dependencies
---------------------------
Add these to your pubspec.yaml:
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6  # Primary database dependency
  firebase_storage: ^11.5.6
  firebase_messaging: ^14.7.9
```

Installation Steps
-----------------

1. Android Setup:
   - Set ANDROID_HOME environment variable
   - Enable Developer Options and USB Debugging on your Android device
   - Minimum Android SDK version: API 29 (Android 10)
   - Target Android SDK version: API 33 (Android 13)

2. Firebase Setup:
   - Install Firebase CLI:
     ```
     npm install -g firebase-tools
     ```
   - Login to Firebase:
     ```
     firebase login
     ```
   - Initialize Firebase in your project:
     ```
     flutterfire configure
     ```

3. Clone the Repository:
   Make sure you have access to the project repository and clone it to your local machine.

4. Install Dependencies:
   ```
   flutter pub get
   ```

5. Build and Run:
   - Connect Android device or start an emulator
   - Build the application:
     ```
     flutter build apk --release
     ```
   - The built APK will be in build/app/outputs/flutter-apk/app-release.apk

Android Configuration
-------------------
1. Update android/app/build.gradle:
   ```gradle
   android {
       defaultConfig {
           minSdkVersion 29
           targetSdkVersion 33
       }
   }
   ```

2. Firebase Setup:
   - Place google-services.json in android/app/
   - Ensure android/build.gradle has:
     ```
     classpath 'com.google.gms:google-services:4.4.0'
     ```

Firebase Firestore Setup
-----------------------
1. Database Setup:
   - Go to Firebase Console -> Firestore Database
   - Create a new database in production mode
   - Choose the closest region for better performance
   - Set up Firestore security rules:
     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /{document=**} {
           allow read, write: if request.auth != null;
         }
       }
     }
     ```

2. Firestore Configuration:
   - Initialize Firestore in your main.dart:
     ```dart
     await Firebase.initializeApp();
     FirebaseFirestore.instance.settings = 
         Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
     ```

Troubleshooting
--------------
- Ensure all required dependencies are installed
- Check Flutter doctor output for any issues:
  ```
  flutter doctor
  ```
- For build errors, try cleaning the build:
  ```
  flutter clean
  flutter pub get
  ```

For additional support, please contact the development team.
