/// VPN2GO — API сервис для взаимодействия с бэкендом
library;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // TODO: заменить на реальный URL бэкенда
  static const String baseUrl = 'https://api.vpn2go.com/api/v1';
  
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  String? _appToken;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  )) {
    // Интерцептор для автоматической подстановки токена
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_appToken != null) {
          options.headers['Authorization'] = 'Bearer $_appToken';
        }
        print('🌐 [${options.method}] ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) {
        print('❌ API Error: ${error.response?.statusCode} ${error.message}');
        handler.next(error);
      },
    ));
  }

  // ==============================
  //  AUTH
  // ==============================

  /// Логин → получаем app_token
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    
    final data = response.data;
    _appToken = data['app_token'];
    await _storage.write(key: 'app_token', value: _appToken);
    await _storage.write(key: 'user_id', value: data['user_id']);
    await _storage.write(key: 'email', value: data['email']);
    
    return data;
  }

  /// Регистрация
  Future<Map<String, dynamic>> register(String email, String password, {String? username}) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      if (username != null) 'username': username,
    });
    return response.data;
  }

  /// Восстановить сессию из хранилища
  Future<bool> restoreSession() async {
    _appToken = await _storage.read(key: 'app_token');
    return _appToken != null;
  }

  /// Выход
  Future<void> logout() async {
    _appToken = null;
    await _storage.deleteAll();
  }

  // ==============================
  //  CLIENT
  // ==============================

  /// Профиль клиента
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/client/profile');
    return response.data;
  }

  /// Подписка
  Future<Map<String, dynamic>> getSubscription() async {
    final response = await _dio.get('/client/subscription');
    return response.data;
  }

  /// Баланс
  Future<Map<String, dynamic>> getBalance() async {
    final response = await _dio.get('/client/balance');
    return response.data;
  }

  /// Устройства
  Future<Map<String, dynamic>> getDevices() async {
    final response = await _dio.get('/client/devices');
    return response.data;
  }

  /// Зарегистрировать устройство (HWID)
  Future<Map<String, dynamic>> registerDevice({
    required String hwid,
    String platform = 'android',
    String osVersion = '',
    String deviceModel = '',
    String userAgent = '',
  }) async {
    final response = await _dio.post('/client/device/register', queryParameters: {
      'hwid': hwid,
      'platform': platform,
      'os_version': osVersion,
      'device_model': deviceModel,
      'user_agent': userAgent,
    });
    return response.data;
  }

  /// Проверить HWID устройства
  Future<Map<String, dynamic>> checkDevice(String hwid) async {
    final response = await _dio.get('/client/device/check/$hwid');
    return response.data;
  }

  // ==============================
  //  VPN
  // ==============================

  /// Получить VPN-конфиг для подключения
  /// client_type: singbox | json | v2ray-json
  Future<Map<String, dynamic>> getVpnConfig(String shortUuid, {String clientType = 'singbox'}) async {
    final response = await _dio.get('/vpn/config/$shortUuid', queryParameters: {
      'client_type': clientType,
    });
    return response.data;
  }

  /// Информация о VPN-подписке
  Future<Map<String, dynamic>> getVpnInfo(String shortUuid) async {
    final response = await _dio.get('/vpn/info/$shortUuid');
    return response.data;
  }

  /// Список VPN-нод
  Future<Map<String, dynamic>> getNodes() async {
    final response = await _dio.get('/vpn/nodes');
    return response.data;
  }

  /// Метрики нод
  Future<Map<String, dynamic>> getNodesMetrics() async {
    final response = await _dio.get('/vpn/nodes/metrics');
    return response.data;
  }

  // ==============================
  //  PUBLIC
  // ==============================

  /// Тарифы
  Future<Map<String, dynamic>> getTariffs() async {
    final response = await _dio.get('/public/tariffs');
    return response.data;
  }
}
