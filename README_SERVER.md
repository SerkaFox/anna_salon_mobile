# BRIMOON Studio - Flutter app (anna_salon_mobile)

Source copy of the mobile app (from the Windows PC C:\projectsnna_mobile, 2026-09-25).
Source of truth is also GitHub: https://github.com/SerkaFox/anna_salon_mobile

## Build (needs Flutter SDK + Android SDK + JDK 17)
    export BRIMOON_SIGNING_KEY_PATH=/home/seradmin/anna_mobile/.signing/brimoon-signing-key.keystore
    # passwords/alias: defaults in android/app/build.gradle.kts (BRIMOON_SIGNING_* env vars override)
    flutter pub get
    flutter build apk --release
Release steps: bump version in pubspec.yaml + lib/app_version.dart, update
mobile_api/app_update_manifest.py in the backend (sha256, size), upload APK to /home/seradmin/anna/media/.

## Signing key
The keystore is NOT in this copy. Original: C:\projects\.signingrimoon-signing-key.keystore on the Windows PC.
Losing it means users must uninstall/reinstall the app. Keep a copy somewhere safe (password manager / USB).
