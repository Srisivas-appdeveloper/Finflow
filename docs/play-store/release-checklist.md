# FinFlow release checklist (Google Play)

Application ID: `com.kalainova.finflow`. **Permanent once uploaded.**

## 1. Upload key (done)

The upload key was created on 25 October 2026:

- Keystore: `~/keys/finflow-upload.jks` (alias `upload`, RSA 4096,
  certificate `CN=Kalainova, O=Kalainova, C=IN`, valid ~27 years)
- Passwords: in `android/key.properties` (git-ignored) and a copy at
  `~/keys/finflow-key.properties`

**Back up the whole `~/keys` folder now** to two places you control (for
example an encrypted USB drive and a password manager's file vault). Never
commit it, email it or put it in the project. With Play App Signing, Google
holds the real app-signing key; if this upload key is ever lost, the account
owner can request an upload-key reset in Play Console > Test and release >
App integrity.

Without `android/key.properties` the release build falls back to the debug
key, which Play Console rejects. Check the signer before uploading:

```sh
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | grep -m1 X.509
# expect: CN=Kalainova, O=Kalainova, C=IN
```

## 2. Bump the version

In `pubspec.yaml`: `version: 1.0.0+1`. Increase the number after `+` for
every upload (it is Android's `versionCode`).

## 3. Verify

```sh
flutter analyze
flutter test
flutter test integration_test/app_flow_test.dart -d <emulator-id>
```

Then install a release build on an emulator or test device and walk
through: onboarding, add a transaction, add a card, add a bill, record a
payment, turn on reminders (permission prompt), export CSV, delete all data.

```sh
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

## 4. Build the upload bundle

```sh
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols
```

Upload `build/app/outputs/bundle/release/app-release.aab`. Keep
`build/symbols` for this version: it is needed to read crash stack traces
from obfuscated builds.

## 5. Play Console (organisation account)

1. Developer account: organisation type, verified with the company's
   D-U-N-S number, website and contact details. Organisation accounts are
   not subject to the 12-tester / 14-day closed-test rule for personal
   accounts.
2. Create app: name "FinFlow: Expense Tracker", default language English
   (India), App, Free. Package `com.kalainova.finflow` is fixed after the
   first upload.
3. Store listing: text from `listing.md`; icon and feature graphic from
   `graphics/`; the 8 images in `screenshots/`.
4. App content: answers in `data-safety.md`, including the **Financial
   features** declaration (personal finance tracking only) and the privacy
   policy URL.
5. Test and release > Internal testing: create a release, upload
   `app-release.aab` (Play App Signing is on by default; accept it), add
   your team's Google accounts as testers, install from the opt-in link and
   run the walkthrough in step 3 on real phones.
6. Optional but recommended: a short closed test with a few outside users.
7. Production: promote the tested release, choose countries (India, or
   wider), roll out. First review usually takes a few days.
8. Keep `build/symbols` for each uploaded version and upload the
   `native-debug-symbols` / mapping when Console asks, so crash reports are
   readable.

## Still to do before production

- Support email: srisivas362@gmail.com (in the policy and `listing.md`).
- Privacy policy is live at
  https://srisivas-appdeveloper.github.io/finflow-privacy/ (enter it in the
  listing and in App content > Privacy policy).
- iOS is not configured or tested.
