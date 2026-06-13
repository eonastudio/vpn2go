/// VPN2GO — Выбор VPN протокола
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Доступные VPN протоколы
enum VpnProtocol {
  singbox,
  mihomo,
}

/// Информация о протоколе
class ProtocolInfo {
  final VpnProtocol protocol;
  final String name;
  final String description;
  final IconData icon;
  final String clientType; // для API запроса

  const ProtocolInfo({
    required this.protocol,
    required this.name,
    required this.description,
    required this.icon,
    required this.clientType,
  });
}

/// Список доступных протоколов
const List<ProtocolInfo> availableProtocols = [
  ProtocolInfo(
    protocol: VpnProtocol.singbox,
    name: 'sing-box',
    description: 'VLESS + Reality, Hysteria, xhttp',
    icon: Icons.shield_rounded,
    clientType: 'singbox',
  ),
  ProtocolInfo(
    protocol: VpnProtocol.mihomo,
    name: 'mihomo',
    description: 'Clash Meta, YAML конфиг, прокси-группы',
    icon: Icons.hub_rounded,
    clientType: 'mihomo',
  ),
];

/// Виджет выбора протокола
class ProtocolSelector extends StatelessWidget {
  final VpnProtocol selected;
  final ValueChanged<VpnProtocol> onChanged;

  const ProtocolSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Протокол',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...availableProtocols.map((info) => _buildProtocolTile(info)),
        ],
      ),
    );
  }

  Widget _buildProtocolTile(ProtocolInfo info) {
    final isSelected = selected == info.protocol;
    return GestureDetector(
      onTap: () => onChanged(info.protocol),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.15)
              : AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              info.icon,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.description,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
