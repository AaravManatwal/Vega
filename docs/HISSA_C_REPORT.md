# Vega: Hissa C (Naam aur build taiyari) Report, 2026-11-18

Niyam: Android 13+ (minSdk 33 waisa hi), UI design me koi badlav nahi, modular code.

## Kya hua
1. **Naam sab jagah Vega.** Flutter ke andar `Sampreshan*` class aur provider (`VegaColors`, `VegaState`, `VegaController`, `VegaApp`, `vegaProvider`), README, Play Store checklist, firewall script, key.properties.example, Kotlin comment, `metadata.json`, CI. Downloads folder `Downloads/Vega` hi hai (README ab wahi kehta hai).
2. **Ek aur toota hua QR bug mila.** Scanner page `sampreshan://` dhoondhta tha jabki QR `vega://pair?...` banta tha, to QR pairing do jagah se fail hoti thi (radar screen ka dusra check). Ab sab `vega://`.
3. **Release signing.** Release build ab kabhi debug key se sign nahi hota. `android/key.properties` na ho to build saaf message ke saath fail hota hai. Phone testing ke liye debug APK use hoga.
4. **Cleartext traffic band** (`usesCleartextTraffic=false`). Vega ka transfer raw TCP socket par chalta hai, jis par ye setting asar nahi karti, isliye transfer par koi farq nahi padega.
5. **Zip ka kachra hata.** `dist/`, `dev-dist/`, `.vega-data/` hataye aur `.gitignore` me daale. Use na hone wala `@google/genai` package.json se hataya.
6. **CI sudhar.** `npm ci` aur npm cache lock file na hone se fail hote the, ab `npm install`. Naya job `android-debug-apk`: GitHub Actions apne aap debug APK banata hai aur `vega-debug-apk` naam se download ke liye rakhta hai. Phone se test karne ka yahi tareeka hai.

## Jo maine nahi chhua
- minSdk 33 (aapka niyam).
- `metadata.json` ka `SERVER_SIDE_GEMINI_API` capability: ye AI Studio ki setting hai, dependency hat chuki hai. Hatana ho to bata dijiye.
- `bun.lock` me genai ka entry rehta hai (offline regenerate nahi ho sakta), `bun install` ya `npm install` saaf kar dega.

## Verify
- `npm test`: 9 pass. Naam badalne ke baad Sampreshan ka koi nishaan nahi bacha (purani reports ko chhodkar).
- Dart code compile nahi hua (Dart yahan nahi hai). Sirf mechanical rename hai, par pehla `flutter analyze` GitHub Actions me hi chalega.
