// ════════════════════════════════════════════════════════════════
//  CSV Smart Task Upload Dialog
//  Step 1 : 파일 첨부 또는 직접 붙여넣기
//  Step 2 : 열 매핑 (자동 추천 + 수동 조정)
//  Step 3 : 미리보기 테이블 → 저장
// ════════════════════════════════════════════════════════════════
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';

// ── web 전용 파일 선택 (플랫폼 조건부)
import '../utils/web_utils.dart';

// ── 태스크 필드 정의 ─────────────────────────────────────────
class _TF {
  final String key;
  final String label;
  final bool required;
  const _TF(this.key, this.label, {this.required = false});
}

const _kFields = [
  _TF('title',       '제목 (Title)',           required: true),
  _TF('description', '설명 (Description)'),
  _TF('status',      '상태 (todo/done 등)'),
  _TF('priority',    '우선순위 (low/high 등)'),
  _TF('dueDate',     '마감일 (yyyy-MM-dd)'),
  _TF('tags',        '태그 (;구분)'),
  _TF('assigneeIds', '담당자ID (;구분)'),
  _TF('externalId',  '외부 ID'),
  _TF('year',        '연도'),
  _TF('target',      '목표값'),
  _TF('unit',        '단위'),
  _TF('pillar',      '전략 필러'),
  _TF('theme',       '테마'),
  _TF('owner',       '담당자명'),
  _TF('__skip__',    '이 열 무시'),
];

// 자동 매핑 사전
const _kAutoMap = {
  'title':'title','name':'title','제목':'title','이름':'title','태스크명':'title',
  'description':'description','desc':'description','설명':'description',
  'status':'status','상태':'status',
  'priority':'priority','우선순위':'priority',
  'duedate':'dueDate','due_date':'dueDate','due':'dueDate','마감일':'dueDate',
  'tags':'tags','tag':'tags','태그':'tags',
  'assigneeids':'assigneeIds','assignee':'assigneeIds','assignees':'assigneeIds',
  'id':'externalId','no':'externalId','번호':'externalId',
  'year':'year','연도':'year',
  'target':'target','목표':'target','목표값':'target',
  'unit':'unit','단위':'unit',
  'pillar':'pillar','필러':'pillar','전략필러':'pillar',
  'theme':'theme','테마':'theme','주제':'theme',
  'owner':'owner','담당자':'owner','담당자명':'owner','오너':'owner',
};

const _kSample =
    'ID,Name,Year,Target,Unit,Pillar,Theme,Owner\n'
    'B2D-01,SteerStar 리포지셔닝,2026,1,EA,Brand to Demand,Brand Equity,이기환\n'
    'B2D-02,Choice kit 확장 전개,2026,1,EA,Brand to Demand,Brand Preference,이기환\n'
    'D2D-01,New arrivals 콘텐츠 시리즈,2026,24,건,Demand to Demand,Product Marketing,김민준';

// ════════════════════════════════════════════════════════════
enum _Step { upload, mapping, preview }

class CsvTaskUploadDialog extends StatefulWidget {
  final String projectId;
  final AppProvider provider;
  const CsvTaskUploadDialog({
    super.key,
    required this.projectId,
    required this.provider,
  });
  @override
  State<CsvTaskUploadDialog> createState() => _CsvTaskUploadDialogState();
}

class _CsvTaskUploadDialogState extends State<CsvTaskUploadDialog> {
  _Step _step = _Step.upload;

  // ── Step 1 상태 ──────────────────────────────────────────
  final _pasteCtrl = TextEditingController();
  String? _fileName;
  bool _isDragging = false;
  String? _uploadError;
  bool _showPasteArea = false;

  // ── Step 2/3 상태 ────────────────────────────────────────
  List<String>       _headers  = [];
  List<List<String>> _dataRows = [];
  Map<int, String>   _mapping  = {};   // colIdx → fieldKey
  List<String>       _parseErrors = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  //  파일 선택 (웹 네이티브 input[type=file])
  // ════════════════════════════════════════════════════════
  void _pickFile() {
    if (!kIsWeb) return;
    pickCsvFile(
      onFileRead: (fileName, text) {
        if (!mounted) return;
        setState(() {
          _fileName = fileName;
          _uploadError = null;
          _pasteCtrl.text = text;
        });
        _tryProceedToMapping(text);
      },
    );
  }

