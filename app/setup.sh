#!/usr/bin/env bash
# Gera a pasta android/ e aplica o AndroidManifest do projeto. Rode dentro de app/.
set -euo pipefail
cd "$(dirname "$0")"
flutter create --org br.com.informaticasaojose --project-name jotalle --platforms android .
cp android-overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp -r android-overrides/res/. android/app/src/main/res/   # ícone do J da Jotalle
mkdir -p ~/.android && cp android-overrides/debug.keystore ~/.android/debug.keystore
flutter pub get
echo "Pronto. Teste: flutter run   |   APK: flutter build apk --release"
