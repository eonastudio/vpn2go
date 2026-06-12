/// VPN2GO — Главный экран (подключение к VPN)
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/singbox_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final SingBoxService _vpn = SingBoxService();
  
  VpnStatus _vpnStatus = VpnStatus.disconnected;
  Map<String, dynamic>? _subscription;
  List<dynamic> _nodes = [];
  String? _selectedNode;
  String? _selectedNodeName;
  
  // Статистика
  String _downloadSpeed = '0 B/s';
  String _uploadSpeed = '0 B/s';
  String _totalDownload = '0 B';
  String _totalUpload = '0 B';
  
  late AnimationController _pulseController;
  StreamSubscription? _statusSub;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _statusSub = _vpn.statusStream.listen((status) {
      if (mounted) setState(() => _vpnStatus = status);
    });
    
    _statsSub = _vpn.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _downloadSpeed = _formatBytes(stats.downloadSpeed) + '/s';
          _uploadSpeed = _formatBytes(stats.uploadSpeed) + '/s';
          _totalDownload = _formatBytes(stats.totalDownload);
          _totalUpload = _formatBytes(stats.totalUpload);
        });
      }
    });
    
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final sub = await _api.getSubscription();
      final nodes = await _api.getNodes();
      if (mounted) {
        setState(() {
          _subscription = sub;
          _nodes = nodes['response'] ?? nodes['data'] ?? [];
          if (_nodes.isNotEmpty) {
            _selectedNode = _nodes[0]['uuid'];
            _selectedNodeName = _nodes[0]['name'] ?? 'Server 1';
          }
        });
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _toggleVpn() async {
    if (_vpnStatus == VpnStatus.connected || _vpnStatus == VpnStatus.connecting) {
      await _vpn.disconnect();
    } else {
      // Получаем конфиг из Remnawave через наш бэкенд
      final shortUuid = _subscription?['shortUuid'] ?? _subscription?['short_uuid'];
      if (shortUuid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Подписка не найдена')),
        );
        return;
      }
      
      try {
        final configData = await _api.getVpnConfig(shortUuid);
        final configJson = configData['config'] as String;
        await _vpn.connect(configJson, serverName: _selectedNodeName);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Color get _statusColor {
    switch (_vpnStatus) {
      case VpnStatus.connected: return AppTheme.success;
      case VpnStatus.connecting: return AppTheme.warning;
      case VpnStatus.error: return AppTheme.danger;
      default: return AppTheme.textMuted;
    }
  }

  String get _statusText {
    switch (_vpnStatus) {
      case VpnStatus.connected: return 'Подключено';
      case VpnStatus.connecting: return 'Подключение...';
      case VpnStatus.disconnecting: return 'Отключение...';
      case VpnStatus.error: return 'Ошибка';
      default: return 'Отключено';
    }
  }

  IconData get _statusIcon {
    switch (_vpnStatus) {
      case VpnStatus.connected: return Icons.shield_rounded;
      case VpnStatus.connecting: return Icons.sync;
      case VpnStatus.error: return Icons.error_outline;
      default: return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Шапка
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VPN2GO',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subscription != null ? 'Подписка активна' : 'Загрузка...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/profile'),
                    icon: const Icon(Icons.person_outline, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Большая кнопка подключения
              _buildConnectButton(),
              const SizedBox(height: 16),
              
              // Статус
              Text(
                _statusText,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_vpnStatus == VpnStatus.connected && _selectedNodeName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _selectedNodeName!,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 40),
              
              // Статистика (показываем только когда подключены)
              if (_vpnStatus == VpnStatus.connected) ...[
                _buildStatsCard(),
                const SizedBox(height: 24),
              ],
              
              // Выбор сервера
              _buildServerSelector(),
              const SizedBox(height: 24),
              
              // Информация о подписке
              if (_subscription != null) _buildSubscriptionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectButton() {
    final isConnected = _vpnStatus == VpnStatus.connected;
    final isConnecting = _vpnStatus == VpnStatus.connecting;
    
    return GestureDetector(
      onTap: isConnecting ? null : _toggleVpn,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = isConnecting ? _pulseController.value * 0.15 : 0.0;
          return Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isConnected ? AppTheme.success : AppTheme.primary).withOpacity(0.2 + pulse),
                  Colors.transparent,
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isConnected
                      ? [AppTheme.success, const Color(0xFF00D2AA)]
                      : [AppTheme.primary, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isConnected ? AppTheme.success : AppTheme.primary).withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                _statusIcon,
                size: 64,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _statItem(Icons.arrow_downward, 'Загрузка', _downloadSpeed, AppTheme.accent)),
              Container(width: 1, height: 40, color: AppTheme.bgCardLight),
              Expanded(child: _statItem(Icons.arrow_upward, 'Отдача', _uploadSpeed, AppTheme.primaryLight)),
            ],
          ),
          const Divider(color: AppTheme.bgCardLight, height: 24),
          Row(
            children: [
              Expanded(child: _statItem(Icons.download_done, 'Всего ↓', _totalDownload, AppTheme.textSecondary)),
              Container(width: 1, height: 40, color: AppTheme.bgCardLight),
              Expanded(child: _statItem(Icons.cloud_upload, 'Всего ↑', _totalUpload, AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildServerSelector() {
    return GestureDetector(
      onTap: () => _showServerPicker(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.public, color: AppTheme.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Сервер', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  Text(
                    _selectedNodeName ?? 'Выбери сервер',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final expireAt = _subscription?['expireAt'] ?? _subscription?['expire_at'] ?? '';
    final status = _subscription?['status'] ?? 'unknown';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_membership,
            color: status == 'active' ? AppTheme.success : AppTheme.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Подписка: $status',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
                if (expireAt.isNotEmpty)
                  Text(
                    'Действует до: $expireAt',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showServerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Выбери сервер',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ..._nodes.map((node) => ListTile(
                leading: const Icon(Icons.public, color: AppTheme.accent),
                title: Text(node['name'] ?? 'Unknown'),
                subtitle: Text(node['address'] ?? ''),
                trailing: _selectedNode == node['uuid']
                    ? const Icon(Icons.check_circle, color: AppTheme.success)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedNode = node['uuid'];
                    _selectedNodeName = node['name'] ?? 'Server';
                  });
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusSub?.cancel();
    _statsSub?.cancel();
    _vpn.dispose();
    super.dispose();
  }
}
