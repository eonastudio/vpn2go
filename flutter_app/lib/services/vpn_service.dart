/// VPN2GO — VPN подключение через sing-box
library;

import 'dart:async';
import 'package:flutter/services.dart';

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class VpnService {
  static const MethodChannel _channel = MethodChannel('com.vpn2go/vpn');
  
  VpnStatus _status = VpnStatus.disconnected;
  String? _currentServer;
  String? _errorMessage;
  
  final StreamController<VpnStatus> _statusController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _statsController = StreamController.broadcast();

  VpnStatus get status => _status;
  String? get currentServer => _currentServer;
  String? get errorMessage => _errorMessage;
  
  Stream<VpnStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  VpnService() {
    // Слушаем нативные события
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVpnStatusChanged':
        final String statusStr = call.arguments['status'];
        _status = _parseStatus(statusStr);
        _statusController.add(_status);
        break;
      case 'onVpnStatsUpdate':
        final Map<String, dynamic> stats = Map<String, dynamic>.from(call.arguments);
        _statsController.add(stats);
        break;
      case 'onVpnError':
        _errorMessage = call.arguments['message'];
        _status = VpnStatus.error;
        _statusController.add(_status);
        break;
    }
  }

  VpnStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'connected': return VpnStatus.connected;
      case 'connecting': return VpnStatus.connecting;
      case 'disconnected': return VpnStatus.disconnected;
      case 'disconnecting': return VpnStatus.disconnecting;
      default: return VpnStatus.error;
    }
  }

  /// Подключиться к VPN
  /// configJson — sing-box JSON конфиг из Remnawave
  Future<bool> connect(String configJson, {String? serverName}) async {
    try {
      _status = VpnStatus.connecting;
      _currentServer = serverName;
      _statusController.add(_status);
      
      final result = await _channel.invokeMethod('connect', {
        'config': configJson,
        'serverName': serverName ?? 'VPN2GO',
      });
      
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message;
      _status = VpnStatus.error;
      _statusController.add(_status);
      return false;
    }
  }

  /// Отключиться от VPN
  Future<bool> disconnect() async {
    try {
      _status = VpnStatus.disconnecting;
      _statusController.add(_status);
      
      final result = await _channel.invokeMethod('disconnect');
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
      final String status = await _channel.invokeMethod('getStatus');
      _status = _parseStatus(status);
      return _status;
    } on PlatformException {
      return VpnStatus.disconnected;
    }
  }

  void dispose() {
    _statusController.close();
    _statsController.close();
  }
}
