import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'active': return AppTheme.success;
      case 'completed': return AppTheme.info;
      case 'planned': return AppTheme.warning;
      case 'paused': return AppTheme.textSecondary;
      default: return AppTheme.textMuted;
    }
  }

  String get _label {
    switch (status) {
      case 'active': return '진행중';
      case 'completed': return '완료';
      case 'planned': return '예정';
      case 'paused': return '일시정지';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(_label, style: TextStyle(
            color: _color, fontSize: 11, fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class MintGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const MintGradientCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.mintPrimary.withValues(alpha: 0.15),
            AppTheme.bgCard,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.mintPrimary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
          )),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!, style: const TextStyle(
              color: AppTheme.mintPrimary, fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.textMuted, fontSize: 15)),
        ],
      ),
    );
  }
}
