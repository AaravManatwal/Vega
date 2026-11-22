# Vega — Google Play Store Release Checklist

## 1. Create Your Release Signing Key (One Time)
Run inside `flutter_app/`:
```bash
keytool -genkey -v -keystore android/vega-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias vega-release
```
Then copy `android/key.properties.example` to `android/key.properties` and fill in your passwords. Keep `vega-release.jks` backed up safely — Play Store requires the same upload key for future app updates.

## 2. Build Play Store App Bundle (`.aab`)
```bash
cd flutter_app
flutter pub get
flutter analyze
flutter build appbundle --release
```
Output file:
`build/app/outputs/bundle/release/app-release.aab`

## 3. Google Play Console Declarations (Pre-Aligned)
- **Target API**: Android 15 (API 35) • **Minimum API**: Android 13 (API 33)
- **Permissions**:
  - `NEARBY_WIFI_DEVICES` (`neverForLocation`) — Used solely for offline Wi-Fi Direct / LAN peer discovery.
  - `CAMERA` — Used solely for scanning peer QR pairing codes.
  - `FOREGROUND_SERVICE_DATA_SYNC` — Keeps large P2P transfers running when the screen turns off.
  - **No** `MANAGE_EXTERNAL_STORAGE`, **no** location permissions, and **no** cloud telemetry SDKs.
- **Data Safety Form**:
  - Does your app collect or share user data? **No** (all transfers occur directly device-to-device over local Wi-Fi/Hotspot; transfer history stays strictly on-device).
- **App Content / Privacy Policy**:
  - Host a static privacy policy page stating Vega operates offline peer-to-peer without collecting personal data, analytics, or file contents.
