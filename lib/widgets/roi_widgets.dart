// ════════════════════════════════════════════════════════════════
//  ROI Analytics Widgets
//  권역별 / 국가별 / 고객사별  오더금액 · 매출 · ROI 위젯
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

// ════════════════════════════════════════════════════════
//  권역별 ROI 위젯
// ════════════════════════════════════════════════════════
class RegionRoiWidget extends StatelessWidget {
  final AppProvider provider;
  final String title;
  const RegionRoiWidget({super.key, required this.provider, this.title = '권역별 ROI'});

  @override
  Widget build(BuildContext context) {
    final data = _aggregateByRegion(provider);
    return _RoiCard(
      title: title,
      icon: '🌏',
      color: AppTheme.mintPrimary,
      rows: data,
      onAddEntry: () => _showAddDialog(context, provider, 'region'),
    );
  }

  static List<_RoiRow> _aggregateByRegion(AppProvider provider) {
    final map = <String, _RoiAgg>{};
    for (final e in provider.revenueEntries) {
      final region = e.region ?? '기타';
      map.putIfAbsent(region, () => _RoiAgg(region));
      map[region]!.add(e);
    }
    // 클라이언트의 권역 정보도 포함
    for (final c in provider.clients) {
      final region = c.region ?? '기타';
      if (!map.containsKey(region)) {
        map.putIfAbsent(region, () => _RoiAgg(region));
      }
    }
    return map.values
        .map((a) => _RoiRow(
              label: a.key,
              orderAmount: a.orderAmount,
              revenue: a.revenue,
              adSpend: a.adSpend,
            ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }
}

// ════════════════════════════════════════════════════════
//  국가별 ROI 위젯
// ════════════════════════════════════════════════════════
class CountryRoiWidget extends StatelessWidget {
  final AppProvider provider;
  final String title;
  const CountryRoiWidget({super.key, required this.provider, this.title = '국가별 ROI'});

  @override
  Widget build(BuildContext context) {
    final data = _aggregateByCountry(provider);
    return _RoiCard(
      title: title,
      icon: '🗺️',
      color: AppTheme.accentBlue,
      rows: data,
      onAddEntry: () => _showAddDialog(context, provider, 'country'),
    );
  }

  static List<_RoiRow> _aggregateByCountry(AppProvider provider) {
    final map = <String, _RoiAgg>{};
    for (final e in provider.revenueEntries) {
      final country = e.country ?? '기타';
      map.putIfAbsent(country, () => _RoiAgg(country));
      map[country]!.add(e);
    }
    // 클라이언트 국가 정보
    for (final c in provider.clients) {
      final country = c.country ?? '기타';
      if (!map.containsKey(country)) {
        map.putIfAbsent(country, () => _RoiAgg(country));
      }
    }
    return map.values
        .map((a) => _RoiRow(
              label: a.key,
              orderAmount: a.orderAmount,
              revenue: a.revenue,
              adSpend: a.adSpend,
            ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }
}

// ════════════════════════════════════════════════════════
//  고객사별 ROI 위젯
// ════════════════════════════════════════════════════════
class ClientRoiWidget extends StatelessWidget {
  final AppProvider provider;
  final String title;
  const ClientRoiWidget({super.key, required this.provider, this.title = '고객사별 ROI'});

  @override
  Widget build(BuildContext context) {
    final data = _aggregateByClient(provider);
    return _RoiCard(
      title: title,
      icon: '🏢',
      color: AppTheme.accentOrange,
      rows: data,
      onAddEntry: () => _showAddDialog(context, provider, 'client'),
    );
  }

  static List<_RoiRow> _aggregateByClient(AppProvider provider) {
    final map = <String, _RoiAgg>{};

    // revenueEntries 기반 집계
    for (final e in provider.revenueEntries) {
      final clientName = _clientName(provider, e.clientId);
      map.putIfAbsent(clientName, () => _RoiAgg(clientName));
      map[clientName]!.add(e);
    }

    // 클라이언트 직접 매출 추가 (entry 없는 경우)
    for (final c in provider.clients) {
      if (!map.containsKey(c.name) && c.revenue > 0) {
        final agg = _RoiAgg(c.name);
        agg.revenue = c.revenue;
        agg.orderAmount = c.revenue;
        map[c.name] = agg;
      }
    }

    return map.values
        .map((a) => _RoiRow(
              label: a.key,
              orderAmount: a.orderAmount,
              revenue: a.revenue,
              adSpend: a.adSpend,
            ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  static String _clientName(AppProvider provider, String clientId) {
    try {
      return provider.clients.firstWhere((c) => c.id == clientId).name;
    } catch (_) {
      return clientId.isNotEmpty ? clientId : '기타';
    }
  }
}

// ════════════════════════════════════════════════════════
//  공통 ROI 카드 위젯
// ════════════════════════════════════════════════════════
class _RoiCard extends StatefulWidget {
  final String title, icon;
  final Color color;
  final List<_RoiRow> rows;
  final VoidCallback onAddEntry;

  const _RoiCard({
    required this.title, required this.icon, required this.color,
    required this.rows, required this.onAddEntry,
  });

  @override
  State<_RoiCard> createState() => _RoiCardState();
}

class _RoiCardState extends State<_RoiCard> {
  _SortField _sortField = _SortField.revenue;
  bool _sortAsc = false;
  bool _expanded = true;

  List<_RoiRow> get _sorted {
    final rows = List<_RoiRow>.from(widget.rows);
    rows.sort((a, b) {
      double va, vb;
      switch (_sortField) {
        case _SortField.label: return _sortAsc ? a.label.compareTo(b.label) : b.label.compareTo(a.label);
        case _SortField.order: va = a.orderAmount; vb = b.orderAmount; break;
        case _SortField.revenue: va = a.revenue; vb = b.revenue; break;
        case _SortField.roi: va = a.roi; vb = b.roi; break;
        case _SortField.adSpend: va = a.adSpend; vb = b.adSpend; break;
      }
      return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
    });
    return rows;
  }

  void _sort(_SortField f) {
    setState(() {
      if (_sortField == f) _sortAsc = !_sortAsc;
      else { _sortField = f; _sortAsc = false; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sorted;
    final fmt = NumberFormat('#,###');

    // 합계
    final totalOrder   = rows.fold(0.0, (s, r) => s + r.orderAmount);
    final totalRevenue = rows.fold(0.0, (s, r) => s + r.revenue);
    final totalAd      = rows.fold(0.0, (s, r) => s + r.adSpend);
    final totalRoi     = totalAd > 0 ? ((totalRevenue - totalAd) / totalAd * 100) : 0.0;
    final totalRoas    = totalAd > 0 ? totalRevenue / totalAd : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── 헤더 ───────────────────────────────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(children: [
              Text(widget.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.title,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
              // 합계 배지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('매출 ${_fmtBillion(totalRevenue)}',
                    style: TextStyle(color: widget.color, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (totalRoi >= 0 ? AppTheme.accentGreen : AppTheme.accentRed).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('ROI ${totalRoi.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: totalRoi >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                      fontSize: 11, fontWeight: FontWeight.w600,
                    )),
              ),
              const SizedBox(width: 4),
              // 데이터 추가
              IconButton(
                icon: Icon(Icons.add_rounded, color: widget.color, size: 16),
                tooltip: '오더/매출 데이터 추가',
                onPressed: widget.onAddEntry,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textMuted, size: 16),
            ]),
          ),
        ),

        if (_expanded) ...[
          // ── 요약 카드 행 ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _SummaryCard('오더금액', _fmtBillion(totalOrder), AppTheme.accentBlue),
              const SizedBox(width: 8),
              _SummaryCard('실현매출', _fmtBillion(totalRevenue), AppTheme.accentGreen),
              const SizedBox(width: 8),
              _SummaryCard('광고비', _fmtBillion(totalAd), AppTheme.accentOrange),
              const SizedBox(width: 8),
              _SummaryCard('ROAS', '${totalRoas.toStringAsFixed(1)}x',
                  totalRoas >= 2 ? AppTheme.accentGreen : AppTheme.accentRed),
            ]),
          ),
          const SizedBox(height: 10),

          // ── 테이블 헤더 ──────────────────────────────────
          Container(
            color: AppTheme.bgDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _SortHeader('구분', _SortField.label, _sortField, _sortAsc, _sort, flex: 3),
              _SortHeader('오더금액', _SortField.order, _sortField, _sortAsc, _sort, flex: 2),
              _SortHeader('매출', _SortField.revenue, _sortField, _sortAsc, _sort, flex: 2),
              _SortHeader('광고비', _SortField.adSpend, _sortField, _sortAsc, _sort, flex: 2),
              _SortHeader('ROI', _SortField.roi, _sortField, _sortAsc, _sort, flex: 2),
              const Spacer(flex: 1),
            ]),
          ),

          // ── 데이터 행들 ──────────────────────────────────
          ...rows.take(8).map((r) => _DataRow(row: r, maxRevenue: totalRevenue, color: widget.color, fmt: fmt)),

          if (rows.length > 8)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('+${rows.length - 8}개 더',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }

  static String _fmtBillion(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B원';
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억원';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만원';
    return '${v.toStringAsFixed(0)}원';
  }
}

enum _SortField { label, order, revenue, adSpend, roi }

class _RoiAgg {
  final String key;
  double orderAmount = 0, revenue = 0, adSpend = 0;
  _RoiAgg(this.key);
  void add(ProjectRevenueEntry e) {
    orderAmount += e.orderAmount;
    revenue     += e.revenue;
    adSpend     += e.adSpend;
  }
}

class _RoiRow {
  final String label;
  final double orderAmount, revenue, adSpend;
  _RoiRow({required this.label, required this.orderAmount, required this.revenue, required this.adSpend});
  double get roi => adSpend > 0 ? ((revenue - adSpend) / adSpend * 100) : 0;
  double get roas => adSpend > 0 ? revenue / adSpend : 0;
}

Widget _SortHeader(String text, _SortField field, _SortField current, bool asc,
    void Function(_SortField) onSort, {int flex = 1}) =>
  Expanded(flex: flex, child: InkWell(
    onTap: () => onSort(field),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(text, style: TextStyle(
        color: current == field ? AppTheme.mintPrimary : AppTheme.textMuted,
        fontSize: 11, fontWeight: FontWeight.w600,
      )),
      if (current == field) ...[
        const SizedBox(width: 2),
        Icon(asc ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10, color: AppTheme.mintPrimary),
      ],
    ]),
  ));

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  ));
}

