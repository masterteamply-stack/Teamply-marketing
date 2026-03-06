// ════════════════════════════════════════════════════════════
//  In-App Notification Center
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

class NotificationCenter extends StatelessWidget {
  const NotificationCenter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final l10n  = AppLocalizations.of(context);
    final notifs = auth.notifications;

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.notifications_rounded,
                    color: AppTheme.mintPrimary, size: 18),
                const SizedBox(width: 8),
                Text(l10n.notifications,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                if (auth.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${auth.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
                const Spacer(),
                if (auth.unreadCount > 0)
                  TextButton(
                    onPressed: auth.markAllRead,
                    child: const Text('모두 읽음',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // Notification list
          if (notifs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 40, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    const Text('새 알림이 없습니다',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (ctx, i) => _NotifTile(notif: notifs[i], auth: auth),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final AuthProvider auth;
  const _NotifTile({required this.notif, required this.auth});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notif.type);
    final icon  = _typeIcon(notif.type);
    final ago   = _timeAgo(notif.createdAt);

    return GestureDetector(
      onTap: () => auth.markRead(notif.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notif.isRead
              ? Colors.transparent
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: notif.isRead
              ? null
              : Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif.title,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(notif.body,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(ago,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'task':     return AppTheme.accentBlue;
      case 'campaign': return AppTheme.mintPrimary;
      case 'budget':   return AppTheme.accentOrange;
      case 'mention':  return AppTheme.accentPurple;
      case 'report':   return AppTheme.accentGreen;
      default:         return AppTheme.textMuted;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'task':     return Icons.task_alt;
      case 'campaign': return Icons.campaign_outlined;
      case 'budget':   return Icons.account_balance_wallet_outlined;
      case 'mention':  return Icons.alternate_email;
      case 'report':   return Icons.bar_chart_outlined;
      default:         return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    if (diff.inDays < 7)     return '${diff.inDays}일 전';
    return DateFormat('MM/dd').format(dt);
  }
}
