# Hissa D2: Approval screen, Material 3, modular widgets

## Kya badla
1. **Approval step (engine)**: pehle receiver turant accept kar deta tha. Ab nayi file par receiver ka user sender ka naam, file aur 6-digit code dekhta hai aur Accept ya Reject dabata hai. `go` frame aane tak sender kuchh nahi bhejta. 60 s me jawab na aaye, ya koi screen na sun raha ho, to reject (bina dekhe accept kabhi nahi). Resume wali transfer ye step chhodti hai.
   - `lib/core/approval.dart` (ApprovalBroker, ApprovalRequest), engine me `approvals`.
   - Protocol: `docs/PROTOCOL_LAN_V2.md` step 7.
2. **Material 3 theme**: `lib/theme/` ab 5 chhoti files: `vega_colors`, `vega_scheme` (fromSeed + brand), `vega_components` (buttons, card, dialog, sheet, nav bar, progress, input, snackbar), `vega_motion`, `app_theme` (jodta hai). Dynamic color ka hook hai (`dynamicScheme`), abhi band.
3. **Approval UI (6 widget)** `lib/widgets/approval/`: `vega_header`, `link_orbit`, `code_digits`, `trust_banner`, `file_card`, `action_bar`, matn `approval_strings` me ek jagah.
4. **Screens**: `approval_screen.dart` (receiver), `sender_code_screen.dart` (sender). `approval_host.dart` engine ke events sun kar sahi screen kholta hai (`main.dart` me judha).
5. **Tests**: `test/approval_test.dart` (9 tests).

## Speed
Approval sirf shuru me ek baar, chunks se pehle. Data ke raste (AES-GCM, chunk loop) me koi badlav nahi.

## Dhyan dene wali baatein
- Dart yahan compile nahi hua. GitHub Actions ke `flutter test` aur debug APK se pakda jayega.
- App background me ho to Accept screen nahi dikhegi aur 60 s baad reject ho jayega. Notification wala Accept baad ka kaam hai.
- Pehle se maujood screens ke buttons ab M3 theme ka size/shape lete hain (thoda badlav ho sakta hai).
- `acceptPlaintext` abhi bhi true hai (aapka jawab baaki).
- App me font bundle nahi hai, system font chalega.
