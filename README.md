# Ooredoo Storm & Bundle (Flutter)

Log in with your Ooredoo number + password, then run Storm (*580#) or Bundle (*585#).
The app calls Ooredoo directly (same endpoints as your Node `ooredooService.js`).

## Setup
```bash
flutter create ooredoo_app --platforms=android,ios
cd ooredoo_app
# copy pubspec.yaml and the lib/ folder from this archive over the generated ones
flutter pub get
flutter run
```

Android release builds need internet permission. In `android/app/src/main/AndroidManifest.xml`,
inside `<manifest>`, before `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
`flutter_secure_storage` needs `minSdkVersion 23` (set it in `android/app/build.gradle`).

## Layout
- `core/ooredoo_api.dart`     login, cookie, silent re-login, /nbservice call
- `core/ooredoo_parser.dart`  Dart port of Ooredooparser.js
- `core/ussd_flow.dart`       remembers number / amount / offer for the receipt (never the PIN)
- `core/ussd_controller.dart` one USSD session: steps, 60 s timer, errors
- `screens/`                  login, home (Storm / Bundle), flow screen
