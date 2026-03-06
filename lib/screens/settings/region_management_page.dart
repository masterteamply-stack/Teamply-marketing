import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

// ════════════════════════════════════════════════════════
//  권역 & 나라 관리 페이지
// ════════════════════════════════════════════════════════
class RegionManagementPage extends StatefulWidget {
  const RegionManagementPage({super.key});

  @override
  State<RegionManagementPage> createState() => _RegionManagementPageState();
}

class _RegionManagementPageState extends State<RegionManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: const Text('권역 & 나라 관리',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppTheme.mintPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.mintPrimary,
          tabs: const [
            Tab(text: '🌏  권역 관리'),
            Tab(text: '🗺️  나라 코드 관리'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _RegionTab(provider: provider),
          _CountryTab(provider: provider),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  권역 탭
// ════════════════════════════════════════════════════════
class _RegionTab extends StatelessWidget {
  final AppProvider provider;
  const _RegionTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final regions = provider.regions;

    return Column(
      children: [
        // 툴바
        Container(
          color: AppTheme.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Text('총 ${regions.length}개 권역',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showBulkDialog(context),
              icon: const Icon(Icons.upload_file_rounded, size: 14, color: AppTheme.accentBlue),
              label: const Text('CSV 업로드', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showEditDialog(context, null),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('권역 추가', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        // 목록
        Expanded(
          child: regions.isEmpty
              ? _emptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: regions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RegionCard(
                    region: regions[i],
                    clientCount: provider.clients.where((c) => c.region == regions[i].name).length,
                    onEdit: () => _showEditDialog(context, regions[i]),
                    onDelete: () => _confirmDelete(context, regions[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.map_rounded, size: 32, color: AppTheme.textMuted),
      ),
      const SizedBox(height: 16),
      const Text('등록된 권역이 없습니다', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('권역을 추가하거나 CSV로 업로드하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => _showEditDialog(context, null),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('권역 추가'),
      ),
    ]),
  );

  void _showEditDialog(BuildContext ctx, MarketingRegion? region) {
    showDialog(
      context: ctx,
      builder: (_) => _RegionEditDialog(region: region, provider: provider),
    );
  }

  void _showBulkDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _RegionBulkUploadDialog(provider: provider),
    );
  }

  void _confirmDelete(BuildContext ctx, MarketingRegion r) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('권역 삭제', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('「${r.name}」 권역을 삭제하시겠습니까?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () { provider.deleteRegion(r.id); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 권역 카드 ──────────────────────────────────────────
class _RegionCard extends StatelessWidget {
  final MarketingRegion region;
  final int clientCount;
  final VoidCallback onEdit, onDelete;
  const _RegionCard({required this.region, required this.clientCount, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.tryParse('0xFF${region.colorHex.replaceFirst('#', '')}') ?? 0xFF00C9A7);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Text(region.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(region.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                if (region.regionCode != null)
                  Text(region.regionCode!, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const Spacer(),
              // 고객사 수 뱃지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('고객사 $clientCount개', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.edit_rounded, size: 15, color: AppTheme.textMuted),
                  onPressed: onEdit, tooltip: '편집',
                  constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30), padding: EdgeInsets.zero),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.error),
                  onPressed: onDelete, tooltip: '삭제',
                  constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30), padding: EdgeInsets.zero),
            ]),
          ),
          // 국가 목록
          if (region.countries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('포함 국가', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: region.countries.map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(c, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  )).toList(),
                ),
              ]),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text('포함 국가 없음', style: TextStyle(color: AppTheme.textDisabled, fontSize: 11)),
            ),
          if (region.description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(region.description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  권역 편집 다이얼로그
// ════════════════════════════════════════════════════════
class _RegionEditDialog extends StatefulWidget {
  final MarketingRegion? region;
  final AppProvider provider;
  const _RegionEditDialog({required this.region, required this.provider});

  @override
  State<_RegionEditDialog> createState() => _RegionEditDialogState();
}

class _RegionEditDialogState extends State<_RegionEditDialog> {
  late TextEditingController _nameCtrl, _codeCtrl, _descCtrl, _countryCtrl;
  String _colorHex = '#00C9A7';
  String _icon = '🌍';
  List<String> _countries = [];

  static const _colorOptions = [
    '#00C9A7', '#4DB8FF', '#BD7FEB', '#FF8C5A', '#FFC93C',
    '#6EE79C', '#FF6B6B', '#29B6F6', '#AB47BC', '#FF7043',
  ];
  static const _iconOptions = ['🌏', '🌍', '🌎', '🌐', '🗺️', '🏔️', '🏙️', '⭐', '🔵', '🟢'];

  @override
  void initState() {
    super.initState();
    final r = widget.region;
    _nameCtrl    = TextEditingController(text: r?.name ?? '');
    _codeCtrl    = TextEditingController(text: r?.regionCode ?? '');
    _descCtrl    = TextEditingController(text: r?.description ?? '');
    _countryCtrl = TextEditingController();
    _colorHex    = r?.colorHex ?? '#00C9A7';
    _icon        = r?.icon ?? '🌍';
    _countries   = List<String>.from(r?.countries ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose(); _descCtrl.dispose(); _countryCtrl.dispose();
    super.dispose();
  }

  void _addCountry() {
    final c = _countryCtrl.text.trim().toUpperCase();
    if (c.isNotEmpty && !_countries.contains(c)) {
      setState(() { _countries.add(c); _countryCtrl.clear(); });
    }
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final now = DateTime.now();
    final id = widget.region?.id ?? 'reg_${now.millisecondsSinceEpoch}';
    final updated = MarketingRegion(
      id: id,
      name: _nameCtrl.text.trim(),
      regionCode: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      countries: _countries,
      colorHex: _colorHex,
      icon: _icon,
    );
    if (widget.region == null) {
      widget.provider.addRegion(updated);
    } else {
      widget.provider.updateRegion(updated);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.region == null;
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.map_rounded, color: AppTheme.mintPrimary, size: 22),
              const SizedBox(width: 12),
              Text(isNew ? '권역 추가' : '권역 편집',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 기본 정보
                Row(children: [
                  Expanded(flex: 3, child: _field('권역명 *', _nameCtrl, hint: '예: 동남아, 중동, 북미')),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _field('권역 코드', _codeCtrl, hint: 'SEA, ME, NA…')),
                ]),
                const SizedBox(height: 12),
                _field('설명', _descCtrl, hint: '권역에 대한 간략한 설명 (선택)', maxLines: 2),
                const SizedBox(height: 16),

                // 색상 선택
                const Text('색상', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _colorOptions.map((hex) {
                    final color = Color(int.tryParse('0xFF${hex.replaceFirst('#', '')}') ?? 0xFF00C9A7);
                    final selected = _colorHex == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _colorHex = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: selected ? 2.5 : 0,
                          ),
                          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)] : [],
                        ),
                        child: selected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 아이콘 선택
                const Text('아이콘', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _iconOptions.map((icon) {
                    final selected = _icon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => _icon = icon),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.mintPrimary.withValues(alpha: 0.2) : AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selected ? AppTheme.mintPrimary : AppTheme.border, width: selected ? 1.5 : 1),
                        ),
                        child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 포함 국가
                const Text('포함 국가 코드', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _countryCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '국가 코드 입력 (예: KR, VN, AE)',
                        hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true, fillColor: AppTheme.bgSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
                      ),
                      onSubmitted: (_) => _addCountry(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCountry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgSurface,
                      foregroundColor: AppTheme.mintPrimary,
                      side: BorderSide(color: AppTheme.mintPrimary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('추가'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (_countries.isNotEmpty)
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _countries.map((c) => Chip(
                      label: Text(c, style: const TextStyle(fontSize: 11)),
                      onDeleted: () => setState(() => _countries.remove(c)),
                      deleteIcon: const Icon(Icons.close, size: 12),
                      backgroundColor: AppTheme.bgSurface,
                      side: const BorderSide(color: AppTheme.border),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    )).toList(),
                  ),
              ]),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: Text(isNew ? '추가' : '저장', style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, maxLines: maxLines,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: AppTheme.bgSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
        ),
      ),
    ]);
}

// ════════════════════════════════════════════════════════
//  권역 CSV 벌크 업로드
// ════════════════════════════════════════════════════════
class _RegionBulkUploadDialog extends StatefulWidget {
  final AppProvider provider;
  const _RegionBulkUploadDialog({required this.provider});

  @override
  State<_RegionBulkUploadDialog> createState() => _RegionBulkUploadDialogState();
}

class _RegionBulkUploadDialogState extends State<_RegionBulkUploadDialog> {
  final _ctrl = TextEditingController();
  List<MarketingRegion> _parsed = [];
  String? _error;
  bool _parsedOk = false;

  static const _template =
    'name,regionCode,icon,colorHex,countries,description\n'
    '동남아,SEA,🌏,#00C9A7,"VN,TH,SG,MY,ID",동남아시아 지역\n'
    '중동,ME,🌍,#FFC93C,"AE,SA,QA,KW",중동 지역\n'
    '북미,NA,🌎,#4DB8FF,"US,CA,MX",북미 지역';

  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) { setState(() { _error = 'CSV 데이터를 입력하세요'; _parsedOk = false; }); return; }
    try {
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) throw 'empty';

      final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      final nameIdx   = header.indexWhere((h) => h == 'name' || h == '권역명');
      final codeIdx   = header.indexWhere((h) => h == 'regioncode' || h == 'region_code' || h == '코드');
      final iconIdx   = header.indexWhere((h) => h == 'icon' || h == '아이콘');
      final colorIdx  = header.indexWhere((h) => h == 'colorhex' || h == 'color' || h == '색상');
      final countryIdx= header.indexWhere((h) => h == 'countries' || h == '국가' || h == '나라');
      final descIdx   = header.indexWhere((h) => h == 'description' || h == '설명');
      if (nameIdx < 0) throw '"name" 컬럼이 없습니다';

      final results = <MarketingRegion>[];
      for (final line in lines.skip(1)) {
        // 따옴표로 감싸진 쉼표 처리
        final cols = _parseCsvLine(line);
        String get(int idx) => idx >= 0 && idx < cols.length ? cols[idx].trim() : '';
        final countries = get(countryIdx).split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        results.add(MarketingRegion(
          id: 'reg_${DateTime.now().millisecondsSinceEpoch}_${results.length}',
          name: get(nameIdx),
          regionCode: codeIdx >= 0 && get(codeIdx).isNotEmpty ? get(codeIdx) : null,
          icon: iconIdx >= 0 && get(iconIdx).isNotEmpty ? get(iconIdx) : '🌍',
          colorHex: colorIdx >= 0 && get(colorIdx).isNotEmpty ? get(colorIdx) : '#00C9A7',
          countries: countries,
          description: descIdx >= 0 && get(descIdx).isNotEmpty ? get(descIdx) : null,
        ));
      }
      setState(() { _parsed = results; _parsedOk = true; _error = null; });
    } catch (e) {
      setState(() { _error = '파싱 오류: $e'; _parsedOk = false; _parsed = []; });
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (final ch in line.runes) {
      final c = String.fromCharCode(ch);
      if (c == '"') { inQuotes = !inQuotes; }
      else if (c == ',' && !inQuotes) { result.add(buf.toString()); buf.clear(); }
      else { buf.write(c); }
    }
    result.add(buf.toString());
    return result;
  }

  void _import() {
    for (final r in _parsed) widget.provider.addRegion(r);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_parsed.length}개 권역이 추가되었습니다'),
      backgroundColor: AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.upload_file_rounded, color: AppTheme.accentBlue, size: 22),
              const SizedBox(width: 12),
              const Text('권역 CSV 일괄 업로드',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: _template));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('템플릿 복사됨')));
                },
                icon: const Icon(Icons.copy_outlined, size: 14),
                label: const Text('템플릿 복사', style: TextStyle(fontSize: 12)),
              ),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('CSV 형식 (국가는 쌍따옴표로 감싸 쉼표 구분)',
                        style: TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(6)),
                      child: const Text(_template, style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontFamily: 'monospace')),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text('CSV 데이터', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrl,
                  maxLines: 7,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '위 템플릿을 참고하여 붙여넣으세요...',
                    hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
                    filled: true, fillColor: AppTheme.bgSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                ],
                if (_parsedOk && _parsed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${_parsed.length}개 권역 파싱 완료',
                      style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _parse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentBlue,
                        side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('파싱 확인'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _parsedOk && _parsed.isNotEmpty ? _import : null,
                      icon: const Icon(Icons.upload_rounded, size: 16),
                      label: Text(_parsed.isNotEmpty ? '${_parsed.length}개 추가' : '가져오기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintPrimary,
                        disabledBackgroundColor: AppTheme.bgCardLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  나라 코드 탭 (고객사 국가 목록 집계 + 신규 추가 안내)
// ════════════════════════════════════════════════════════
class _CountryTab extends StatefulWidget {
  final AppProvider provider;
  const _CountryTab({required this.provider});

  @override
  State<_CountryTab> createState() => _CountryTabState();
}

class _CountryTabState extends State<_CountryTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    // 고객사에서 사용 중인 국가 집계
    final Map<String, Map<String, dynamic>> countryMap = {};
    for (final c in widget.provider.clients) {
      if (c.country == null) continue;
      final key = c.country!.toUpperCase();
      if (!countryMap.containsKey(key)) {
        countryMap[key] = {'region': c.region ?? '미지정', 'count': 0, 'revenue': 0.0};
      }
      countryMap[key]!['count'] = (countryMap[key]!['count'] as int) + 1;
      countryMap[key]!['revenue'] = (countryMap[key]!['revenue'] as double) + c.revenue;
    }

    final countries = countryMap.entries
        .where((e) => _search.isEmpty || e.key.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));

    return Column(
      children: [
        Container(
          color: AppTheme.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '국가 코드 검색...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true, fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
                ),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        // 헤더
        Container(
          color: AppTheme.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _th('국가 코드', flex: 2), _th('권역', flex: 2),
            _th('고객사 수', flex: 2, align: TextAlign.right),
            _th('총 매출 (₩)', flex: 3, align: TextAlign.right),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(
          child: countries.isEmpty
              ? const Center(child: Text('데이터 없음\n고객사에서 국가 코드를 입력하면 자동 집계됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.6)))
              : ListView.separated(
                  itemCount: countries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (_, i) {
                    final entry = countries[i];
                    final fmt = NumberFormat('#,###');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Expanded(flex: 2, child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                            ),
                            child: Text(entry.key, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ])),
                        Expanded(flex: 2, child: Text(entry.value['region'] as String,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                        Expanded(flex: 2, child: Text('${entry.value['count']}개',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                        Expanded(flex: 3, child: Text(
                            (entry.value['revenue'] as double) > 0
                                ? '₩${fmt.format(entry.value['revenue'])}'
                                : '—',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: (entry.value['revenue'] as double) > 0
                                  ? AppTheme.mintPrimary : AppTheme.textDisabled,
                              fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) => Expanded(
    flex: flex,
    child: Text(label, textAlign: align,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  );
}

// end of file
