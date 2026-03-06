import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// CSV 벌크 태스크 업로드 다이얼로그
/// 사용법: showDialog(context: context, builder: (_) => CsvBulkUploadDialog(projectId: ..., provider: ...))
class CsvBulkUploadDialog extends StatefulWidget {
  final String projectId;
  final String projectName;
  final AppProvider provider;

  const CsvBulkUploadDialog({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.provider,
  });

  @override
  State<CsvBulkUploadDialog> createState() => _CsvBulkUploadDialogState();
}

class _CsvBulkUploadDialogState extends State<CsvBulkUploadDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, String>> _parsed = [];
  List<String> _parseErrors = [];
  bool _showPreview = false;
  bool _imported = false;

  // CSV 헤더
  static const _headers = ['title', 'description', 'status', 'priority', 'dueDate', 'assigneeIds', 'tags'];

  // 샘플 CSV
  static const _sampleCsv = '''title,description,status,priority,dueDate,assigneeIds,tags
신규 캠페인 기획,Q3 여름 프로모션 기획 및 크리에이티브 제작,todo,high,2025-07-15,u1;u2,캠페인;기획
SNS 광고 집행,인스타그램 리타겟팅 광고 세팅 및 집행,inProgress,medium,2025-07-20,u2,광고;SNS
성과 보고서 작성,6월 마케팅 성과 분석 및 보고서 작성,todo,medium,2025-07-31,u1,보고서
랜딩페이지 A/B 테스트,신규 랜딩페이지 A/B 테스트 진행,inProgress,high,2025-07-25,u3,CRO;테스트
이메일 뉴스레터 발송,7월 뉴스레터 기획 및 발송,todo,low,2025-08-05,u2;u3,이메일;콘텐츠''';

  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;

    // 헤더 파싱
    final headerLine = lines.first.toLowerCase().replaceAll(' ', '');
    final headers = _splitCsvLine(headerLine);

    // 헤더 유효성
    if (!headers.contains('title')) {
      setState(() {
        _parseErrors = ['첫 번째 행에 title 컬럼이 필요합니다.'];
        _parsed = [];
        _showPreview = true;
      });
      return;
    }

    final rows = <Map<String, String>>[];
    final errors = <String>[];

    for (int i = 1; i < lines.length; i++) {
      final cells = _splitCsvLine(lines[i]);
      if (cells.length < headers.length && cells.every((c) => c.isEmpty)) continue;

      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = j < cells.length ? cells[j].trim() : '';
      }
      // 필수 필드 검증
      if (row['title']?.isEmpty != false) {
        errors.add('행 ${i+1}: title이 비어 있습니다');
        continue;
      }
      rows.add(row);
    }

    setState(() {
      _parsed = rows;
      _parseErrors = errors;
      _showPreview = true;
    });
  }

  List<String> _splitCsvLine(String line) {
    // 간단한 CSV 파서 (따옴표 지원)
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuote = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuote = !inQuote;
      } else if (c == ',' && !inQuote) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString());
    return result;
  }

  void _import() {
    if (_parsed.isEmpty) return;
    final errors = widget.provider.bulkAddTasksFromCsv(widget.projectId, _parsed);
    setState(() {
      _imported = true;
      _parseErrors = errors;
    });
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'inprogress': case '진행': return AppTheme.info;
      case 'inreview': case '검토': return AppTheme.warning;
      case 'done': case '완료': return AppTheme.success;
      default: return AppTheme.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'inprogress': return '진행';
      case 'inreview': return '검토';
      case 'done': return '완료';
      default: return '대기';
    }
  }

  Color _priorityColor(String s) {
    switch (s.toLowerCase()) {
      case 'urgent': return AppTheme.error;
      case 'high': return AppTheme.warning;
      case 'low': return AppTheme.textMuted;
      default: return AppTheme.info;
    }
  }

  String _priorityLabel(String s) {
    switch (s.toLowerCase()) {
      case 'urgent': return '긴급';
      case 'high': return '높음';
      case 'low': return '낮음';
      default: return '보통';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 820,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.mintPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.upload_file, color: AppTheme.mintPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CSV 벌크 업로드', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('${widget.projectName} · CSV로 태스크를 일괄 등록합니다',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                ),
              ]),
            ),

            Expanded(
              child: _imported ? _buildImportResult() : _buildUploadBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 좌측: 입력 영역 ──────────────────────────────
        SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 컬럼 가이드
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.info_outline, color: AppTheme.info, size: 13),
                      const SizedBox(width: 6),
                      const Text('CSV 컬럼 형식', style: TextStyle(color: AppTheme.info, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    ..._buildColGuide(),
                  ]),
                ),
                const SizedBox(height: 12),

                // 샘플 복사 버튼
                GestureDetector(
                  onTap: () {
                    _ctrl.text = _sampleCsv;
                    Clipboard.setData(const ClipboardData(text: _sampleCsv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('샘플 CSV가 입력창에 붙여넣어졌습니다'),
                          backgroundColor: AppTheme.success, duration: Duration(seconds: 2)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E3040)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.content_copy, color: AppTheme.textMuted, size: 13),
                      const SizedBox(width: 6),
                      const Text('샘플 CSV 불러오기', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // CSV 입력창
                const Text('CSV 붙여넣기', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'title,description,status,...\n태스크1,설명,...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      filled: true,
                      fillColor: AppTheme.bgCardLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E3040)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E3040)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.mintPrimary),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _parse,
                    icon: const Icon(Icons.preview, size: 16),
                    label: const Text('파싱 & 미리보기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 우측: 프리뷰 ──────────────────────────────────
        const VerticalDivider(width: 1, color: Color(0xFF1E3040)),
        Expanded(
          child: _showPreview ? _buildPreviewPanel() : _buildEmptyPreview(),
        ),
      ],
    );
  }

  List<Widget> _buildColGuide() {
    final guides = [
      ('title *', '태스크 제목 (필수)'),
      ('description', '설명 (선택)'),
      ('status', 'todo / inProgress / inReview / done'),
      ('priority', 'low / medium / high / urgent'),
      ('dueDate', '마감일 yyyy-MM-dd'),
      ('assigneeIds', '담당자 ID, ; 구분 (u1;u2)'),
      ('tags', '태그, ; 구분'),
    ];
    return guides.map((g) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(g.$1,
              style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ),
        Expanded(child: Text(g.$2, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
      ]),
    )).toList();
  }

  Widget _buildEmptyPreview() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.table_chart_outlined, color: AppTheme.textMuted.withValues(alpha: 0.3), size: 48),
        const SizedBox(height: 12),
        const Text('CSV를 입력하고 "파싱 & 미리보기"를 클릭하세요',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ]),
    );
  }

  Widget _buildPreviewPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 상태 바
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _parsed.isEmpty ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _parsed.isEmpty ? Icons.error_outline : Icons.check_circle_outline,
                color: _parsed.isEmpty ? AppTheme.error : AppTheme.success,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                _parsed.isEmpty
                    ? '파싱 실패'
                    : '${_parsed.length}개 태스크 파싱 완료',
                style: TextStyle(
                  color: _parsed.isEmpty ? AppTheme.error : AppTheme.success,
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          if (_parseErrors.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${_parseErrors.length}개 경고',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 12)),
            ),
          ],
          const Spacer(),
          if (_parsed.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload, size: 14),
              label: Text('${_parsed.length}개 등록'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ]),
        const SizedBox(height: 10),

        // 에러 목록
        if (_parseErrors.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _parseErrors.map((e) => Row(children: [
                const Icon(Icons.warning_amber, color: AppTheme.warning, size: 12),
                const SizedBox(width: 4),
                Text(e, style: const TextStyle(color: AppTheme.warning, fontSize: 11)),
              ])).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 프리뷰 테이블
        Expanded(
          child: _parsed.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  itemCount: _parsed.length,
                  itemBuilder: (_, i) => _PreviewTaskCard(
                    row: _parsed[i],
                    index: i,
                    statusColor: _statusColor,
                    statusLabel: _statusLabel,
                    priorityColor: _priorityColor,
                    priorityLabel: _priorityLabel,
                    provider: widget.provider,
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildImportResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
          ),
          const SizedBox(height: 20),
          Text('${_parsed.length}개 태스크 등록 완료!',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('${widget.projectName}에 성공적으로 추가되었습니다',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          if (_parseErrors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _parseErrors.map((e) => Text(e,
                    style: const TextStyle(color: AppTheme.warning, fontSize: 12))).toList(),
              ),
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _PreviewTaskCard extends StatelessWidget {
  final Map<String, String> row;
  final int index;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final Color Function(String) priorityColor;
  final String Function(String) priorityLabel;
  final AppProvider provider;

  const _PreviewTaskCard({
    required this.row, required this.index,
    required this.statusColor, required this.statusLabel,
    required this.priorityColor, required this.priorityLabel,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final status = row['status'] ?? 'todo';
    final priority = row['priority'] ?? 'medium';
    final dueDate = row['dueDate'] ?? '';
    final tags = (row['tags'] ?? '').split(';').where((t) => t.trim().isNotEmpty).toList();
    final assigneeIds = (row['assigneeIds'] ?? '').split(';').where((a) => a.trim().isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor(status).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(4)),
            child: Center(
              child: Text('${index + 1}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(row['title'] ?? '',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: statusColor(status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(statusLabel(status), style: TextStyle(color: statusColor(status), fontSize: 10)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: priorityColor(priority).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(priorityLabel(priority), style: TextStyle(color: priorityColor(priority), fontSize: 10)),
          ),
        ]),
        if (row['description']?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(row['description']!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 6),
        Row(children: [
          if (dueDate.isNotEmpty) ...[
            const Icon(Icons.calendar_today_outlined, size: 10, color: AppTheme.textMuted),
            const SizedBox(width: 3),
            Text(dueDate, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            const SizedBox(width: 10),
          ],
          if (assigneeIds.isNotEmpty) ...[
            const Icon(Icons.person_outline, size: 10, color: AppTheme.textMuted),
            const SizedBox(width: 3),
            Text(assigneeIds.join(', '), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            const SizedBox(width: 10),
          ],
          ...tags.take(3).map((t) => Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF1E3040)),
            ),
            child: Text(t, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          )),
        ]),
      ]),
    );
  }
}
