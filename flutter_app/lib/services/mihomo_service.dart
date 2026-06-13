/// VPN2GO — Mihomo (Clash Meta) VPN Service
///
/// mihomo использует YAML-конфиг и работает как локальный прокси.
/// VPN-туннель создаётся через Android VpnService, который направляет
/// трафик на локальный mixed-port прокси mihomo.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Статус mihomo VPN
enum MihomoStatus {
  disconnected,
  starting,
  connected,
  stopping,
  error,
}

/// Статистика mihomo
class MihomoStats {
  final int uploadTotal;
  final int downloadTotal;
  final int uploadSpeed;
  final int downloadSpeed;

  MihomoStats({
    this.uploadTotal = 0,
    this.downloadTotal = 0,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
  });
}

/// Сервис управления mihomo VPN
class MihomoService {
  static const MethodChannel _channel = MethodChannel('com.vpn2go/mihomo');

  MihomoStatus _status = MihomoStatus.disconnected;
  String? _errorMessage;

  final StreamController<MihomoStatus> _statusController =
      StreamController<MihomoStatus>.broadcast();
  final StreamController<MihomoStats> _statsController =
      StreamController<MihomoStats>.broadcast();

  MihomoStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Stream<MihomoStatus> get statusStream => _statusController.stream;
  Stream<MihomoStats> get statsStream => _statsController.stream;
  bool get isConnected => _status == MihomoStatus.connected;

  MihomoService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMihomoStatusChanged':
        final String statusStr = call.arguments['status'];
        _status = _parseStatus(statusStr);
        _statusController.add(_status);
        break;
      case 'onMihomoStatsUpdate':
        _statsController.add(MihomoStats(
          uploadSpeed: call.arguments['uploadSpeed'] ?? 0,
          downloadSpeed: call.arguments['downloadSpeed'] ?? 0,
          uploadTotal: call.arguments['uploadTotal'] ?? 0,
          downloadTotal: call.arguments['downloadTotal'] ?? 0,
        ));
        break;
      case 'onMihomoError':
        _errorMessage = call.arguments['message'];
        _status = MihomoStatus.error;
        _statusController.add(_status);
        break;
    }
  }

  MihomoStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
      case 'running':
        return MihomoStatus.connected;
      case 'starting':
        return MihomoStatus.starting;
      case 'disconnected':
      case 'stopped':
        return MihomoStatus.disconnected;
      case 'stopping':
        return MihomoStatus.stopping;
      default:
        return MihomoStatus.error;
    }
  }

  /// Запустить mihomo с YAML конфигом
  Future<bool> connect(String yamlConfig, {String? serverName}) async {
    try {
      _status = MihomoStatus.starting;
      _statusController.add(_status);

      final result = await _channel.invokeMethod('startMihomo', {
        'config': yamlConfig,
        'serverName': serverName ?? 'VPN2GO',
      });

      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message;
      _status = MihomoStatus.error;
      _statusController.add(_status);
      return false;
    }
  }

  /// Остановить mihomo
  Future<bool> disconnect() async {
    try {
      _status = MihomoStatus.stopping;
      _statusController.add(_status);

      final result = await _channel.invokeMethod('stopMihomo');
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message;
      return false;
    }
  }

  /// Получить текущий статус
  Future<MihomoStatus> getStatus() async {
    try {
      final String status = await _channel.invokeMethod('getMihomoStatus');
      _status = _parseStatus(status);
      return _status;
    } on PlatformException {
      return MihomoStatus.disconnected;
    }
  }

  /// Переключить подключение
  Future<bool> toggle(String yamlConfig, {String? serverName}) async {
    if (isConnected) {
      await disconnect();
      return false;
    } else {
      return await connect(yamlConfig, serverName: serverName);
    }
  }

  /// Получить доступные прокси-группы
  Future<List<dynamic>> getProxies() async {
    try {
      final result = await _channel.invokeMethod('getProxies');
      return result ?? [];
    } on PlatformException {
      return [];
    }
  }

  /// Переключить прокси в группе
  Future<bool> switchProxy(String group, String proxy) async {
    try {
      final result = await _channel.invokeMethod('switchProxy', {
        'group': group,
        'proxy': proxy,
      });
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  void dispose() {
    _statusController.close();
    _statsController.close();
  }
}
