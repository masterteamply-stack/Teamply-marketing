// ════════════════════════════════════════════════════════════════
//  Task Attachment Tab
//  - 링크 / 파일URL 추가 (OneDrive, Google Drive, 이메일, 일반 링크, 직접 URL)
//  - 파일 유형 자동 감지 + 아이콘
//  - 체크리스트 항목 연결
//  - 미리보기 / 복사 / 삭제
// ════════════════════════════════════════════════════════════════
// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/web_utils.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class TaskAttachmentTab extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const TaskAttachmentTab({
    super.key,
    required this.task,
    required this.provider,
    required this.project,
  });
  @override
  State<TaskAttachmentTab> createState() => _TaskAttachmentTabState();
}

class _TaskAttachmentTabState extends State<TaskAttachmentTab> {
  // 필터: 전체 / 파일유형별
  String _filter = 'all'; // all | file | link | drive | email

  List<TaskAttachment> get _filtered {
    final all = widget.task.attachments;
    switch (_filter) {
      case 'file':
        return all.where((a) => a.sourceType == AttachmentSourceType.file).toList();
      case 'link':
        return all.where((a) => a.sourceType == AttachmentSourceType.link).toList();
      case 'drive':
        return all.where((a) =>
            a.sourceType == AttachmentSourceType.googleDrive ||
            a.sourceType == AttachmentSourceType.oneDrive).toList();
      case 'email':
        return all.where((a) => a.sourceType == AttachmentSourceType.email).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachments = _filtered;
    final all = widget.task.attachments;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── 헤더 ──────────────────────────────────────────────
        Row(children: [
          // 타이틀
          const Icon(Icons.attach_file_rounded, color: AppTheme.mintPrimary, size: 20),
          const SizedBox(width: 8),
          const Text('첨부파일 & 링크',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          _countBadge(all.length),
          const Spacer(),
          // 추가 버튼들
          _addLinkButton(),
          const SizedBox(width: 8),
          _addFileButton(),
        ]),
        const SizedBox(height: 14),

        // ── 필터 칩 ────────────────────────────────────────────
        _buildFilterRow(all),
        const SizedBox(height: 16),

        // ── 통계 요약 ──────────────────────────────────────────
        if (all.isNotEmpty) ...[
          _buildSummaryRow(all),
          const SizedBox(height: 16),
        ],

        // ── 첨부파일 목록 ──────────────────────────────────────
        Expanded(child: attachments.isEmpty
            ? _buildEmptyState()
            : _buildAttachmentList(attachments)),
      ]),
    );
  }

  // ── 링크 추가 버튼 ────────────────────────────────────────
  Widget _addLinkButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add_link_rounded, size: 16),
      label: const Text('링크 추가', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accentBlue,
        side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _showAddDialog(initialTab: 0),
    );
  }

  // ── 파일 업로드 버튼 (웹 기준 URL 또는 파일 첨부) ─────────
  Widget _addFileButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.upload_file_rounded, size: 16),
      label: const Text('파일 첨부', style: TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.mintPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _showAddDialog(initialTab: 1),
    );
  }

  // ── 필터 칩 행 ────────────────────────────────────────────
  Widget _buildFilterRow(List<TaskAttachment> all) {
    final filters = [
      ('all',   '전체 ${all.length}',       AppTheme.textSecondary),
      ('file',  '파일 ${all.where((a) => a.sourceType == AttachmentSourceType.file).length}', AppTheme.mintPrimary),
      ('link',  '링크 ${all.where((a) => a.sourceType == AttachmentSourceType.link).length}', AppTheme.accentBlue),
      ('drive', '드라이브 ${all.where((a) => a.sourceType == AttachmentSourceType.googleDrive || a.sourceType == AttachmentSourceType.oneDrive).length}', AppTheme.accentGreen),
      ('email', '이메일 ${all.where((a) => a.sourceType == AttachmentSourceType.email).length}', AppTheme.accentOrange),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(f.$2, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : f.$3,
              )),
              selected: isActive,
              onSelected: (_) => setState(() => _filter = f.$1),
              backgroundColor: f.$3.withValues(alpha: 0.08),
              selectedColor: f.$3,
              checkmarkColor: Colors.white,
              side: BorderSide(color: f.$3.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 요약 행 ──────────────────────────────────────────────
  Widget _buildSummaryRow(List<TaskAttachment> all) {
    // 유형별 집계
    final byType = <AttachmentFileType, int>{};
    for (final a in all) {
      byType[a.fileType] = (byType[a.fileType] ?? 0) + 1;
    }
    final topTypes = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.bar_chart_rounded, color: AppTheme.textMuted, size: 14),
        const SizedBox(width: 8),
        Text('총 ${all.length}개', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        ...topTypes.take(4).map((e) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(e.key.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text('${e.key.label} ${e.value}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        )),
      ]),
    );
  }

  // ── 빈 상태 ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppTheme.mintPrimary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.attach_file_rounded, color: AppTheme.mintPrimary, size: 34),
        ),
        const SizedBox(height: 16),
        const Text('첨부파일이 없습니다',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('파일 업로드, OneDrive/Google Drive 링크,\n이메일, URL 등 다양한 방식으로 첨부할 수 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add_link_rounded, size: 15),
            label: const Text('링크 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentBlue,
              side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddDialog(initialTab: 0),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 15),
            label: const Text('파일 첨부'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddDialog(initialTab: 1),
          ),
        ]),
      ]),
    );
  }

  // ── 첨부파일 목록 ────────────────────────────────────────
  Widget _buildAttachmentList(List<TaskAttachment> items) {
    // 체크리스트 항목에 연결된 것과 일반을 분리
    final linked   = items.where((a) => a.checklistItemId != null).toList();
    final unlinked = items.where((a) => a.checklistItemId == null).toList();

    return ListView(
      children: [
        if (linked.isNotEmpty) ...[
          _sectionHeader('체크리스트 연결', Icons.checklist_rounded, AppTheme.mintPrimary),
          ...linked.map((a) => _AttachmentCard(
            attachment: a,
            task: widget.task,
            provider: widget.provider,
            project: widget.project,
            onDelete: () => _deleteAttachment(a),
            onEdit: () => _editAttachment(a),
          )),
          const SizedBox(height: 10),
        ],
        if (unlinked.isNotEmpty) ...[
          if (linked.isNotEmpty)
            _sectionHeader('기타 첨부파일', Icons.folder_open_rounded, AppTheme.textMuted),
          ...unlinked.map((a) => _AttachmentCard(
            attachment: a,
            task: widget.task,
            provider: widget.provider,
            project: widget.project,
            onDelete: () => _deleteAttachment(a),
            onEdit: () => _editAttachment(a),
          )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
      ]),
    );
  }

  Widget _countBadge(int n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.mintPrimary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('$n', style: const TextStyle(
        color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  // ════════════════════════════════════════════════════════
  //  ADD DIALOG
  // ════════════════════════════════════════════════════════
  void _showAddDialog({int initialTab = 0}) {
    showDialog(
      context: context,
      builder: (_) => _AddAttachmentDialog(
        task: widget.task,
        provider: widget.provider,
        project: widget.project,
        initialTab: initialTab,
      ),
    ).then((_) => setState(() {}));
  }

  void _deleteAttachment(TaskAttachment a) {
    if (widget.project == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('첨부파일 삭제', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        content: Text('"${a.name}"을(를) 삭제하시겠습니까?',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
            onPressed: () {
              widget.provider.deleteTaskAttachment(widget.project!.id, widget.task.id, a.id);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _editAttachment(TaskAttachment a) {
    showDialog(
      context: context,
      builder: (_) => _EditAttachmentDialog(
        attachment: a,
        task: widget.task,
        provider: widget.provider,
        project: widget.project,
      ),
    ).then((_) => setState(() {}));
  }
}

// ════════════════════════════════════════════════════════
//  ATTACHMENT CARD
// ════════════════════════════════════════════════════════
class _AttachmentCard extends StatelessWidget {
  final TaskAttachment attachment;
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AttachmentCard({
    required this.attachment,
    required this.task,
    required this.provider,
    required this.project,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final color = Color(int.parse('0xFF${a.fileType.colorHex.substring(1)}'));

    // 연결된 체크리스트 항목 찾기
    ChecklistItem? linkedItem;
    if (a.checklistItemId != null) {
      try {
        linkedItem = task.checklist.firstWhere((c) => c.id == a.checklistItemId);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openUrl(a.url),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // 파일 타입 아이콘
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Center(child: Text(a.fileType.icon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),

            // 이름 + 메타
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // 출처 배지
                _sourceBadge(a.sourceType),
                const SizedBox(width: 6),
                Expanded(child: Text(a.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                // 파일 타입
                Text(a.fileType.label,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                if (a.fileSizeLabel.isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  Text(a.fileSizeLabel,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
                const Text(' · ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                Text(_formatDate(a.createdAt),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ]),
              if (a.description != null && a.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(a.description!,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              // 체크리스트 연결 표시
              if (linkedItem != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.mintPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      linkedItem.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: linkedItem.isDone ? AppTheme.mintPrimary : AppTheme.textMuted,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(linkedItem.title,
                        style: TextStyle(
                          color: linkedItem.isDone ? AppTheme.mintPrimary : AppTheme.textSecondary,
                          fontSize: 10,
                          decoration: linkedItem.isDone ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ],
            ])),

            // 액션 버튼
            Row(mainAxisSize: MainAxisSize.min, children: [
              // URL 복사
              _iconBtn(Icons.copy_outlined, AppTheme.textMuted, '복사', () {
                Clipboard.setData(ClipboardData(text: a.url));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('링크가 복사되었습니다'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ));
              }),
              // 편집
              _iconBtn(Icons.edit_outlined, AppTheme.textMuted, '편집', onEdit),
              // 삭제
              _iconBtn(Icons.delete_outline, AppTheme.accentRed, '삭제', onDelete),
            ]),
          ]),
        ),
      ),
    );
  }

  void _openUrl(String url) {
    if (!kIsWeb) return;
    if (url.isEmpty) return;
    openUrlInBrowser(url);
  }

  Widget _sourceBadge(AttachmentSourceType type) {
    Color color;
    switch (type) {
      case AttachmentSourceType.googleDrive: color = const Color(0xFF4285F4); break;
      case AttachmentSourceType.oneDrive:    color = const Color(0xFF0078D4); break;
      case AttachmentSourceType.email:       color = AppTheme.accentOrange; break;
      case AttachmentSourceType.link:        color = AppTheme.accentBlue; break;
      case AttachmentSourceType.file:        color = AppTheme.mintPrimary; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text('${type.emoji} ${type.label}',
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  Widget _iconBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) =>
      IconButton(
        icon: Icon(icon, size: 16, color: color),
        tooltip: tooltip,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        onPressed: onTap,
      );

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

// ════════════════════════════════════════════════════════
//  ADD ATTACHMENT DIALOG
// ════════════════════════════════════════════════════════
class _AddAttachmentDialog extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  final int initialTab;

  const _AddAttachmentDialog({
    required this.task,
    required this.provider,
    required this.project,
    required this.initialTab,
  });
  @override
  State<_AddAttachmentDialog> createState() => _AddAttachmentDialogState();
}

class _AddAttachmentDialogState extends State<_AddAttachmentDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _nameCtrl  = TextEditingController();
  final _urlCtrl   = TextEditingController();
  final _descCtrl  = TextEditingController();

  AttachmentSourceType _sourceType = AttachmentSourceType.link;
  String? _selectedChecklistId;
  bool _isSaving = false;
  String? _error;

  // 파일 첨부용
  String? _pickedFileName;
  int?    _pickedFileSize;

  // 빠른 출처 선택 프리셋
  static const _sourcePresets = [
    (AttachmentSourceType.link,        '🔗 일반 URL'),
    (AttachmentSourceType.googleDrive, '📂 Google Drive'),
    (AttachmentSourceType.oneDrive,    '☁️  OneDrive'),
    (AttachmentSourceType.email,       '📧 이메일'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // URL 입력 시 이름 자동 채우기
  void _onUrlChanged(String url) {
    if (_nameCtrl.text.isEmpty && url.isNotEmpty) {
      // URL에서 파일명 추출
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final seg = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
        if (seg != null) {
          _nameCtrl.text = Uri.decodeComponent(seg);
        }
      }
    }
    // 출처 자동 감지
    final lower = url.toLowerCase();
    if (lower.contains('drive.google.com') || lower.contains('docs.google.com')) {
      setState(() => _sourceType = AttachmentSourceType.googleDrive);
    } else if (lower.contains('onedrive.live.com') || lower.contains('sharepoint.com') || lower.contains('1drv.ms')) {
      setState(() => _sourceType = AttachmentSourceType.oneDrive);
    } else if (lower.contains('mailto:') || lower.contains('@') && lower.contains('.')) {
      setState(() => _sourceType = AttachmentSourceType.email);
    }
  }

  // 파일 선택 (웹)
  void _pickFile() {
    if (!kIsWeb) return;
    pickAnyFile(
      onFilePicked: (fileName, fileSize, objectUrl) {
        if (!mounted) return;
        setState(() {
          _pickedFileName = fileName;
          _pickedFileSize = fileSize;
          _urlCtrl.text   = objectUrl;
          _sourceType     = AttachmentSourceType.file;
          if (_nameCtrl.text.isEmpty) _nameCtrl.text = fileName;
        });
      },
    );
  }

  void _save() {
    final url  = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (url.isEmpty) { setState(() => _error = 'URL 또는 파일을 입력해주세요'); return; }
    if (name.isEmpty) { setState(() => _error = '이름을 입력해주세요'); return; }
    if (widget.project == null) { setState(() => _error = '프로젝트 정보가 없습니다'); return; }

    setState(() { _isSaving = true; _error = null; });

    final fileType = TaskAttachment.inferFileType(url, _sourceType);
    final attachment = TaskAttachment(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      url: url,
      fileType: fileType,
      sourceType: _sourceType,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      checklistItemId: _selectedChecklistId,
      uploadedBy: widget.provider.currentUser.id,
      createdAt: DateTime.now(),
      fileSizeBytes: _pickedFileSize,
    );

    widget.provider.addTaskAttachment(widget.project!.id, widget.task.id, attachment);
    setState(() => _isSaving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ "${attachment.name}" 첨부 완료'),
      backgroundColor: AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_file_rounded, color: AppTheme.mintPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('첨부파일 추가',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 17),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // 탭바: 링크 | 파일 업로드
          TabBar(
            controller: _tab,
            labelColor: AppTheme.mintPrimary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.mintPrimary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(icon: Icon(Icons.link, size: 16), text: '링크/URL'),
              Tab(icon: Icon(Icons.upload_file, size: 16), text: '파일 업로드'),
            ],
          ),
          const Divider(height: 1, color: AppTheme.border),

          // 본문
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── 탭 0: 링크 입력 ───────────────────────────
              if (_tab.index == 0) ...[
                // 출처 유형 선택
                const Text('출처', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: _sourcePresets.map((p) {
                  final active = _sourceType == p.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _sourceType = p.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.mintPrimary.withValues(alpha: 0.15)
                            : AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active ? AppTheme.mintPrimary : AppTheme.border,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Text(p.$2, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: active ? AppTheme.mintPrimary : AppTheme.textSecondary,
                      )),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 16),

                // URL 입력
                _field('URL / 링크 *', _urlCtrl,
                    hint: 'https://drive.google.com/... 또는 https://...',
                    onChanged: _onUrlChanged),
              ],

              // ── 탭 1: 파일 업로드 ────────────────────────
              if (_tab.index == 1) ...[
                GestureDetector(
                  onTap: _pickFile,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: double.infinity,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _pickedFileName != null
                              ? AppTheme.accentGreen
                              : AppTheme.border,
                          width: 1.5,
                        ),
                      ),
                      child: _pickedFileName != null
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.accentGreen, size: 28),
                              const SizedBox(height: 6),
                              Text(_pickedFileName!,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              if (_pickedFileSize != null)
                                Text(_formatSize(_pickedFileSize!),
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                              TextButton(
                                onPressed: () => setState(() {
                                  _pickedFileName = null; _pickedFileSize = null; _urlCtrl.clear();
                                }),
                                child: const Text('다른 파일 선택', style: TextStyle(fontSize: 11)),
                              ),
                            ])
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.upload_rounded, color: AppTheme.mintPrimary, size: 28),
                              const SizedBox(height: 6),
                              const Text('클릭하여 파일 선택',
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              const Text('PDF, PPT, Word, Excel, 이미지, 코드 등 모든 파일',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, color: AppTheme.info, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      '웹 환경에서는 파일을 직접 업로드하는 대신, OneDrive·Google Drive에 올린 후 공유 링크를 사용하는 것을 권장합니다.',
                      style: TextStyle(color: AppTheme.info.withValues(alpha: 0.85), fontSize: 11, height: 1.4),
                    )),
                  ]),
                ),
              ],

              const SizedBox(height: 14),

              // ── 공통 필드 ──────────────────────────────────
              _field('표시 이름 *', _nameCtrl, hint: '파일/링크 이름'),
              const SizedBox(height: 12),
              _field('설명 (선택)', _descCtrl, hint: '간단한 메모', maxLines: 2),
              const SizedBox(height: 12),

              // 체크리스트 연결
              if (widget.task.checklist.isNotEmpty) ...[
                const Text('체크리스트 항목 연결 (선택)',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedChecklistId,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppTheme.bgCardLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    hintText: '체크리스트 항목 선택 (없으면 일반 첨부)',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  items: [
                    const DropdownMenuItem(value: null, child:
                        Text('연결 안함', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                    ...widget.task.checklist.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(children: [
                        Icon(c.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 14,
                            color: c.isDone ? AppTheme.mintPrimary : AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(c.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.isDone ? AppTheme.textMuted : AppTheme.textPrimary,
                              decoration: c.isDone ? TextDecoration.lineThrough : null,
                            ))),
                      ]),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedChecklistId = v),
                ),
              ],

              // 에러
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 14),
                    const SizedBox(width: 6),
                    Text(_error!, style: const TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          )),

          // 푸터
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                child: const Text('취소'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 15),
                label: Text(_isSaving ? '저장 중...' : '첨부 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSaving ? null : _save,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1, void Function(String)? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: AppTheme.bgCardLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
        ),
      ),
    ]);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}

// ════════════════════════════════════════════════════════
//  EDIT ATTACHMENT DIALOG
// ════════════════════════════════════════════════════════
class _EditAttachmentDialog extends StatefulWidget {
  final TaskAttachment attachment;
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _EditAttachmentDialog({
    required this.attachment,
    required this.task,
    required this.provider,
    required this.project,
  });
  @override
  State<_EditAttachmentDialog> createState() => _EditAttachmentDialogState();
}

class _EditAttachmentDialogState extends State<_EditAttachmentDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  String? _selectedChecklistId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.attachment.name);
    _descCtrl = TextEditingController(text: widget.attachment.description ?? '');
    _selectedChecklistId = widget.attachment.checklistItemId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose();
  }

  void _save() {
    if (widget.project == null) return;
    widget.provider.updateTaskAttachment(
      widget.project!.id, widget.task.id, widget.attachment.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      checklistItemId: _selectedChecklistId ?? '',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: const Text('첨부파일 편집',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: _inputDec('표시 이름'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: _inputDec('설명 (선택)'),
          ),
          if (widget.task.checklist.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedChecklistId,
              decoration: _inputDec('체크리스트 연결'),
              dropdownColor: AppTheme.bgCard,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              items: [
                const DropdownMenuItem(value: null,
                    child: Text('연결 안함', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                ...widget.task.checklist.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.title, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (v) => setState(() => _selectedChecklistId = v),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white),
          child: const Text('저장'),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: AppTheme.bgCardLight,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.border)),
  );
}