  // ════════════════════════════════════════════════════════
  //  CSV 파싱 → 매핑 단계로 이동
  // ════════════════════════════════════════════════════════
  bool _tryProceedToMapping(String text) {
    text = text.trim();
    if (text.isEmpty) {
      setState(() => _uploadError = 'CSV 내용이 비어 있습니다');
      return false;
    }

    final lines = text
        .split('\n')
        .map((l) => l.trim().replaceAll('\r', ''))
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) {
      setState(() => _uploadError = '헤더 행 + 데이터 행이 최소 1개씩 필요합니다');
      return false;
    }

    final headers = _splitCsv(lines[0]);
    final dataRows = <List<String>>[];
    for (int i = 1; i < lines.length; i++) {
      final vals = _splitCsv(lines[i]);
      while (vals.length < headers.length) vals.add('');
      dataRows.add(vals);
    }

    // 자동 매핑
    final autoMap = <int, String>{};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().replaceAll(' ', '');
      final m = _kAutoMap[h];
      autoMap[i] = m ?? '__skip__';
    }

    setState(() {
      _headers  = headers;
      _dataRows = dataRows;
      _mapping  = autoMap;
      _parseErrors = [];
      _uploadError = null;
      _step = _Step.mapping;
    });
    return true;
  }

  List<String> _splitCsv(String line) {
    final res = <String>[];
    final buf = StringBuffer();
    bool inQ = false;
    for (final c in line.characters) {
      if (c == '"') { inQ = !inQ; }
      else if (c == ',' && !inQ) { res.add(buf.toString().trim()); buf.clear(); }
      else { buf.write(c); }
    }
    res.add(buf.toString().trim());
    return res;
  }

  // ════════════════════════════════════════════════════════
  //  저장
  // ════════════════════════════════════════════════════════
  Future<void> _save() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 60));

    final mapped = <Map<String, String>>[];
    for (final row in _dataRows) {
      final m = <String, String>{};
      for (int i = 0; i < _headers.length; i++) {
        final fk = _mapping[i];
        if (fk != null && fk != '__skip__' && !m.containsKey(fk)) {
          m[fk] = i < row.length ? row[i] : '';
        }
      }
      mapped.add(m);
    }

    final errs = widget.provider.bulkAddTasksFromCsv(widget.projectId, mapped);
    setState(() => _isSaving = false);
    if (!mounted) return;

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(errs.isEmpty
          ? '✅ ${mapped.length}개 태스크가 추가되었습니다'
          : '⚠ ${errs.length}건 오류 포함, ${mapped.length - errs.length}개 저장됨'),
      backgroundColor: errs.isEmpty ? AppTheme.accentGreen : AppTheme.warning,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Column(children: [
          _buildHeader(),
          _buildStepper(),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(child: _buildBody()),
          const Divider(height: 1, color: AppTheme.border),
          _buildFooter(),
        ]),
      ),
    );
  }

  // ── 헤더 ────────────────────────────────────────────────
  Widget _buildHeader() {
    final subtitle = _step == _Step.upload
        ? 'CSV / Excel 파일을 첨부하거나 내용을 직접 붙여넣기 하세요'
        : _step == _Step.mapping
            ? '각 열이 어떤 태스크 필드인지 지정하세요'
            : '${_dataRows.length}개 태스크 미리보기 — 이상 없으면 저장하세요';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.mintPrimary, AppTheme.accentBlue],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CSV 태스크 일괄 업로드',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }

  // ── 스텝 인디케이터 ──────────────────────────────────────
  Widget _buildStepper() {
    const labels = ['① 파일 업로드', '② 열 매핑', '③ 저장'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _step.index;
          final done   = i < _step.index;
          final col = active
              ? AppTheme.mintPrimary
              : done
                  ? AppTheme.mintPrimary.withValues(alpha: 0.5)
                  : AppTheme.textMuted;
          return Expanded(child: Row(children: [
            if (i > 0) Expanded(child: Container(height: 1,
                color: done ? AppTheme.mintPrimary : AppTheme.border)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.mintPrimary
                    : done
                        ? AppTheme.mintPrimary.withValues(alpha: 0.15)
                        : AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : col)),
            ),
            if (i < labels.length - 1) Expanded(child: Container(height: 1,
                color: done ? AppTheme.mintPrimary : AppTheme.border)),
          ]));
        }),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.upload:  return _buildUploadStep();
      case _Step.mapping: return _buildMappingStep();
      case _Step.preview: return _buildPreviewStep();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 1 — 파일 업로드
  // ══════════════════════════════════════════════════════════
  Widget _buildUploadStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 파일 선택 드롭존 ────────────────────────────────
        GestureDetector(
          onTap: _pickFile,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 170,
              decoration: BoxDecoration(
                color: _isDragging
                    ? AppTheme.mintPrimary.withValues(alpha: 0.10)
                    : AppTheme.bgDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isDragging
                      ? AppTheme.mintPrimary
                      : _fileName != null
                          ? AppTheme.accentGreen
                          : AppTheme.border,
                  width: _isDragging ? 2 : 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: _fileName != null
                  ? _buildFileAttached()
                  : _buildDropPrompt(),
            ),
          ),
        ),

        if (_uploadError != null) ...[
          const SizedBox(height: 8),
          _errorBanner(_uploadError!),
        ],

        const SizedBox(height: 16),

        // ── 구분선 ───────────────────────────────────────────
        Row(children: [
          const Expanded(child: Divider(color: AppTheme.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('또는 직접 붙여넣기',
                style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 12)),
          ),
          const Expanded(child: Divider(color: AppTheme.border)),
        ]),

        const SizedBox(height: 12),

        // ── 붙여넣기 토글 버튼 ───────────────────────────────
        Row(children: [
          OutlinedButton.icon(
            icon: Icon(_showPasteArea ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 15),
            label: Text(_showPasteArea ? '숨기기' : 'CSV 텍스트 직접 입력'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => setState(() => _showPasteArea = !_showPasteArea),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.content_paste, size: 14),
            label: const Text('샘플 불러오기', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mintPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            ),
            onPressed: () {
              setState(() {
                _pasteCtrl.text = _kSample;
                _showPasteArea  = true;
                _fileName       = null;
                _uploadError    = null;
              });
            },
          ),
        ]),

        // ── 붙여넣기 영역 ────────────────────────────────────
        if (_showPasteArea) ...[
          const SizedBox(height: 10),
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: TextField(
              controller: _pasteCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  color: AppTheme.textPrimary, height: 1.55),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(12),
                border: InputBorder.none,
                hintText:
                    'ID,Name,Year,Target,Unit,Pillar,Theme,Owner\n'
                    'B2D-01,SteerStar 리포지셔닝,2026,1,EA,Brand to Demand,Brand Equity,이기환\n'
                    '...',
                hintStyle: TextStyle(
                    color: AppTheme.textMuted, fontSize: 12, height: 1.55),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy, size: 13),
              label: const Text('복사', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _pasteCtrl.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('클립보드에 복사되었습니다'),
                  duration: Duration(seconds: 1),
                ));
              },
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── 지원 형식 안내 ───────────────────────────────────
        _infoBanner(
          '💡 지원 형식',
          'CSV(.csv) 또는 텍스트(.txt) 파일 — 엑셀에서 "CSV UTF-8로 저장" 후 업로드\n'
          '첫 번째 행이 헤더(열 이름)여야 합니다. 어떤 열 이름이든 다음 단계에서 직접 매핑할 수 있습니다.',
        ),
      ]),
    );
  }

  Widget _buildFileAttached() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 28),
      ),
      const SizedBox(height: 10),
      Text(_fileName!,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('파일이 첨부되었습니다 — 다른 파일로 변경하려면 클릭하세요',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      const SizedBox(height: 8),
      TextButton.icon(
        icon: const Icon(Icons.refresh, size: 13, color: AppTheme.textMuted),
        label: const Text('다른 파일 선택', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
        onPressed: () => setState(() { _fileName = null; _pasteCtrl.clear(); }),
      ),
    ]);
  }

  Widget _buildDropPrompt() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: AppTheme.mintPrimary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.upload_rounded, color: AppTheme.mintPrimary, size: 30),
      ),
      const SizedBox(height: 12),
      const Text('클릭하여 CSV 파일 첨부',
          style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      RichText(text: TextSpan(
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        children: [
          const TextSpan(text: '엑셀에서 '),
          TextSpan(
            text: '"CSV UTF-8(.csv)로 저장"',
            style: const TextStyle(
                color: AppTheme.mintPrimary, fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: ' 후 업로드 · .csv / .txt 지원'),
        ],
      )),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 2 — 열 매핑
  // ══════════════════════════════════════════════════════════
  Widget _buildMappingStep() {
    // 미리보기용 샘플 (최대 3행)
    final preview = _dataRows.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // 요약 행
        Row(children: [
          _badge('${_headers.length}개 열', AppTheme.accentBlue),
          const SizedBox(width: 8),
          _badge('${_dataRows.length}개 행', AppTheme.mintPrimary),
          if (_fileName != null) ...[
            const SizedBox(width: 8),
            _badge(_fileName!, AppTheme.accentGreen),
          ],
          const Spacer(),
          Text('● 필수 매핑',
              style: TextStyle(color: AppTheme.accentRed.withValues(alpha: 0.8), fontSize: 11)),
        ]),
        const SizedBox(height: 14),

        // 매핑 테이블
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: [
            // 헤더 행
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(children: const [
                SizedBox(width: 36,
                    child: Text('#', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 130,
                    child: Text('CSV 열 이름', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 14),
                SizedBox(width: 180,
                    child: Text('샘플 데이터', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 14),
                Expanded(child: Text('→ 태스크 필드', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // 각 열 행
            ...List.generate(_headers.length, (ci) {
              final sampleVals = preview
                  .map((r) => ci < r.length ? r[ci] : '')
                  .where((v) => v.isNotEmpty)
                  .take(2)
                  .join(' / ');
              final cur = _mapping[ci] ?? '__skip__';
              final isMapped = cur != '__skip__';
              final isRequired = cur == 'title';

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(children: [
                    // 번호
                    SizedBox(width: 36,
                        child: Text('${ci + 1}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                    // 열 이름
                    SizedBox(
                      width: 130,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMapped
                              ? AppTheme.mintPrimary.withValues(alpha: 0.10)
                              : AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isRequired
                                ? AppTheme.mintPrimary
                                : isMapped
                                    ? AppTheme.mintPrimary.withValues(alpha: 0.35)
                                    : AppTheme.border,
                          ),
                        ),
                        child: Text(_headers[ci],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: isMapped ? FontWeight.w600 : FontWeight.w400,
                                color: isMapped ? AppTheme.textPrimary : AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 샘플
                    SizedBox(
                      width: 180,
                      child: Text(
                        sampleVals.isEmpty ? '—' : sampleVals,
                        style: TextStyle(
                            fontSize: 11,
                            color: sampleVals.isEmpty
                                ? AppTheme.textMuted
                                : AppTheme.textSecondary,
                            fontStyle: sampleVals.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 드롭다운
                    Expanded(child: _mappingDropdown(ci, cur)),
                  ]),
                ),
                if (ci < _headers.length - 1)
                  const Divider(height: 1, color: AppTheme.border, indent: 14, endIndent: 14),
              ]);
            }),
          ]),
        ),

        const SizedBox(height: 14),
        _buildMappingSummary(),
      ]),
    );
  }

  Widget _mappingDropdown(int ci, String cur) {
    final isRequired = cur == 'title';
    final isMapped   = cur != '__skip__';
    return DropdownButtonFormField<String>(
      value: cur,
      isDense: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: AppTheme.bgCardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: isRequired
                ? AppTheme.mintPrimary
                : isMapped
                    ? AppTheme.mintPrimary.withValues(alpha: 0.4)
                    : AppTheme.border,
          ),
        ),
      ),
      dropdownColor: AppTheme.bgCard,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
      items: _kFields.map((f) {
        final alreadyTaken = f.key != '__skip__' &&
            f.key != cur &&
            _mapping.values.contains(f.key);
        return DropdownMenuItem(
          value: f.key,
          child: Row(children: [
            if (f.required) ...[
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: AppTheme.accentRed, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            Expanded(child: Text(f.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: alreadyTaken
                        ? AppTheme.textMuted
                        : AppTheme.textPrimary))),
            if (alreadyTaken)
              const Text(' ✓', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        );
      }).toList(),
      onChanged: (v) { if (v != null) setState(() => _mapping[ci] = v); },
    );
  }

  Widget _buildMappingSummary() {
    final mapped = _mapping.values.where((v) => v != '__skip__').toList();
    final hasTitle = mapped.contains('title');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasTitle
            ? AppTheme.accentGreen.withValues(alpha: 0.06)
            : AppTheme.accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasTitle
              ? AppTheme.accentGreen.withValues(alpha: 0.3)
              : AppTheme.accentOrange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
          hasTitle ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: hasTitle ? AppTheme.accentGreen : AppTheme.accentOrange,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            hasTitle ? '매핑 완료! 미리보기를 확인하고 저장하세요'
                : '⚠ "제목(Title)" 필드를 반드시 하나의 열에 매핑해야 합니다',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: hasTitle ? AppTheme.accentGreen : AppTheme.accentOrange),
          ),
          if (mapped.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 5, runSpacing: 3, children: mapped.map((fk) {
              final f = _kFields.firstWhere((x) => x.key == fk,
                  orElse: () => _TF(fk, fk));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(f.label.split(' ').first,
                    style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10)),
              );
            }).toList()),
          ],
        ])),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 3 — 미리보기
  // ══════════════════════════════════════════════════════════
  Widget _buildPreviewStep() {
    final activeCols = _mapping.entries
        .where((e) => e.value != '__skip__')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // 집계
    final owners = <String>{};
    final pillars = <String>{};
    for (final row in _dataRows) {
      for (final e in _mapping.entries) {
        final v = e.key < row.length ? row[e.key] : '';
        if (e.value == 'owner' && v.isNotEmpty) owners.add(v);
        if (e.value == 'pillar' && v.isNotEmpty) pillars.add(v);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 요약 배너
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.mintPrimary.withValues(alpha: 0.10),
            AppTheme.accentBlue.withValues(alpha: 0.06),
          ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          _summaryChip(Icons.task_alt_rounded, '${_dataRows.length}개 태스크', AppTheme.mintPrimary),
          if (owners.isNotEmpty) ...[
            const SizedBox(width: 20),
            _summaryChip(Icons.person_outline, '담당자 ${owners.length}명', AppTheme.accentBlue),
          ],
          if (pillars.isNotEmpty) ...[
            const SizedBox(width: 20),
            _summaryChip(Icons.flag_outlined, '필러 ${pillars.length}종', AppTheme.accentPurple),
          ],
          if (_fileName != null) ...[
            const SizedBox(width: 20),
            _summaryChip(Icons.attach_file, _fileName!, AppTheme.accentGreen),
          ],
        ]),
      ),
      const SizedBox(height: 10),

      // 테이블 헤더
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const SizedBox(width: 28,
              child: Text('#', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
          ...activeCols.map((e) {
            final f = _kFields.firstWhere((x) => x.key == e.value,
                orElse: () => _TF(e.value, e.value));
            return Expanded(child: Text(f.label.split(' ').first,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis));
          }),
        ]),
      ),

      // 데이터 목록
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            border: Border(
              left: BorderSide(color: AppTheme.border),
              right: BorderSide(color: AppTheme.border),
              bottom: BorderSide(color: AppTheme.border),
            ),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _dataRows.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.border),
            itemBuilder: (_, idx) {
              final row = _dataRows[idx];
              final titleColIdx = _mapping.entries
                  .where((e) => e.value == 'title')
                  .map((e) => e.key)
                  .firstOrNull;
              final isValid = titleColIdx != null &&
                  titleColIdx < row.length &&
                  row[titleColIdx].isNotEmpty;

              return Container(
                color: isValid
                    ? Colors.transparent
                    : AppTheme.accentRed.withValues(alpha: 0.05),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: Text('${idx + 1}',
                        style: TextStyle(
                            color: isValid ? AppTheme.textMuted : AppTheme.accentRed,
                            fontSize: 11)),
                  ),
                  ...activeCols.map((e) {
                    final val = e.key < row.length ? row[e.key] : '';
                    final isTitle = e.value == 'title';
                    return Expanded(child: Text(
                      val.isEmpty ? '—' : val,
                      style: TextStyle(
                          fontSize: 12,
                          color: val.isEmpty
                              ? AppTheme.textMuted
                              : isTitle
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                          fontWeight: isTitle ? FontWeight.w500 : FontWeight.w400,
                          fontStyle: val.isEmpty ? FontStyle.italic : FontStyle.normal),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ));
                  }),
                ]),
              );
            },
          ),
        ),
      ),
    ]);
  }

  // ── 푸터 ────────────────────────────────────────────────
  Widget _buildFooter() {
    final hasTitleMap = _mapping.values.contains('title');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        if (_step != _Step.upload)
          TextButton.icon(
            icon: const Icon(Icons.arrow_back, size: 15),
            label: const Text('이전'),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            onPressed: () => setState(() {
              if (_step == _Step.mapping) _step = _Step.upload;
              else if (_step == _Step.preview) _step = _Step.mapping;
            }),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
          child: const Text('취소'),
        ),
        const SizedBox(width: 8),

        // Step 1 → 파일 선택 또는 텍스트 붙여넣기 후 다음
        if (_step == _Step.upload)
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 15),
            label: const Text('다음: 열 매핑'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              // 파일이 이미 파싱된 경우 (파일 첨부 완료) → 바로 이동
              if (_headers.isNotEmpty) {
                setState(() => _step = _Step.mapping);
              } else {
                // 붙여넣기 텍스트로 파싱
                final text = _pasteCtrl.text.trim();
                if (text.isEmpty) {
                  setState(() => _uploadError = 'CSV 파일을 첨부하거나 텍스트를 붙여넣어주세요');
                } else {
                  _tryProceedToMapping(text);
                }
              }
            },
          ),

        // Step 2 → 미리보기
        if (_step == _Step.mapping)
          ElevatedButton.icon(
            icon: const Icon(Icons.preview, size: 15),
            label: const Text('미리보기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasTitleMap
                  ? AppTheme.mintPrimary
                  : AppTheme.bgCardLight,
              foregroundColor: hasTitleMap ? Colors.white : AppTheme.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: hasTitleMap
                ? () => setState(() => _step = _Step.preview)
                : null,
          ),

        // Step 3 → 저장
        if (_step == _Step.preview)
          ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 15),
            label: Text(_isSaving ? '저장 중...' : '${_dataRows.length}개 태스크 저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isSaving ? null : _save,
          ),
      ]),
    );
  }

  // ── 공용 위젯 ────────────────────────────────────────────
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _summaryChip(IconData icon, String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]);

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppTheme.accentRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 15),
      const SizedBox(width: 7),
      Expanded(child: Text(msg,
          style: const TextStyle(color: AppTheme.accentRed, fontSize: 12))),
    ]),
  );

  Widget _infoBanner(String title, String body) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.info.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline, color: AppTheme.info, size: 15),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: AppTheme.info, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(body,
            style: TextStyle(
                color: AppTheme.info.withValues(alpha: 0.8), fontSize: 11, height: 1.5)),
      ])),
    ]),
  );
}
