#!/bin/bash
# VPN2GO — Build APK
# Использование: ./build-apk.sh
set -e

echo "🔧 VPN2GO APK Builder"
echo ""

# Проверяем Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter не установлен."
    echo ""
    echo "Установка Flutter:"
    echo "  1. Скачай: https://docs.flutter.dev/get-started/install/linux"
    echo "  2. Или: snap install flutter --classic"
    echo "  3. Или: git clone https://github.com/flutter/flutter.git -b stable"
    exit 1
fi

echo "✅ Flutter: $(flutter --version | head -1)"

# Проверяем Java
if ! command -v java &> /dev/null; then
    echo "❌ Java не установлена. Установи: apt install openjdk-17-jdk"
    exit 1
fi
echo "✅ Java: $(java -version 2>&1 | head -1)"

cd "$(dirname "$0")/flutter_app"

# Создаём local.properties
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
cat > android/local.properties << EOF
sdk.dir=$ANDROID_HOME
flutter.sdk=$(dirname $(which flutter))
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
EOF

echo ""
echo "📦 Installing dependencies..."
flutter pub get

echo ""
echo "🔨 Building APK (release)..."
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo ""
    echo "✅ APK собран!"
    echo "   Путь: $(pwd)/$APK_PATH"
    echo "   Размер: $SIZE"
    echo ""
    echo "📱 Установка на устройство:"
    echo "   adb install $APK_PATH"
else
    echo "❌ Ошибка сборки"
    exit 1
fi
