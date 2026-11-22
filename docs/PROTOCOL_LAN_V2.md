# Vega LAN protocol v2 (phone to phone over TCP)

Goal: a passive sniffer learns nothing, a man-in-the-middle cannot alter the transfer after scanning the QR code, and a file is marked verified only after the receiver proves it received exactly the bytes that were sent. AES-256-GCM is kept on purpose: it is hardware accelerated on Android 13+, so there is no speed loss.

## Frames
`[u32 BE headerLen][header JSON][payload]`, header contains `payloadLen`. Limits: header 64 KiB, payload 16 MiB, file size 1 TiB.

## Handshake
1. Sender: ephemeral X25519 key E. Sends `init` (`v:2`, `mode: qr|open`, `id`, `fileName`, `totalBytes`, `chunkSizeBytes`, `encrypted`, `epk`, and `rpk` in QR mode).
2. Receiver: checks limits, then makes ephemeral key F. In QR mode it checks `rpk` equals its current offer (not expired). Replies `accept {fpk, confirm}` or `reject {reason}`.
3. Both compute: `ikm = DH(E,F)` (open) or `DH(E,F) || DH(E,R)` (QR, R = receiver key from the QR code); `salt = psk` (QR, 16 random bytes from the QR code) or 32 zero bytes.
4. `transcript = SHA256(label | 0 | qr | encrypted | E | F | [R] | u64 totalBytes | u32 chunkSize | u16 len fileName | fileName | u16 len id | id)`. Because the transfer parameters are inside the transcript, changing any of them (for example turning encryption off) breaks the confirm check.
5. `key`, `confirm`, `sas` = HKDF-SHA256(ikm, salt, info = "VEGA-LAN-2 <name>" || transcript). `sas` is 6 digits (uint32 BE of the first 4 bytes, mod 10^6), identical on both phones.
6. `confirm` in `accept` = HMAC-SHA256(confirmKey, "accept" || transcript). The sender aborts if it does not match.

7. Approval (new transfers only): after `accept` the receiver shows its user the sender name, file and match code and waits for Accept or Reject. Accept sends `go {}` and the receiver then starts storing data. Reject (or no answer in 60 s, or no UI listening) sends `reject {reason}`. The sender shows the same code, sends no chunk until `go` arrives, and gives up after 90 s. A resumed transfer (`init.resume:true`) skips this step, because the user already approved it and the sender proves it with the resume proof. This step happens once per file, before any chunk, so it does not change throughput.

QR mode authenticates the receiver (the QR was scanned from the receiver's screen). Open mode (picked from the nearby list) is encrypted but not authenticated, so the user compares the 6-digit match code on both screens before tapping Accept.

## Data
Each chunk: AES-256-GCM, random 12-byte nonce, AAD = `"VEGA-LAN-2 chunk|index|offset|plainSize"`. Receiver requires `index` and `offset` to be exactly the next expected values, so chunks cannot be reordered, repeated or dropped.

## Completion
Sender sends `complete {sha256Hex}`. Receiver hashes the file and replies `done {ok, sha256Hex, bytes, confirm}` where `confirm = HMAC(confirmKey, "done:<ok>:<sha>:<bytes>")`. The sender shows "verified" only if that MAC is valid and the values match. The receiver saves to Downloads only when `ok` is true.

## Resume (connection dropped mid-transfer)
- Receiver: on a network drop it keeps the verified part (a whole number of chunks) for 10 minutes, at most 4 partial files, then deletes it. Cancel, malformed data and failed verification delete it at once.
- Sender: retries up to 5 times (1, 2, 4, 8, 16 seconds) only for network-level drops (never for refusals or failed verification).
- Reconnect: a fresh handshake (new ephemeral keys), `init` carries `resume: true`, then the sender sends `resume {proof}` where `proof = HMAC(resumeKey_old, "resume" || newTranscript)`. `resumeKey` = HKDF output with label `resume` from the previous session. Binding to the new transcript means a captured proof cannot be replayed.
- Receiver checks the parameters match the parked transfer (file name, size, chunk size, encryption flag) and the proof, then answers `resumed {offset, index, confirm}`; `confirm = HMAC(confirmKey, "resumed:<offset>:<index>")`. The sender continues from that offset (never beyond what it already sent), re-hashes the already-sent bytes from the source file, and the final SHA-256 still covers the whole file.
- No parked transfer found: receiver starts fresh and answers `offset: 0`. Both sides rotate to the new `resumeKey` after each successful (re)connect.
- Executable model: `tools/lan_v2_resume_sim.mjs`.

## Test vectors
`tools/lan_v2_vectors.mjs` (node:crypto only; X25519 checked against RFC 7748 section 6.1) writes `flutter_app/test/vectors/lan_v2.json`. `flutter_app/test/lan_v2_test.dart` must reproduce every value.
