# EduTrack Pro - APK உருவாக்கும் முறை

1. Flutter SDK நிறுவவும் (https://docs.flutter.dev/get-started/install) + Android SDK (Android Studio).
2. இந்த ஃபோல்டரில் டெர்மினல் திறந்து:

   flutter create --org com.edutrack --project-name edutrack_pro --platforms android .
   flutter pub get
   flutter analyze
   flutter build apk --release

3. APK கிடைக்கும் இடம்: build/app/outputs/flutter-apk/app-release.apk
4. போனில் நிறுவ: APK ஐ மாற்றி, "Unknown sources" அனுமதி கொடுக்கவும்.

(`flutter create .` ஏற்கனவே உள்ள lib/main.dart மற்றும் pubspec.yaml ஐ மாற்றாது.)
