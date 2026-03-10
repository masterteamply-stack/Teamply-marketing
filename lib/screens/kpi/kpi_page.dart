import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/task_link_panel.dart';
import '../../widgets/edit_dialog.dart';

class KpiPage extends StatefulWidget {
  const KpiPage({super.key});

  @override
  State<KpiPage> createState() => _KpiPageState();
}

class _KpiPageState extends State<KpiPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;
    final selectedTeam = provider.selectedTeam;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showAddKpiDialog(context, provider),
              backgroundColor: AppTheme.mintPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 28, isMobile ? 14 : 24, isMobile ? 16 : 28, 0),
              color: AppTheme.bgCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMobile)
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Text('KPI 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            if (selectedTeam != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(int.parse('0xFF${selectedTeam.colorHex.substring(1)}')).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(int.parse('0xFF${selectedTeam.colorHex.substring(1)}')).withValues(alpha: 0.4)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(selectedTeam.iconEmoji, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(selectedTeam.name,
                                      style: TextStyle(color: Color(int.parse('0xFF${selectedTeam.colorHex.substring(1)}')), fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 4),
                          const Text('선택된 팀의 KPI와 개인별 KPI 설정 및 추적', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ]),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCsvKpiUploadDialog(context, provider),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('CSV 업로드'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bgCardLight, foregroundColor: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddKpiDialog(context, provider),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('KPI 추가'),
                      ),
                    ]),
                  if (!isMobile) const SizedBox(height: 16),
                  TabBar(
                    controller: _tab,
                    labelColor: AppTheme.mintPrimary,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.mintPrimary,
                    labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                    tabs: const [
                      Tab(text: '팀 전략 KPI'),
                      Tab(text: '개인별 KPI'),
                      Tab(text: '월별 트래커'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _TeamKpiTab(provider: provider),
                  _PersonalKpiTab(provider: provider),
                  _KpiTrackerTab(provider: provider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddKpiDialog(BuildContext context, AppProvider provider) {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final currentCtrl = TextEditingController();
    String unit = '건';
    String category = '매출';
    bool isTeamKpi = true;
    String? assignedTo;
    final categories = ['매출', 'ROI', 'ROAS', '리드', 'CTR', 'SEO', '콘텐츠', 'SNS', '이메일', '광고', '전환', '기타'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('KPI 추가', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  dense: true,
                  title: const Text('팀 KPI', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text('팀 전체 목표 여부', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  value: isTeamKpi, activeColor: AppTheme.mintPrimary,
                  onChanged: (v) => setState(() => isTeamKpi = v),
                ),
                const SizedBox(height: 8),
                TextField(controller: titleCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'KPI 이름 *')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category, dropdownColor: AppTheme.bgCard,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: targetCtrl, style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '목표값 *'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: currentCtrl, style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '현재값'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(labelText: '단위', hintText: unit),
                    onChanged: (v) => setState(() => unit = v.isEmpty ? '건' : v),
                  )),
                ]),
                if (!isTeamKpi) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: assignedTo, dropdownColor: AppTheme.bgCard,
                    decoration: const InputDecoration(labelText: '담당자'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('없음')),
                      ...provider.allUsers.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                    ],
                    onChanged: (v) => setState(() => assignedTo = v),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final target = double.tryParse(targetCtrl.text);
                if (title.isNotEmpty && target != null) {
                  provider.addKpi(KpiModel(
                    id: 'kpi_${DateTime.now().millisecondsSinceEpoch}',
                    title: title, category: category,
                    target: target,
                    current: double.tryParse(currentCtrl.text) ?? 0,
                    unit: unit, period: provider.selectedPeriod,
                    isTeamKpi: isTeamKpi, assignedTo: assignedTo,
                    dueDate: DateTime(DateTime.now().year, 12, 31),
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCsvKpiUploadDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _CsvKpiUploadDialog(provider: provider),
    );
  }
}

// ─── CSV KPI 업로드 다이얼로그 ───────────────────────────────────────────────
class _CsvKpiUploadDialog extends StatefulWidget {
  final AppProvider provider;
  const _CsvKpiUploadDialog({required this.provider});

  @override
  State<_CsvKpiUploadDialog> createState() => _CsvKpiUploadDialogState();
}

class _CsvKpiUploadDialogState extends State<_CsvKpiUploadDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, String>> _parsed = [];
  List<String> _parseErrors = [];
  bool _showPreview = false;
  bool _imported = false;

  static const _sampleCsv = '''name,current,target,unit,category,date
분기 총 매출,342000000,500000000,원,매출,2025-12-31
마케팅 ROI,285,300,%,ROI,2025-12-31
신규 리드 수,1650,2000,건,리드,2025-12-31
캠페인 클릭률,3.2,3.5,%,CTR,2025-12-31
SNS 팔로워 증가,4200,5000,명,SNS,2025-12-31''';

  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;

    final headerLine = lines.first.toLowerCase().replaceAll(' ', '');
    final headers = _splitLine(headerLine);

    if (!headers.contains('name') && !headers.contains('title')) {
      setState(() {
        _parseErrors = ['첫 번째 행에 name 또는 title 컬럼이 필요합니다.'];
        _parsed = []; _showPreview = true;
      });
      return;
    }

    final rows = <Map<String, String>>[];
    final errors = <String>[];

    for (int i = 1; i < lines.length; i++) {
      final cells = _splitLine(lines[i]);
      if (cells.every((c) => c.isEmpty)) continue;

      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = j < cells.length ? cells[j].trim() : '';
      }
      final name = (row['name'] ?? row['title'] ?? '').trim();
      if (name.isEmpty) {
        errors.add('행 ${i+1}: name이 비어 있습니다');
        continue;
      }
      final targetStr = row['target'] ?? '';
      if (targetStr.isNotEmpty && double.tryParse(targetStr) == null) {
        errors.add('행 ${i+1}: target 값이 유효하지 않습니다 ("$targetStr")');
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

  List<String> _splitLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuote = false;
    for (final c in line.split('')) {
      if (c == '"') { inQuote = !inQuote; }
      else if (c == ',' && !inQuote) { result.add(buf.toString()); buf.clear(); }
      else { buf.write(c); }
    }
    result.add(buf.toString());
    return result;
  }

  void _import() {
    if (_parsed.isEmpty) return;
    final errors = widget.provider.bulkAddKpisFromCsv(_parsed);
    setState(() { _imported = true; _parseErrors = errors; });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 820,
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.upload_file, color: AppTheme.mintPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('KPI CSV 벌크 업로드', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('현재 선택된 팀: ${widget.provider.selectedTeam?.name ?? "없음"}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ])),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppTheme.textMuted, size: 20)),
              ]),
            ),
            Expanded(child: _imported ? _buildResult() : _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 컬럼 가이드
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.info_outline, color: AppTheme.info, size: 13),
                    SizedBox(width: 6),
                    Text('CSV 컬럼 형식', style: TextStyle(color: AppTheme.info, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  _colGuideRow('name *', 'KPI 이름 (필수)'),
                  _colGuideRow('current', '현재값 (숫자)'),
                  _colGuideRow('target *', '목표값 (숫자)'),
                  _colGuideRow('unit', '단위 (원, %, 건 등)'),
                  _colGuideRow('category', '매출/ROI/CTR/SEO 등'),
                  _colGuideRow('date', '마감일 yyyy-MM-dd'),
                ]),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  _ctrl.text = _sampleCsv;
                  Clipboard.setData(const ClipboardData(text: _sampleCsv));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('샘플 CSV가 입력창에 붙여넣어졌습니다'), backgroundColor: AppTheme.success, duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3040))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.content_copy, color: AppTheme.textMuted, size: 13),
                    SizedBox(width: 6),
                    Text('샘플 CSV 불러오기', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              const Text('CSV 붙여넣기', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null, expands: true,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'name,current,target,unit,category,date\n분기 매출,342000000,500000000,원,매출,2025-12-31',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    filled: true, fillColor: AppTheme.bgCardLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.mintPrimary)),
                    contentPadding: const EdgeInsets.all(12),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ]),
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF1E3040)),
        Expanded(child: _showPreview ? _buildPreview() : _buildEmptyPreview()),
      ],
    );
  }

  Widget _colGuideRow(String col, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 90, child: Text(col, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
        Expanded(child: Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
      ]),
    );
  }

  Widget _buildEmptyPreview() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.table_chart_outlined, color: AppTheme.textMuted.withValues(alpha: 0.3), size: 48),
      const SizedBox(height: 12),
      const Text('CSV를 입력하고 "파싱 & 미리보기"를 클릭하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
    ]));
  }

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _parsed.isEmpty ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_parsed.isEmpty ? Icons.error_outline : Icons.check_circle_outline, color: _parsed.isEmpty ? AppTheme.error : AppTheme.success, size: 14),
              const SizedBox(width: 4),
              Text(
                _parsed.isEmpty ? '파싱 실패' : '${_parsed.length}개 KPI 파싱 완료',
                style: TextStyle(color: _parsed.isEmpty ? AppTheme.error : AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          if (_parseErrors.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('${_parseErrors.length}개 경고', style: const TextStyle(color: AppTheme.warning, fontSize: 12)),
            ),
          ],
          const Spacer(),
          if (_parsed.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload, size: 14),
              label: Text('${_parsed.length}개 KPI 등록'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
        ]),
        const SizedBox(height: 10),
        if (_parseErrors.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _parseErrors.map((e) => Row(children: [
              const Icon(Icons.warning_amber, color: AppTheme.warning, size: 12),
              const SizedBox(width: 4),
              Text(e, style: const TextStyle(color: AppTheme.warning, fontSize: 11)),
            ])).toList()),
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: _parsed.isEmpty
              ? const SizedBox()
              : ListView.builder(
                  itemCount: _parsed.length,
                  itemBuilder: (_, i) => _KpiPreviewCard(row: _parsed[i], index: i),
                ),
        ),
      ]),
    );
  }

  Widget _buildResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
          ),
          const SizedBox(height: 20),
          Text('${_parsed.length}개 KPI 등록 완료!', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('${widget.provider.selectedTeam?.name ?? "현재 팀"}에 성공적으로 추가되었습니다', style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          if (_parseErrors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Column(children: _parseErrors.map((e) => Text(e, style: const TextStyle(color: AppTheme.warning, fontSize: 12))).toList()),
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _KpiPreviewCard extends StatelessWidget {
  final Map<String, String> row;
  final int index;
  const _KpiPreviewCard({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = row['name'] ?? row['title'] ?? '';
    final target = row['target'] ?? '';
    final current = row['current'] ?? '0';
    final unit = row['unit'] ?? '건';
    final category = row['category'] ?? '기타';
    final date = row['date'] ?? '';
    final targetVal = double.tryParse(target) ?? 0;
    final currentVal = double.tryParse(current) ?? 0;
    final rate = targetVal > 0 ? (currentVal / targetVal * 100).clamp(0.0, 100.0) : 0.0;
    final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text('${index + 1}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(category, style: TextStyle(color: color, fontSize: 10)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('현재: $current$unit', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(width: 12),
          Text('목표: $target$unit', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          if (date.isNotEmpty) ...[const SizedBox(width: 12), Icon(Icons.calendar_today_outlined, size: 10, color: AppTheme.textMuted), const SizedBox(width: 3), Text(date, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))],
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.bgCardLight, valueColor: AlwaysStoppedAnimation(color), minHeight: 4),
        ),
      ]),
    );
  }
}

