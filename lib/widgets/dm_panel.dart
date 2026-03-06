import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// DM 패널 (데스크톱 우측 슬라이드)
class DmPanel extends StatefulWidget {
  const DmPanel({super.key});

  @override
  State<DmPanel> createState() => _DmPanelState();
}

class _DmPanelState extends State<DmPanel> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final activeDmUserId = provider.activeDmUserId;
    if (activeDmUserId == null) return const SizedBox.shrink();

    final otherUser = provider.getUserById(activeDmUserId);
    final conv = provider.getOrCreateDm(activeDmUserId);

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(left: BorderSide(color: Color(0xFF1E3040), width: 1)),
      ),
      child: Column(
        children: [
          _buildHeader(context, provider, otherUser),
          Expanded(child: _buildMessages(provider, conv)),
          _buildInput(provider, activeDmUserId),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider, AppUser? user) {
    final avatarColor = user?.avatarColor != null
        ? Color(int.parse('0xFF${user!.avatarColor!.substring(1)}'))
        : AppTheme.mintPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.bgCardLight,
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: avatarColor.withValues(alpha: 0.2),
            child: Text(
              user?.avatarInitials ?? '?',
              style: TextStyle(color: avatarColor, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? '사용자',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  user?.jobTitle.label ?? '',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: provider.closeDm,
            icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(AppProvider provider, DmConversation conv) {
    final messages = conv.messages;
    final myId = provider.currentUser.id;

    if (messages.isEmpty) {
      return const Center(
        child: Text('첫 메시지를 보내보세요! 👋', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        final isMe = msg.fromUserId == myId;
        final sender = provider.getUserById(msg.fromUserId);
        final avatarColor = sender?.avatarColor != null
            ? Color(int.parse('0xFF${sender!.avatarColor!.substring(1)}'))
            : AppTheme.mintPrimary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: avatarColor.withValues(alpha: 0.2),
                  child: Text(sender?.avatarInitials ?? '?', style: TextStyle(color: avatarColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.mintPrimary.withValues(alpha: 0.2) : AppTheme.bgCardLight,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(12),
                    ),
                    border: isMe ? Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.content, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(_timeAgo(msg.createdAt), style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                    ],
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: avatarColor.withValues(alpha: 0.2),
                  child: Text(sender?.avatarInitials ?? '?', style: TextStyle(color: avatarColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Widget _buildInput(AppProvider provider, String toUserId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.bgCardLight,
        border: Border(top: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: '메시지 입력...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF1E3040)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF1E3040)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.mintPrimary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onSubmitted: (text) => _send(provider, toUserId, text),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(provider, toUserId, _inputCtrl.text),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.mintPrimary, Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _send(AppProvider provider, String toUserId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputCtrl.clear();
    provider.sendDm(toUserId, trimmed);
    _scrollToBottom();
  }
}

/// DM 목록 (모든 대화 목록)
class DmListWidget extends StatelessWidget {
  const DmListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final conversations = provider.dmConversations;
    final myId = provider.currentUser.id;

    if (conversations.isEmpty) {
      return const Center(
        child: Text('대화 없음', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: conversations.length,
      itemBuilder: (ctx, i) {
        final conv = conversations[i];
        final otherId = conv.otherUserId(myId);
        final other = provider.getUserById(otherId);
        final unread = conv.unreadCount(myId);
        final avatarColor = other?.avatarColor != null
            ? Color(int.parse('0xFF${other!.avatarColor!.substring(1)}'))
            : AppTheme.mintPrimary;

        return ListTile(
          dense: true,
          onTap: () => provider.openDm(otherId),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: avatarColor.withValues(alpha: 0.2),
                child: Text(other?.avatarInitials ?? '?', style: TextStyle(color: avatarColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              if (unread > 0)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: AppTheme.mintPrimary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          title: Text(other?.displayName ?? '?', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
          subtitle: Text(
            conv.lastMessage?.content ?? '',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
