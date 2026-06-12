/// VPN2GO — Генерация и управление HWID (Hardware ID)
///
/// Каждое устройство получает уникальный HWID при первом запуске.
/// HWID используется для контроля лимита устройств в подписке.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Информация об устройстве
class DeviceInfo {
  final String hwid;
  final String platform;
  final String osVersion;
  final String deviceModel;
  final String userAgent;

  DeviceInfo({
    required this.hwid,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.userAgent,
  });

  Map<String, dynamic> toJson() => {
    'hwid': hwid,
    'platform': platform,
    'osVersion': osVersion,
    'deviceModel': deviceModel,
    'userAgent': userAgent,
  };
}

/// Сервис генерации и управления HWID
class HwidService {
  static const MethodChannel _channel = MethodChannel('com.vpn2go/device');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _storageKeyHwid = 'device_hwid';
  static const String _storageKeyModel = 'device_model';
  static const String _storageKeyPlatform = 'device_platform';
  static const String _storageKeyOsVersion = 'device_os_version';

  static DeviceInfo? _cachedDevice;

  /// Получить HWID устройства (генерируется один раз, потом сохраняется)
  static Future<String> getHwid() async {
    // Проверяем кэш
    final cached = await _storage.read(key: _storageKeyHwid);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // Генерируем новый HWID через нативный код
    String hwid;
    try {
      hwid = await _channel.invokeMethod('getHwid');
    } catch (e) {
      // Fallback: генерируем на стороне Dart
      hwid = await _generateFallbackHwid();
    }

    // Сохраняем
    await _storage.write(key: _storageKeyHwid, value: hwid);
    return hwid;
  }

  /// Получить полную информацию об устройстве
  static Future<DeviceInfo> getDeviceInfo() async {
    if (_cachedDevice != null) return _cachedDevice!;

    final hwid = await getHwid();

    // Получаем инфо о платформе
    String platform;
    String osVersion;
    String deviceModel;

    try {
      final info = await _channel.invokeMethod('getDeviceInfo');
      platform = info['platform'] ?? Platform.operatingSystem;
      osVersion = info['osVersion'] ?? Platform.operatingSystemVersion;
      deviceModel = info['deviceModel'] ?? 'Unknown';
    } catch (e) {
      platform = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
      deviceModel = 'Unknown';
    }

    // Кэшируем
    await _storage.write(key: _storageKeyPlatform, value: platform);
    await _storage.write(key: _storageKeyOsVersion, value: osVersion);
    await _storage.write(key: _storageKeyModel, value: deviceModel);

    final userAgent = 'VPN2GO/1.0 ($platform $osVersion; $deviceModel)';

    _cachedDevice = DeviceInfo(
      hwid: hwid,
      platform: platform,
      osVersion: osVersion,
      deviceModel: deviceModel,
      userAgent: userAgent,
    );

    return _cachedDevice!;
  }

  /// Сбросить HWID (для привязки к другому аккаунту)
  static Future<void> resetHwid() async {
    await _storage.delete(key: _storageKeyHwid);
    _cachedDevice = null;
  }

  /// Fallback генерация HWID (если нативный код недоступен)
  static Future<String> _generateFallbackHwid() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 31) % 999999999;
    final platform = Platform.operatingSystem;
    final raw = 'vpn2go-$platform-$timestamp-$random';
    
    // Простой хеш
    final bytes = utf8.encode(raw);
    var hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash) + byte;
      hash = hash & 0x7FFFFFFF;
    }
    
    return hash.toRadixString(16).padLeft(12, '0');
  }
}