// ─── Team KPI Tab ────────────────────────────────────────────────────────────
class _TeamKpiTab extends StatefulWidget {
  final AppProvider provider;
  const _TeamKpiTab({required this.provider});

  @override
  State<_TeamKpiTab> createState() => _TeamKpiTabState();
}

class _TeamKpiTabState extends State<_TeamKpiTab> {
  final Set<String> _selected = {};
  bool _selectMode = false;

  @override
  Widget build(BuildContext context) {
    // 현재 선택된 팀의 팀KPI만 표시
    final kpis = widget.provider.teamKpis;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('팀 전략 KPI (${kpis.length}개)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const Spacer(),
            if (_selectMode && _selected.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () {
                  _showBulkDeleteConfirm(context, _selected.toList());
                },
                icon: const Icon(Icons.delete_outline, size: 14),
                label: Text('${_selected.length}개 삭제'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              const SizedBox(width: 8),
            ],
            if (kpis.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectMode = !_selectMode;
                  if (!_selectMode) _selected.clear();
                }),
                icon: Icon(_selectMode ? Icons.close : Icons.checklist, size: 14),
                label: Text(_selectMode ? '취소' : '선택 삭제', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
              ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: kpis.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.track_changes_outlined, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 48),
                      const SizedBox(height: 12),
                      const Text('이 팀의 KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('KPI 추가 버튼 또는 CSV 업로드로 KPI를 추가하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ]),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 3,
                      childAspectRatio: isMobile ? 2.2 : 1.6,
                      crossAxisSpacing: isMobile ? 10 : 16,
                      mainAxisSpacing: isMobile ? 10 : 16,
                    ),
                    itemCount: kpis.length,
                    itemBuilder: (_, i) => _KpiCard(
                      kpi: kpis[i], provider: widget.provider,
                      selectMode: _selectMode,
                      selected: _selected.contains(kpis[i].id),
                      onToggleSelect: (id) => setState(() {
                        if (_selected.contains(id)) _selected.remove(id);
                        else _selected.add(id);
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteConfirm(BuildContext context, List<String> ids) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('KPI 일괄 삭제', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('선택한 ${ids.length}개의 KPI를 삭제하시겠습니까?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteKpisBulk(ids);
              setState(() { _selected.clear(); _selectMode = false; });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('${ids.length}개 삭제', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Personal KPI Tab
class _PersonalKpiTab extends StatelessWidget {
  final AppProvider provider;
  const _PersonalKpiTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    // 현재 선택된 팀의 개인 KPI만 필터링
    final teamId = provider.selectedTeamId;
    final members = teamId != null
        ? provider.allUsers.where((u) => provider.selectedTeam?.getMember(u.id) != null).toList()
        : provider.allUsers;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: members.map((u) {
          final kpis = provider.kpis.where((k) => !k.isTeamKpi && k.assignedTo == u.id &&
              (teamId == null || k.teamId == teamId)).toList();
          if (kpis.isEmpty) return const SizedBox();
          final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(radius: 16, backgroundColor: col.withValues(alpha: 0.3), child: Text(u.avatarInitials, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Text(u.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('KPI ${kpis.length}개', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const Spacer(),
                Text('평균 달성률: ${(kpis.fold(0.0, (s, k) => s + k.achievementRate) / kpis.length).toStringAsFixed(0)}%',
                    style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 4,
                  childAspectRatio: isMobile ? 2.5 : 1.8,
                  crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                itemCount: kpis.length,
                itemBuilder: (_, i) => _KpiCard(kpi: kpis[i], provider: provider, memberColor: col),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF1E3040)),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final KpiModel kpi;
  final AppProvider provider;
  final Color? memberColor;
  final bool selectMode;
  final bool selected;
  final void Function(String)? onToggleSelect;
  const _KpiCard({required this.kpi, required this.provider, this.memberColor, this.selectMode = false, this.selected = false, this.onToggleSelect});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _showTasks = false;

  @override
  Widget build(BuildContext context) {
    final kpi = widget.kpi;
    final provider = widget.provider;
    final rate = kpi.achievementRate.clamp(0, 100);
    final color = widget.memberColor ?? (rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error);
    final tasks = provider.getTasksByKpiId(kpi.id);

    return GestureDetector(
      onTap: widget.selectMode ? () => widget.onToggleSelect?.call(kpi.id) : null,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: _showTasks
                  ? const BorderRadius.vertical(top: Radius.circular(14))
                  : BorderRadius.circular(14),
              border: Border.all(
                color: widget.selected ? AppTheme.mintPrimary : color.withValues(alpha: 0.2),
                width: widget.selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  if (widget.selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        widget.selected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: widget.selected ? AppTheme.mintPrimary : AppTheme.textMuted,
                        size: 16,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(kpi.category, style: TextStyle(color: color, fontSize: 10)),
                  ),
                  const Spacer(),
                  // 태스크 링크 버튼
                  if (!widget.selectMode && tasks.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _showTasks = !_showTasks),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.task_alt, color: AppTheme.info, size: 10),
                          const SizedBox(width: 3),
                          Text('${tasks.length}', style: const TextStyle(color: AppTheme.info, fontSize: 10)),
                          const SizedBox(width: 2),
                          Icon(_showTasks ? Icons.expand_less : Icons.expand_more, color: AppTheme.info, size: 10),
                        ]),
                      ),
                    ),
                  if (!widget.selectMode) ...[
                    const SizedBox(width: 4),
                    // 직접 삭제 버튼
                    GestureDetector(
                      onTap: () => _confirmDelete(context, kpi, provider),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.delete_outline, color: AppTheme.error, size: 14),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 16),
                      color: AppTheme.bgCard,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('수정', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                      ],
                      onSelected: (v) {
                        if (v == 'edit') {
                          showDialog(context: context, builder: (_) => KpiEditDialog(kpi: kpi, provider: provider));
                        }
                      },
                    ),
                  ],
                ]),
                Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.bgCardLight, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
                Text('${_fmtNum(kpi.current)}${kpi.unit} / ${_fmtNum(kpi.target)}${kpi.unit}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          if (_showTasks)
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: TaskLinkPanel(title: '연결 태스크', tasks: tasks, provider: provider, accentColor: color, compact: true),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, KpiModel kpi, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('KPI 삭제', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('"${kpi.title}"을(를) 삭제하시겠습니까?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              provider.deleteKpi(kpi.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${kpi.title}" 삭제됨'), backgroundColor: AppTheme.error, duration: const Duration(seconds: 2)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _fmtNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}

// KPI Tracker Tab
class _KpiTrackerTab extends StatelessWidget {
  final AppProvider provider;
  const _KpiTrackerTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final selectedId = provider.selectedKpiTrackerId;
    // 현재 팀의 KPI만 표시
    final kpis = provider.currentTeamKpis.isNotEmpty ? provider.currentTeamKpis : provider.kpis;
    if (kpis.isEmpty) {
      return const Center(child: Text('KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted)));
    }
    final kpi = kpis.firstWhere((k) => k.id == selectedId, orElse: () => kpis.first);
    final records = provider.getMonthlyRecordsForKpi(selectedId.isNotEmpty && kpis.any((k) => k.id == selectedId) ? selectedId : kpis.first.id);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('KPI 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kpis.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final k = kpis[i];
                final isSelected = k.id == kpi.id;
                final rate = k.achievementRate.clamp(0, 100);
                final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
                return GestureDetector(
                  onTap: () => provider.selectKpiForTracker(k.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.15) : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppTheme.mintPrimary : color.withValues(alpha: 0.4)),
                    ),
                    child: Text(k.title, style: TextStyle(color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal), maxLines: 1),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              Text('${kpi.period} · ${kpi.category}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _KpiMiniStat(label: '목표', value: '${_fmtNum(kpi.target)}${kpi.unit}', color: AppTheme.textMuted),
                _KpiMiniStat(label: '현재', value: '${_fmtNum(kpi.current)}${kpi.unit}', color: AppTheme.mintPrimary),
                _KpiMiniStat(label: '달성률', value: '${kpi.achievementRate.toStringAsFixed(0)}%',
                    color: kpi.achievementRate >= 80 ? AppTheme.success : kpi.achievementRate >= 60 ? AppTheme.warning : AppTheme.error),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('이 KPI의 월별 데이터가 없습니다', style: TextStyle(color: AppTheme.textMuted))))
          else ...[
            Container(
              height: 200, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Text('목표 vs 실적 추이', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Spacer(),
                  _ChartLegend(color: AppTheme.mintPrimary, label: '실적'),
                  SizedBox(width: 12),
                  _ChartLegend(color: AppTheme.textMuted, label: '목표'),
                ]),
                const SizedBox(height: 10),
                Expanded(child: _KpiLineChart(records: records, kpi: kpi)),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('월별 달성률', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Expanded(child: _AchievementBarChart(records: records)),
              ]),
            ),
            const SizedBox(height: 12),
            _buildTable(records, kpi.unit, compact: true),
          ],
        ]),
      );
    }

    // Desktop layout
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 220,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('KPI 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: kpis.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final k = kpis[i];
                  final isSelected = k.id == kpi.id;
                  final rate = k.achievementRate.clamp(0, 100);
                  final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
                  return InkWell(
                    onTap: () => provider.selectKpiForTracker(k.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.12) : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? AppTheme.mintPrimary : Colors.transparent),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(k.title, style: TextStyle(color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal), maxLines: 2),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.bgCardLight, valueColor: AlwaysStoppedAnimation(color), minHeight: 3),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('${kpi.period} · ${kpi.category}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ]),
                const Spacer(),
                _KpiMiniStat(label: '목표', value: '${_fmtNum(kpi.target)}${kpi.unit}', color: AppTheme.textMuted),
                const SizedBox(width: 24),
                _KpiMiniStat(label: '현재', value: '${_fmtNum(kpi.current)}${kpi.unit}', color: AppTheme.mintPrimary),
                const SizedBox(width: 24),
                _KpiMiniStat(label: '달성률', value: '${kpi.achievementRate.toStringAsFixed(0)}%',
                    color: kpi.achievementRate >= 80 ? AppTheme.success : kpi.achievementRate >= 60 ? AppTheme.warning : AppTheme.error),
              ]),
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Expanded(child: Center(child: Text('이 KPI의 월별 데이터가 없습니다', style: TextStyle(color: AppTheme.textMuted))))
            else
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Text('목표 vs 실적 추이', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        Spacer(),
                        _ChartLegend(color: AppTheme.mintPrimary, label: '실적'),
                        SizedBox(width: 12),
                        _ChartLegend(color: AppTheme.textMuted, label: '목표'),
                      ]),
                      const SizedBox(height: 12),
                      Expanded(child: _KpiLineChart(records: records, kpi: kpi)),
                    ]),
                  )),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('월별 달성률', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Expanded(child: _AchievementBarChart(records: records)),
                    ]),
                  )),
                ]),
              ),
            const SizedBox(height: 16),
            if (records.isNotEmpty) _buildTable(records, kpi.unit),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTable(List<MonthlyKpiRecord> records, String unit, {bool compact = false}) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
            child: Row(children: [
              Expanded(child: Text('월', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              Expanded(child: Text('목표', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              Expanded(child: Text('실적', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              Expanded(child: Text('달성률', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              if (!compact) Expanded(child: Text('Gap', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
            ]),
          ),
          ...records.map((r) {
            final color = r.achievementRate >= 80 ? AppTheme.success : r.achievementRate >= 60 ? AppTheme.warning : AppTheme.error;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
              child: Row(children: [
                Expanded(child: Text(r.monthLabel, style: TextStyle(color: AppTheme.textSecondary, fontSize: compact ? 11 : 12))),
                Expanded(child: Text('${_fmtNum(r.target)}$unit', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
                Expanded(child: Text('${_fmtNum(r.actual)}$unit', style: TextStyle(color: AppTheme.textPrimary, fontSize: compact ? 11 : 12))),
                Expanded(child: Text('${r.achievementRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600))),
                if (!compact)
                  Expanded(child: Text(
                    '${r.gap >= 0 ? '+' : ''}${_fmtNum(r.gap)}$unit',
                    style: TextStyle(color: r.gap >= 0 ? AppTheme.success : AppTheme.error, fontSize: 12),
                  )),
              ]),
            );
          }),
        ],
      ),
    );
  }

  static String _fmtNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}

class _KpiMiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiMiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 3, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
    ]);
  }
}

class _KpiLineChart extends StatelessWidget {
  final List<MonthlyKpiRecord> records;
  final KpiModel kpi;
  const _KpiLineChart({required this.records, required this.kpi});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox();
    final maxVal = records.fold(0.0, (m, r) => r.target > m ? r.target : r.actual > m ? r.actual : m);
    final minVal = records.fold(maxVal, (m, r) => r.actual < m ? r.actual : m) * 0.9;

    return LineChart(
      LineChartData(
        minY: minVal * 0.95, maxY: maxVal * 1.05,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1E3040), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= records.length) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(records[i].monthLabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)));
            })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 55,
            getTitlesWidget: (v, _) => Text(_shortNum(v), style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: records.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.actual)).toList(),
            isCurved: true, color: AppTheme.mintPrimary, barWidth: 2.5,
            dotData: FlDotData(show: true, getDotPainter: (s, _, __, i) {
              final r = records[i];
              return FlDotCirclePainter(radius: 4, color: r.isOnTrack ? AppTheme.success : AppTheme.error, strokeWidth: 2, strokeColor: AppTheme.bgCard);
            }),
            belowBarData: BarAreaData(show: true, color: AppTheme.mintPrimary.withValues(alpha: 0.08)),
          ),
          LineChartBarData(
            spots: records.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.target)).toList(),
            isCurved: false, color: AppTheme.textMuted.withValues(alpha: 0.5), barWidth: 1.5,
            dotData: const FlDotData(show: false), dashArray: [4, 4],
          ),
        ],
      ),
    );
  }

  static String _shortNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(0)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

class _AchievementBarChart extends StatelessWidget {
  final List<MonthlyKpiRecord> records;
  const _AchievementBarChart({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox();
    return BarChart(
      BarChartData(
        maxY: 130,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1E3040), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= records.length) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 4), child: Text(records[i].monthLabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)));
            })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
            getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: records.asMap().entries.map((e) {
          final rate = e.value.achievementRate.clamp(0, 130).toDouble();
          final color = rate >= 100 ? AppTheme.success : rate >= 80 ? AppTheme.mintPrimary : rate >= 60 ? AppTheme.warning : AppTheme.error;
          return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: rate, color: color, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
        }).toList(),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 100, color: AppTheme.success.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
        ]),
      ),
    );
  }
}
