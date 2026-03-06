import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// 알림 패널 (데스크톱 우측 슬라이드)
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.notificationPanelOpen) return const SizedBox.shrink();

    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(left: BorderSide(color: Color(0xFF1E3040), width: 1)),
      ),
      child: Column(
        children: [
          _buildHeader(context, provider),
          Expanded(child: _buildNotificationList(context, provider)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.bgCardLight,
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications, color: AppTheme.mintPrimary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('알림', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (provider.unreadNotificationCount > 0)
            TextButton(
              onPressed: provider.markAllNotificationsRead,
              child: const Text('모두 읽음', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 11)),
            ),
          IconButton(
            onPressed: provider.closeNotificationPanel,
            icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, AppProvider provider) {
    final notifications = provider.notifications;
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, color: AppTheme.textMuted, size: 48),
            SizedBox(height: 12),
            Text('알림이 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (ctx, i) {
        final n = notifications[i];
        return _NotificationTile(
          notification: n,
          fromUser: provider.getUserById(n.fromUserId),
          onTap: () {
            provider.markNotificationRead(n.id);
            // Navigate based on related type
            if (n.relatedType == 'task' && n.relatedId != null) {
              provider.selectTask(n.relatedId!);
              provider.closeNotificationPanel();
            } else if (n.relatedType == 'dm' && n.fromUserId != provider.currentUser.id) {
              provider.openDm(n.fromUserId);
              provider.closeNotificationPanel();
            }
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final AppUser? fromUser;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.fromUser,
    required this.onTap,
  });

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.mention: return Icons.alternate_email;
      case NotificationType.comment: return Icons.chat_bubble_outline;
      case NotificationType.dm: return Icons.mail_outline;
      case NotificationType.taskAssigned: return Icons.assignment_ind_outlined;
      case NotificationType.taskDue: return Icons.alarm;
      case NotificationType.kpiAlert: return Icons.flag_outlined;
      case NotificationType.teamInvite: return Icons.group_add_outlined;
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case NotificationType.mention: return AppTheme.mintPrimary;
      case NotificationType.comment: return const Color(0xFF29B6F6);
      case NotificationType.dm: return const Color(0xFFAB47BC);
      case NotificationType.taskAssigned: return const Color(0xFFFFB300);
      case NotificationType.taskDue: return const Color(0xFFFF7043);
      case NotificationType.kpiAlert: return const Color(0xFFEF5350);
      case NotificationType.teamInvite: return const Color(0xFF66BB6A);
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final avatarColor = fromUser?.avatarColor != null
        ? Color(int.parse('0xFF${fromUser!.avatarColor!.substring(1)}'))
        : AppTheme.mintPrimary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRead ? Colors.transparent : AppTheme.mintPrimary.withValues(alpha: 0.05),
          border: const Border(bottom: BorderSide(color: Color(0xFF1A2E3E), width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor.withValues(alpha: 0.2),
                  child: Text(
                    fromUser?.avatarInitials ?? '?',
                    style: TextStyle(color: avatarColor, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: _iconColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bgCard, width: 1.5),
                    ),
                    child: Icon(_icon, color: Colors.white, size: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.mintPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(_timeAgo(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
