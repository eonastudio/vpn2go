#!/bin/bash
# VPN2GO — sing-box builder
# Собирает libbox.aar для Android из исходников sing-box
#
# Использование: ./build-singbox.sh [version]
# Пример: ./build-singbox.sh 1.11.0

set -e

SINGBOX_VERSION="${1:-1.11.0}"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$BUILD_DIR/android/libs"

echo "🔧 VPN2GO sing-box builder"
echo "   Version: $SINGBOX_VERSION"
echo "   Output:  $OUTPUT_DIR/libbox.aar"
echo ""

# Проверяем Go
if ! command -v go &> /dev/null; then
    echo "❌ Go не установлен. Установи: apt install golang-go"
    exit 1
fi

echo "✅ Go: $(go version)"

# Проверяем/устанавливаем gomobile
if ! command -v gomobile &> /dev/null; then
    echo "📦 Устанавливаем gomobile..."
    go install golang.org/x/mobile/cmd/gomobile@latest
    go install golang.org/x/mobile/cmd/gobind@latest
    export PATH=$PATH:$(go env GOPATH)/bin
    gomobile init
fi

echo "✅ gomobile: $(gomobile version 2>/dev/null || echo 'installed')"

# Клонируем sing-box
SINGBOX_DIR="/tmp/sing-box-$SINGBOX_VERSION"
if [ ! -d "$SINGBOX_DIR" ]; then
    echo "📥 Клонируем sing-box v$SINGBOX_VERSION..."
    git clone --depth 1 --branch "v$SINGBOX_VERSION" \
        https://github.com/sagernet/sing-box.git "$SINGBOX_DIR"
fi

cd "$SINGBOX_DIR"

# Собираем libbox.aar
echo "🔨 Собираем libbox.aar для Android..."
mkdir -p "$OUTPUT_DIR"

gomobile bind \
    -target=android \
    -androidapi=24 \
    -o "$OUTPUT_DIR/libbox.aar" \
    ./experimental/libbox

echo ""
echo "✅ Готово! libbox.aar создан:"
echo "   $OUTPUT_DIR/libbox.aar"
echo ""
echo "📋 Следующие шаги:"
echo "   1. Открой flutter_app/ в Android Studio"
echo "   2. Скопируй singbox-mobile/android/src/ в flutter_app/android/app/src/"
echo "   3. Добавь build.gradle additions"
echo "   4. flutter run"
