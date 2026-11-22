# Vega (वेग) — Flutter + Kotlin Hybrid App

High-speed offline-first P2P file transfer app by **Manatwal Innovations**, engineered for:
1. **Phase 1 — Android ↔ Android** (Wi-Fi Direct + 5 GHz LocalOnlyHotspot + mDNS + TCP Socket `Isolate`)
2. **Phase 2 — Android ↔ Windows** (same Dart TCP socket & mDNS protocol compiles natively to Windows)
3. **Phase 3 — Android ↔ Browser** (embedded `shelf` HTTP portal on port `8080`)

## Play Store Compliance
- `minSdk = 33` (Android 13+) and `targetSdk = 35` (Android 15)
- Zero `MANAGE_EXTERNAL_STORAGE` and zero Location permission — uses Play-Store-safe Photo Picker/SAF, `MediaStore` export into `Downloads/Vega/`, and `NEARBY_WIFI_DEVICES` (`neverForLocation`)

## Build Instructions (Android Studio / CLI)
```bash
cd flutter_app
flutter pub get

# Debug APK for phone testing:
flutter build apk --debug

# Play Store Release Bundle (.aab):
# Needs android/key.properties; without it the release build fails on purpose
# (it is never signed with the debug key).
flutter build appbundle --release

# Windows Desktop App (.exe):
# Run scripts/enable_windows_firewall.ps1 as Administrator once to allow ports 47890, 8080 & mDNS 5353
flutter config --enable-windows-desktop
flutter create --platforms=windows .
flutter build windows --release
```

## Security and tests
- Phone-to-phone protocol: `../docs/PROTOCOL_LAN_V2.md` (X25519 + HKDF + AES-256-GCM, QR-pinned receiver, match code, verified only after the receiver's MAC).
- `flutter test` runs the protocol vectors in `test/vectors/lan_v2.json`; the server-side tests run with `npm test`.
- GitHub Actions builds a debug APK (`vega-debug-apk` artifact) so you can test from a phone without a PC.
- Browser portal: open the full link shown in the app (it contains `?k=` access key).