class _DataRow extends StatelessWidget {
  final _RoiRow row;
  final double maxRevenue;
  final Color color;
  final NumberFormat fmt;
  const _DataRow({required this.row, required this.maxRevenue, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final roiColor = row.roi >= 100 ? AppTheme.accentGreen
        : row.roi >= 0 ? AppTheme.accentBlue
        : AppTheme.accentRed;
    final barWidth = maxRevenue > 0 ? (row.revenue / maxRevenue).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // 구분
          Expanded(flex: 3, child: Text(row.label,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis)),
          // 오더금액
          Expanded(flex: 2, child: Text(_fmtK(row.orderAmount),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
          // 매출
          Expanded(flex: 2, child: Text(_fmtK(row.revenue),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600))),
          // 광고비
          Expanded(flex: 2, child: Text(_fmtK(row.adSpend),
              style: const TextStyle(color: AppTheme.accentOrange, fontSize: 11))),
          // ROI
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: roiColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${row.roi.toStringAsFixed(0)}%',
                style: TextStyle(color: roiColor, fontSize: 11, fontWeight: FontWeight.w700)),
          )),
          // ROAS
          Expanded(flex: 1, child: Text('${row.roas.toStringAsFixed(1)}x',
              style: TextStyle(
                color: row.roas >= 2 ? AppTheme.accentGreen : AppTheme.textMuted,
                fontSize: 10,
              ))),
        ]),
        // 매출 바 차트
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: barWidth,
            backgroundColor: color.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.5)),
            minHeight: 3,
          ),
        ),
      ]),
    );
  }

  static String _fmtK(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

// ════════════════════════════════════════════════════════
//  오더/매출 데이터 추가 다이얼로그
// ════════════════════════════════════════════════════════
void _showAddDialog(BuildContext context, AppProvider provider, String groupBy) {
  showDialog(
    context: context,
    builder: (_) => _AddRevenueDialog(provider: provider, defaultGroupBy: groupBy),
  );
}

class _AddRevenueDialog extends StatefulWidget {
  final AppProvider provider;
  final String defaultGroupBy;
  const _AddRevenueDialog({required this.provider, required this.defaultGroupBy});

  @override State<_AddRevenueDialog> createState() => _AddRevenueDialogState();
}

class _AddRevenueDialogState extends State<_AddRevenueDialog> {
  final _orderCtrl   = TextEditingController();
  final _revenueCtrl = TextEditingController();
  final _adCtrl      = TextEditingController();
  final _regionCtrl  = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _noteCtrl    = TextEditingController();
  String? _clientId;
  String _currency = 'KRW';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _orderCtrl.dispose(); _revenueCtrl.dispose(); _adCtrl.dispose();
    _regionCtrl.dispose(); _countryCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final order   = double.tryParse(_orderCtrl.text) ?? 0;
    final revenue = double.tryParse(_revenueCtrl.text) ?? 0;
    final ad      = double.tryParse(_adCtrl.text) ?? 0;
    if (order == 0 && revenue == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('오더금액 또는 매출을 입력해주세요'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    widget.provider.addRevenueEntry(ProjectRevenueEntry(
      id: 're_${DateTime.now().millisecondsSinceEpoch}',
      clientId: _clientId ?? '',
      country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
      region:  _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
      orderAmount: order,
      revenue: revenue,
      adSpend: ad,
      currency: _currency,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      date: _date,
    ));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ 데이터가 추가되었습니다'),
      backgroundColor: AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                child: const Icon(Icons.add_chart_rounded, color: AppTheme.accentGreen, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('오더/매출 데이터 추가',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 16),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 고객사 선택
              const Text('고객사', style: _lbl),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: _clientId,
                decoration: _dec('고객사 선택 (선택사항)'),
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                items: [
                  const DropdownMenuItem(value: null,
                      child: Text('직접 입력', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                  ...widget.provider.clients.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(children: [
                      Text(c.name, style: const TextStyle(fontSize: 12)),
                      if (c.country != null) Text(' · ${c.country}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ]),
                  )),
                ],
                onChanged: (v) {
                  setState(() {
                    _clientId = v;
                    if (v != null) {
                      final c = widget.provider.clients.firstWhere((c) => c.id == v);
                      if (c.country != null) _countryCtrl.text = c.country!;
                      if (c.region != null) _regionCtrl.text = c.region!;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _fieldW('권역', _regionCtrl, hint: '예: 국내, 동남아, 중동')),
                const SizedBox(width: 10),
                Expanded(child: _fieldW('국가코드', _countryCtrl, hint: '예: KR, US, SG')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _fieldW('오더금액', _orderCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _fieldW('실현매출', _revenueCtrl, keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _fieldW('광고비', _adCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('통화', style: _lbl),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: _dec('통화'),
                    dropdownColor: AppTheme.bgCard,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    items: ['KRW','USD','EUR','JPY','CNY','SGD','AED']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _currency = v ?? 'KRW'),
                  ),
                ])),
              ]),
              const SizedBox(height: 12),
              _fieldW('메모', _noteCtrl, maxLines: 2),
            ]),
          )),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(children: [
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 13),
                label: const Text('저장', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: _save,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static const _lbl = TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600);

  InputDecoration _dec(String hint) => InputDecoration(
    isDense: true, hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    filled: true, fillColor: AppTheme.bgCardLight,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: AppTheme.border)),
  );

  Widget _fieldW(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _lbl),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          isDense: true, hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true, fillColor: AppTheme.bgCardLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: AppTheme.border)),
        ),
      ),
    ]);
}
