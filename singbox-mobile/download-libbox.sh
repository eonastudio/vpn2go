#!/bin/bash
# VPN2GO — скачать готовый libbox.aar из GitHub releases
#
# Использование: ./download-libbox.sh [version]

set -e

VERSION="${1:-1.11.0}"
OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)/android/libs"
OUTPUT_FILE="$OUTPUT_DIR/libbox.aar"

echo "📥 Скачиваем libbox.aar sing-box v$VERSION..."

mkdir -p "$OUTPUT_DIR"

# Формируем URL релиза
RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}"

# Пробуем скачать (формат имени файла может отличаться между версиями)
for name in "libbox.aar" "libbox-${VERSION}.aar" "android-libbox.aar"; do
    echo "   Пробуем: $RELEASE_URL/$name"
    if curl -sL -o "$OUTPUT_FILE" "$RELEASE_URL/$name" 2>/dev/null; then
        # Проверяем что это не HTML (страница 404)
        if file "$OUTPUT_FILE" | grep -q "Zip\|Java"; then
            echo "✅ Скачано: $OUTPUT_FILE ($(du -h "$OUTPUT_FILE" | cut -f1))"
            exit 0
        fi
    fi
done

echo ""
echo "❌ Не удалось скачать libbox.aar автоматически."
echo ""
echo "📋 Скачай вручную:"
echo "   1. Открой: https://github.com/SagerNet/sing-box/releases/tag/v$VERSION"
echo "   2. Найди libbox.aar в Assets"
echo "   3. Положи в: $OUTPUT_FILE"
echo ""
echo "Или собери из исходников:"
echo "   ./build-singbox.sh $VERSION"

rm -f "$OUTPUT_FILE"
exit 1
