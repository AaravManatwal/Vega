# Vega: Hissa B (Secure transfer protocol) Report, 2026-11-18

Niyam: Android 13+ (minSdk 33), speed kam nahi, modular code, UI me koi design change nahi.

## Kya bana
Protocol spec: `docs/PROTOCOL_LAN_V2.md`.
Naye Flutter modules (`flutter_app/lib/core/security/`): `session_crypto.dart` (X25519, HKDF, MACs), `pairing.dart` (QR payload, 10 minute offer, match code info), aur `frame_codec.dart` me `FrameInbox`.
Reference + vectors: `tools/lan_v2_vectors.mjs` aur `flutter_app/test/vectors/lan_v2.json`. Tests: `flutter_app/test/lan_v2_test.dart`.

## Kya theek hua
1. **Plaintext secret khatam.** Pehle sender `sessionSecretHex` ko bina encrypt kiye bhejta tha. Ab key X25519 (dono taraf ephemeral) se banti hai, secret kabhi network par nahi jaata.
2. **QR se receiver ki pehchaan.** QR me receiver ki public key aur 128-bit random secret hai (pehle UUID se bana secret). QR har session me naya banta hai aur 10 minute me expire hota hai.
3. **Match code (6 ank)** dono phone par same banta hai. Engine ye `handshakes` stream se deta hai.
4. **Downgrade nahi ho sakta.** Encryption on/off, file ka naam, size, chunk size sab handshake me bandhe hain. Beech me koi badle to sender reject kar deta hai.
5. **Chunk ki position bandhi hai** (AAD me index, offset, size). Reorder, repeat ya drop pakda jaata hai.
6. **"Verified" sach hua.** Sender tabhi verified dikhata hai jab receiver apna hash aur bytes ek MAC ke saath bheje. Pehle sender bina puchhe verified likh deta tha.
7. **Receiver ki hifazat.** Max 8 ek saath connection, 15 second me handshake nahi to band, kharab version/mode/key par reject.
8. **Sender memory.** Pehle poori file socket queue me ja sakti thi. Ab har 4 chunk par flush hota hai (memory bounded). Isse speed kam nahi honi chahiye, par asli phone par naap nahi hua.
9. **Purana bug:** QR ka scheme `vega://` banta tha aur scanner `sampreshan` dhoondhta tha, to QR pairing chal hi nahi rahi thi. Ab dono `vega`.

## Speed ke baare me
AES-256-GCM hi rakha (hardware accelerated). ChaCha20 nahi liya, kyunki wo Android 13+ phone par aam taur par dhima hoga. Har chunk par sirf ek chhoti AAD string judi hai. Handshake me ek extra round trip (kuch millisecond).

## Verify kaise hua
- Node reference: RFC 7748 vector, dono roles ki key barabar, transcript downgrade ko bandhta hai.
- Browser (WebCrypto) me alag implementation ne wahi 4 cases reproduce kiye, 8 hamle fail hue, 5/5 vector check pass.
- **Dart code yahan compile ya run nahi hua** (Dart installed nahi). Sirf bracket/syntax ka mota check hua. `flutter test` CI me hai. Sabse pehle GitHub Actions chalaiye. Compile error aaye to mujhe log bhej dijiye, main theek kar dunga.

## Jo abhi baaki hai
- **UI approval / match code screen**: receiver par "ye device bhej raha hai, code 123456, Accept?" aur sender par code dikhana. Ye UI badlav hai, isliye aapki haan chahiye. Tab tak `requireAuthenticatedPeers` false hai, yaani nearby list se bheja gaya (bina QR) transfer encrypted hai par pehchana hua nahi.
- **Resume** (beech se dobara shuru) abhi nahi hai. Alag se karenge.
- Receiver abhi sender ka "unencrypted" transfer le leta hai (aapka toggle). Chahein to default band kar sakte hain.
- Web (React/Express) ka encryption alag hai, usme badlav nahi hua.
