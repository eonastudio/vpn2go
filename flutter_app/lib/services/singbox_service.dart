/// VPN2GO — sing-box VPN Service (Flutter ↔ Native)
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Статус VPN-подключения
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
  permissionRequired,
}

/// Статистика VPN
class VpnStats {
  final int uploadSpeed;
  final int downloadSpeed;
  final int totalUpload;
  final int totalDownload;

  VpnStats({
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.totalUpload = 0,
    this.totalDownload = 0,
  });

  String get uploadSpeedFormatted => _formatBytes(uploadSpeed);
  String get downloadSpeedFormatted => _formatBytes(downloadSpeed);
  String get totalUploadFormatted => _formatBytes(totalUpload);
  String get totalDownloadFormatted => _formatBytes(totalDownload);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Сервис управления VPN через sing-box
class SingBoxService {
  static const MethodChannel _method = MethodChannel('com.vpn2go/singbox');
  static const EventChannel _event = EventChannel('com.vpn2go/singbox_events');

  VpnStatus _status = VpnStatus.disconnected;
  String? _currentServer;
  String? _errorMessage;

  final StreamController<VpnStatus> _statusController =
      StreamController<VpnStatus>.broadcast();
  final StreamController<VpnStats> _statsController =
      StreamController<VpnStats>.broadcast();

  StreamSubscription? _eventSubscription;

  // Getters
  VpnStatus get status => _status;
  String? get currentServer => _currentServer;
  String? get errorMessage => _errorMessage;
  Stream<VpnStatus> get statusStream => _statusController.stream;
  Stream<VpnStats> get statsStream => _statsController.stream;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isConnecting => _status == VpnStatus.connecting;

  SingBoxService() {
    _initEventChannel();
  }

  void _initEventChannel() {
    _eventSubscription = _event.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          // Статус
          _updateStatus(_parseStatus(event));
        } else if (event is Map) {
          // Статистика
          _statsController.add(VpnStats(
            uploadSpeed: event['uploadSpeed'] ?? 0,
            downloadSpeed: event['downloadSpeed'] ?? 0,
            totalUpload: event['totalUpload'] ?? 0,
            totalDownload: event['totalDownload'] ?? 0,
          ));
        }
      },
      onError: (error) {
        _errorMessage = error.toString();
        _updateStatus(VpnStatus.error);
      },
    );
  }

  VpnStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return VpnStatus.connected;
      case 'connecting':
        return VpnStatus.connecting;
      case 'disconnected':
        return VpnStatus.disconnected;
      case 'disconnecting':
        return VpnStatus.disconnecting;
      case 'error':
        return VpnStatus.error;
      case 'permission_required':
        return VpnStatus.permissionRequired;
      default:
        return VpnStatus.disconnected;
    }
  }

  void _updateStatus(VpnStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  /// Подключиться к VPN
  ///
  /// [configJson] — sing-box JSON конфиг из Remnawave
  /// [serverName] — имя сервера для отображения
  Future<bool> connect(String configJson, {String? serverName}) async {
    try {
      _currentServer = serverName;
      _updateStatus(VpnStatus.connecting);

      final result = await _method.invokeMethod('connect', {
        'config': configJson,
        'sessionName': serverName ?? 'VPN2GO',
      });

      if (result == 'permission_required') {
        _updateStatus(VpnStatus.permissionRequired);
        return false;
      }

      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message;
      _updateStatus(VpnStatus.error);
      return false;
    }
  }

  /// Отключиться от VPN
  Future<bool> disconnect() async {
    try {
      _updateStatus(VpnStatus.disconnecting);

      final result = await _method.invokeMethod('disconnect');
      _currentServer = null;
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message;
      return false;
    }
  }

  /// Получить текущий статус
  Future<VpnStatus> getStatus() async {
    try {
      final String status = await _method.invokeMethod('getStatus');
      _status = _parseStatus(status);
      return _status;
    } on PlatformException {
      return VpnStatus.disconnected;
    }
  }

  /// Переключить подключение
  Future<bool> toggle(String configJson, {String? serverName}) async {
    if (isConnected || isConnecting) {
      await disconnect();
      return false;
    } else {
      return await connect(configJson, serverName: serverName);
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _statusController.close();
    _statsController.close();
  }
}
