# Vega: Hissa D1 (Resume) Report, 2026-11-19

Niyam: Android 13+ (minSdk 33), speed kam nahi, modular code, UI me koi badlav nahi.

## Kya bana
Connection toot jaye to transfer wahin se dobara shuru hota hai, apne aap.
- Sender: network drop par 5 baar tak khud dobara judta hai (1, 2, 4, 8, 16 second ruk kar). Refusal ya verification fail par dobara koshish nahi.
- Receiver: adhoori file (sirf verify hue poore chunks) 10 minute rakhta hai, max 4. Phir mita deta hai aur transfer "failed" dikhata hai.
- Pehchaan: dobara judte waqt sender purane session ka saboot deta hai (naye handshake se bandha, replay nahi ho sakta). Saboot galat ho to receiver reject karta hai.
- Final SHA-256 poori file par hi hai (sender aur receiver dono pehle se aaye bytes dobara hash karte hain), isliye resume ke baad bhi "verified" sach hai.
- UI ka koi screen nahi badla. Receiver par us beech me status "paused" (connection lost) dikhega, sender par "connecting".

Naye/badle: `lib/core/partial_transfer.dart` (naya), `lib/core/transfer_engine.dart` (sender loop aur receiver resume), `lib/core/security/session_crypto.dart` (resumeKey, resumeProof, resumedConfirm), spec `docs/PROTOCOL_LAN_V2.md` me "Resume" hissa.

## Verify
- `tools/lan_v2_resume_sim.mjs`: protocol ka chalne wala model (normal, 3 baar drop, pehle chunk se pehle drop, nakli saboot reject, replay nahi) pass.
- Browser lab me wahi demo (3 baar connection todo: file byte-exact milti hai; nakli sender reject hota hai). Vector check 5/5, hamle 8/8.
- Naye vectors (`resumeKey`, `resumeProof`, `resumedConfirm`) Dart test me bhi jude hain.
- **Dart code compile/run nahi hua.** Engine ka resume path asli sockets par chalne wala test abhi nahi hai (platform channels chahiye). Pehle GitHub Actions se APK banaiye, phir do phone par ek badi file bhejte waqt Wi-Fi band-chalu karke dekhiye.

## Jo baaki hai
Approval/match-code screen (UI), unencrypted ko default se band karna, folder transfer, Windows scaffold: aapki haan ka intezaar.
