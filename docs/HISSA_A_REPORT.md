# Vega: Hissa A (Security) Report, 2026-11-18

Niyam jo follow kiye: Android 13+ (minSdk 33 waisa hi), transfer speed kam nahi, modular code, UI me koi layout/design change nahi.

## Naye modules
Server (`src/server/security/`): `ids.ts` (safe naam/ID, safeJoin), `tokens.ts`, `sessions.ts`, `rateLimit.ts`, `network.ts`, `guards.ts`. Client: `src/lib/apiClient.ts`.
Flutter (`flutter_app/lib/core/security/`): `frame_codec.dart`, `safe_names.dart`, `access_key.dart`.

## Kya theek hua
1. **Vault `..` bug**: transferId ab sirf `A-Za-z0-9_-` (max 64); har path `safeJoin` se root ke andar rehta hai. File ID ab 128-bit random.
2. **Server auth**: `/api/session` se har device ko token milta hai (peerId se bandha). `health` aur `openapi` ke alawa har `/api` call par token chahiye. Vault chunk par body padhne se pehle auth.
3. **Cross-site/CSRF**: browser ka Origin Host se milna chahiye (HTTP aur WebSocket dono). Optional `VEGA_LAN_ONLY=1` se sirf local network.
4. **WebSocket**: token ke bina connect nahi. `peer:register` ka peerId session ke peerId se milna chahiye. Dusre address se wahi peerId lene ki koshish roki gayi.
5. **Pairing hijack**: `pairing:response` sirf wahi host de sakta hai jisne session banaya, aur sirf ek baar. Cancel bhi sirf host.
6. **Binary relay**: sender registered hona chahiye, target ID length bound. Hot path me sirf ek boolean check (speed par asar nahi).
7. **Pairing code**: ab 8 akshar ka 40-bit (pehle 32-bit), 10 lookup/min limit.
8. **Flutter receiver**: linear-time frame parser (purana har packet par poora buffer copy karta tha, ye speed ke liye bhi behtar hai), header/payload limits, taskId aur fileName sanitize, temp file ka naam random, declared size se zyada data par band, adhoori file delete, **verify fail hone par file Downloads me save nahi hoti**.
9. **Browser portal**: random access key (`?k=`), sab routes par zaroori, naam `textContent` se (XSS band), safe Content-Disposition, upload size cap, "verified" ka jhootha claim hata.

## Jo abhi baaki hai (Hissa B me)
- Flutter me session secret abhi bhi init frame me plaintext jata hai. Sahi fix X25519 handshake hai (Hissa B).
- `encrypted` flag par receiver ki policy, aur sender ka "verified" receiver ack ke baad.
- QR/typed code abhi bhi shared secret ki tarah hai; Sampreshan wala match code (SAS) B me aayega.
- LAN par koi bhi device session le sakta hai. Asli pehchaan ka bandobast B ke handshake se hoga.

## Verify kaise hua
- Server security modules: 9 tests pass (`npm test`).
- `server.ts`, `VegaContext.tsx`, `apiClient.ts`: syntax check pass. Poora `tsc` aur app run yahan nahi hua (dependencies install nahi ho sakti).
- **Dart/Flutter code yahan compile ya run nahi hua** (Dart installed nahi). Iske liye CI me `flutter test test/security_test.dart` jodha gaya hai. Pehle GitHub Actions chalakar dekhna zaroori hai.

## Aapko dikhne wala ek chhota badlav
Browser portal ka link ab `http://IP:PORT/?k=XXXXXXXXXX` hai (QR me bhi wahi). Layout ya design same hai, sirf link ke andar key judi hai.
