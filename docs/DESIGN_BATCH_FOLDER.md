# Design: many files and folders in ONE approval (not built yet)

Problem today: picking 10 files = 10 separate Accept screens (one handshake and one approval per file).

## Rule we keep
Approval must never be skippable by someone who merely sniffs the network. So NO "batchId auto-approves the next files" shortcut.

## Plan: one archive per send
1. Sender packs the selected files / folder into one uncompressed tar-like archive (Dart isolate, streamed, no big memory use). Photos/videos are already compressed, so no compression = no speed loss.
2. It travels as ONE normal v2 transfer named `<name>.vegabundle`. The name is already bound into the handshake transcript, so it cannot be swapped.
3. The receiver sees ONE Accept screen: "12 files, 340 MB" (count and total sent in `init`, shown from the transcript-bound size).
4. Extraction happens only AFTER the authenticated `done` (verified). Strict rules: reject absolute paths, `..`, symlinks, duplicate names, more than N entries or declared size > total; every file saved through MediaStore under Downloads/Vega/<bundle>/.
5. Resume works unchanged (it is just one file).

## Needs
- Kotlin: `saveToDownloads` must accept a relative sub-folder (MediaStore RELATIVE_PATH). Folder picking on Android 13+ needs SAF (ACTION_OPEN_DOCUMENT_TREE) with copy-to-cache; not possible to test here.
- Dart: tar writer + reader (+ unit tests with traversal cases), ChunkSource in the sender isolate, UI: "12 files" in file card.
- Build this only after the current three Hissas compile on CI, so errors are not mixed.

## Status (2026-11-22)
Step 1 is DONE as an isolated library, not yet wired into the engine or UI, so it cannot break existing transfers:
- `lib/core/bundle/vega_bundle.dart`: `pack` (streamed), `packedSize`, `extract` (strict path checks, size limit, duplicates, truncation), `checkPath`.
- `test/vega_bundle_test.dart`: round trip with 7-byte chunks, traversal / backslash / colon / empty-segment names, wrong magic, truncation, oversize.
- Next after CI is green: engine hook (send the bundle as one file), Accept screen "N files", Kotlin sub-folder save, picker UI.

## Status update 2 (2026-11-22): multi-file send is wired
- Sender (`app_state.sendFilesToPeer`): 2 or more picked files are packed by `BundleIo.packForSend` into one cache file `"N files.vegabundle"` and sent as ONE transfer, so the receiver taps Accept once. Old bundles are deleted before the next pack. The sender isolate and wire protocol are untouched.
- Receiver (engine, verified branch): a name ending in `.vegabundle` is opened only after the authenticated `done`, extracted to a temp dir with all `VegaBundle` checks, then each file goes to Downloads one by one (names flat, sanitized). Failure → task shown as failed with the reason, temp data removed.
- Trade-off: packing copies the selected files once on the sender's disk before the network transfer (needs free space equal to the total; adds a few seconds per GB). Wire speed is unchanged.
- Not yet: real folders (needs SAF picker + MediaStore sub-folder), "12 files" count on the Accept screen (currently the name "12 files.vegabundle" is shown).
- Single files are sent exactly as before.

## Review fixes (2026-11-22)
Static review found and fixed: bundles are now packed into their own sub-folder and only bundles older than 2 hours are removed (a running or resuming send is never deleted); file names are capped by UTF-8 bytes (Hindi names), not characters; core library desugaring enabled in `android/app/build.gradle.kts` for flutter_local_notifications; notification only when the app is really in the background; device name saves while typing.
Known, left as is: a bundle with both `a` and `a/b` fails with a file-system error (still safe, shown as failed); an unpack failure shows a verified file as failed.
