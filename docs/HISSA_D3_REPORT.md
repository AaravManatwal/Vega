# Hissa D3: Premium Home + Transfer progress

## Kya badla
- **Home** (`lib/screens/home_screen.dart`, naya): header, device ka naam, **radar card** (aas-paas ke device chamakte dot ki tarah, sonar rings, ghoomti beam), **Send / Receive tiles** (dabane par thoda dabte hain), live transfer card, Browser aur Windows Share, **Material 3 navigation bar** (Home, History, Settings). Purana drawer aur jali/jharokha background hata diya.
- **Radar** ke liye `startQuietDiscovery()` (bina permission maange mDNS se device dhundhta hai). Send screen ka apna discovery wahi rehta hai.
- **Transfer progress screen** (`transfer_progress_screen.dart`): gol ring (neela se sona, chamak, 38 MB/s, kitna samay baaki), file card, Encrypted / Verified tags, Pause/Resume aur Cancel (sirf sender me; receiver me engine me cancel abhi nahi).
- **Auto-open**: receiver Accept dabate hi, aur sender code check ke baad, progress screen khud khulti hai (`approval_host.dart`).
- Widgets: `widgets/home/{radar_card, action_tile, live_transfer_card}.dart`, `widgets/progress/progress_ring.dart`.
- Tests: `test/approval_ui_test.dart` (4 widget tests).

## Faisle
- Bina encryption wale transfer allowed rahe, par approval screen par saaf warning aati hai aur Accept dabana padta hai (sender ka apna toggle toot na jaye).
- Pause/Resume: sender ki progress screen par hai (engine me pehle se tha; pehle galti se maine kaha tha ki nahi hai, baad me theek kiya).

## Speed
Sirf UI. Data wale raste me koi badlav nahi. Ring ka animation ek AnimationController hai jo screen ke saath ruk jata hai; "reduce motion" on ho to animation band.

## Baaki / jokhim
- Dart yahan compile nahi hua, CI se pakda jayega.
- Radar tabhi bharta hai jab dusre device par Vega Receive mode me ho (mDNS).
- Home par Android back/predictive back aur tablet layout abhi nahi dekhe.
- Folder transfer aur Windows scaffold baaki.

## Jaanch ke baad theek kiye (compile errors)
- `progress_ring.dart`: `FontFeature` ka import chhoot gaya tha.
- `splash_screen.dart` (purani file): `(_, _, _)` Dart 3.7 ki cheez hai, par pubspec 3.4 maangta hai. `(_, __, ___)` kiya.

## D3.1 — Receiver-side cancel (2026-11-22)
- Engine: `_receiverCancels[taskId]` registered after the handshake; `cancelTransfer(taskId)` now stops a sender OR a receiver. On receiver cancel the partial temp file is discarded, a `cancelled` task is emitted ("Aapne transfer rok diya") and the socket is destroyed; the sender sees a normal connection failure. No partial is parked, so it cannot be resumed.
- UI: receiver progress screen now has "Peeche jaaiye" (primary) and "Transfer rokein" (secondary).
- No change to the chunk path, so speed is unaffected. Not compiled; CI will check.

## D3.2 — Incoming-file notification (2026-11-22)
- New `lib/services/approval_notifier.dart` (package `flutter_local_notifications` >=18.0.1 <19). When an approval request arrives while the app is NOT in the foreground, a heads-up notification "<name> file bhejna chahta hai" appears (auto-expires after 60 s, same as the approval window).
- Tapping it opens Vega on the Accept screen. There is deliberately NO Accept button on the notification: the 6-digit code must be compared on screen first. "Mana karein" (Reject) is offered as a quick action (opens the app, then declines).
- The notification is cleared as soon as the request is resolved. POST_NOTIFICATIONS permission is requested at start (already in the manifest). Without permission the in-app screen still works.
- R8 keep rules added to `proguard-rules.pro` for release builds.
- Needs the Foreground service to keep the process alive in the background (already used in Receive mode). Unverified on a real device; the package version resolves on CI (`flutter pub get`).

## D3.3 — First-run guide, History, Settings, About (2026-11-22)
- `onboarding_screen.dart`: 3 pages (offline speed / code check / resume), shown once; flag `vega_onboarded_v1` in SharedPreferences. Splash decides: first run → onboarding → Home. If prefs fail it goes straight to Home.
- History: tinted direction icon, "Bheja/Mila", Verified + relative time, failed items in red, friendly empty state, confirm dialog before clearing (list only; saved files untouched).
- Settings: Hinglish, grouped (Device / Suraksha / Speed / Dikhaawa). Device name now also saves when tapping outside the field. Same settings fields as before; chunk size and encryption behaviour unchanged, so no speed change.
- About: four icon cards, Hinglish. Class names unchanged, so Home's navigation is untouched.
- Not compiled. Uses Dart records (Dart 3.0+, fine for sdk >=3.4).
