# sing-box Integration для VPN2GO

## Архитектура

```
┌─────────────────────────────────────────────────┐
│                Flutter App                       │
│  ┌─────────────────────────────────────────┐    │
│  │     SingBoxService (Dart)               │    │
│  │     MethodChannel + EventChannel        │    │
│  └──────────────────┬──────────────────────┘    │
│                     │ Platform Channels          │
│  ┌──────────────────▼──────────────────────┐    │
│  │     SingBoxBridge (Java)                │    │
│  │     Flutter ↔ Android Native            │    │
│  └──────────────────┬──────────────────────┘    │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐    │
│  │     SingBoxVpnService (Java)            │    │
│  │     Android VpnService + libbox         │    │
│  └──────────────────┬──────────────────────┘    │
│                     │ JNI                        │
│  ┌──────────────────▼──────────────────────┐    │
│  │     libbox.aar (Go/sing-box)            │    │
│  │     VLESS + Reality + Hysteria          │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Быстрый старт

### 1. Скачать libbox.aar

```bash
cd singbox-mobile
chmod +x download-libbox.sh
./download-libbox.sh 1.11.0
```

Если не скачалось — вручную с https://github.com/SagerNet/sing-box/releases
Положить в `singbox-mobile/android/libs/libbox.aar`

### 2. Скопировать нативный код в Flutter проект

```bash
# Копируем Java файлы
cp -r singbox-mobile/android/src/main/java/com/vpn2go/singbox \
      flutter_app/android/app/src/main/java/com/vpn2go/

# Копируем libbox.aar
cp singbox-mobile/android/libs/libbox.aar \
   flutter_app/android/app/libs/
```

### 3. Обновить Android конфигурацию

В `flutter_app/android/app/build.gradle` добавить:

```gradle
android {
    packagingOptions {
        pickFirst '**/libgojni.so'
    }
    defaultConfig {
        minSdkVersion 24
    }
}

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.aar'])
}
```

В `AndroidManifest.xml` добавить сервис:

```xml
<service
    android:name="com.vpn2go.singbox.SingBoxVpnService"
    android:exported="false"
    android:foregroundServiceType="specialUse"
    android:permission="android.permission.BIND_VPN_SERVICE">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

### 4. Обновить MainActivity

```kotlin
class MainActivity : FlutterActivity() {
    private lateinit var singBoxBridge: SingBoxBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        singBoxBridge = SingBoxBridge(this)
        singBoxBridge.configure(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        singBoxBridge.onActivityResult(requestCode, resultCode)
    }
}
```

### 5. Запустить

```bash
cd flutter_app
flutter pub get
flutter run
```

## Flutter API

```dart
final vpn = SingBoxService();

// Подключиться
await vpn.connect(configJson, serverName: 'NODE-NL-01');

// Отключиться
await vpn.disconnect();

// Переключить
await vpn.toggle(configJson, serverName: 'NODE-NL-01');

// Слушать статус
vpn.statusStream.listen((status) {
  print('VPN Status: $status');
});

// Слушать статистику
vpn.statsStream.listen((stats) {
  print('Download: ${stats.downloadSpeedFormatted}');
  print('Upload: ${stats.uploadSpeedFormatted}');
});
```

## Поддерживаемые протоколы

sing-box поддерживает:
- ✅ VLESS + Reality (все ноды NL, SE, FR, FI)
- ✅ VLESS + xhttp (CDN ноды)
- ✅ Hysteria 2 (RU, FI ноды)
- ✅ Trojan + gRPC
- ✅ VMess + WebSocket

Конфиг автоматически генерируется Remnawave при запросе `/api/sub/{shortUuid}/singbox`.

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| `libbox.aar not found` | Скачать/собрать и положить в `libs/` |
| `VPN permission denied` | Приложение запросит разрешение при первом подключении |
| `minSdkVersion` | Установить `minSdkVersion 24` в build.gradle |
| `libgojni.so conflict` | Добавить `pickFirst '**/libgojni.so'` в packagingOptions |
