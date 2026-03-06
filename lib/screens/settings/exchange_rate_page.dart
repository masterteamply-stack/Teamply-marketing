import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class ExchangeRatePage extends StatefulWidget {
  const ExchangeRatePage({super.key});
  @override
  State<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends State<ExchangeRatePage> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              color: AppTheme.bgCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('환율 관리', style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('글로벌 기준환율 및 프로젝트별 경영환율 설정',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    )),
                    _LastUpdatedBadge(),
                  ]),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tab,
                    labelColor: AppTheme.mintPrimary,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.mintPrimary,
                    tabs: const [
                      Tab(text: '글로벌 기준환율'),
                      Tab(text: '프로젝트 경영환율'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  const _GlobalRatesTab(),
                  const _ProjectRatesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastUpdatedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dt = p.globalRates.updatedAt;
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.access_time, color: AppTheme.textMuted, size: 12),
        const SizedBox(width: 4),
        Text('최종 업데이트: ${fmt.format(dt)}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 글로벌 기준환율 탭
// ─────────────────────────────────────────────────────────────
class _GlobalRatesTab extends StatelessWidget {
  const _GlobalRatesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // 우선 표시 통화 (주요 무역국 순서)
    final priority = [
      CurrencyCode.usd, CurrencyCode.eur, CurrencyCode.jpy,
      CurrencyCode.cny, CurrencyCode.gbp, CurrencyCode.hkd,
      CurrencyCode.sgd, CurrencyCode.aud, CurrencyCode.cad,
      CurrencyCode.thb, CurrencyCode.vnd, CurrencyCode.aed,
      CurrencyCode.rub, CurrencyCode.inr, CurrencyCode.chf,
      CurrencyCode.myr, CurrencyCode.php, CurrencyCode.idr,
      CurrencyCode.brl, CurrencyCode.mxn, CurrencyCode.nzd,
      CurrencyCode.sek, CurrencyCode.nok, CurrencyCode.dkk,
      CurrencyCode.pln, CurrencyCode.try_, CurrencyCode.zar,
      CurrencyCode.sar, CurrencyCode.twd,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppTheme.info, size: 16),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                '기준환율은 앱 전체에 기본값으로 적용됩니다. 프로젝트별로 경영환율을 별도 설정하면 해당 프로젝트에서 우선 적용됩니다.',
                style: TextStyle(color: AppTheme.info, fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          Text('KRW(원화) 기준 환율', style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // 환율 테이블 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(children: [
              Expanded(flex: 2, child: Text('통화', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 1, child: Text('통화코드', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 2, child: Text('현재 환율 (1단위 → ₩)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 2, child: Text('기본값', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              SizedBox(width: 80),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFF1E3040)),
          // 환율 행
          ...priority.map((c) => _RateRow(
            currency: c,
            currentRate: provider.getRateToKrw(c),
            defaultRate: c.defaultRateToKrw,
            onSave: (rate) => provider.updateGlobalRate(c, rate),
          )),
        ],
      ),
    );
  }
}

class _RateRow extends StatefulWidget {
  final CurrencyCode currency;
  final double currentRate;
  final double defaultRate;
  final void Function(double) onSave;

  const _RateRow({
    required this.currency, required this.currentRate,
    required this.defaultRate, required this.onSave,
  });

  @override
  State<_RateRow> createState() => _RateRowState();
}

class _RateRowState extends State<_RateRow> {
  bool _editing = false;
  late TextEditingController _ctrl;
  final fmt = NumberFormat('#,##0.####');

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentRate.toStringAsFixed(4));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.currency;
    final isCustom = (widget.currentRate - widget.defaultRate).abs() > 0.001;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Row(children: [
        // 통화명
        Expanded(flex: 2, child: Row(children: [
          Text(c.symbol, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            c.label.split('(').first.trim(),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          )),
        ])),
        // 코드
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(4),
          ),
          child: Text(c.code,
              style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
        )),
        // 현재 환율
        Expanded(flex: 2, child: _editing
            ? TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  prefixText: '₩ ',
                ),
              )
            : Row(children: [
                Text('₩ ${fmt.format(widget.currentRate)}',
                    style: TextStyle(
                      color: isCustom ? AppTheme.warning : AppTheme.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w500,
                    )),
                if (isCustom) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('경영', style: TextStyle(color: AppTheme.warning, fontSize: 9)),
                  ),
                ],
              ])),
        // 기본값
        Expanded(flex: 2, child: Text('₩ ${fmt.format(widget.defaultRate)}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        // 액션
        SizedBox(width: 80, child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: _editing
              ? [
                  GestureDetector(
                    onTap: () {
                      final v = double.tryParse(_ctrl.text.replaceAll(',', ''));
                      if (v != null && v > 0) widget.onSave(v);
                      setState(() => _editing = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('저장', style: TextStyle(color: AppTheme.success, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      _ctrl.text = widget.currentRate.toStringAsFixed(4);
                      setState(() => _editing = false);
                    },
                    child: const Icon(Icons.close, color: AppTheme.textMuted, size: 16),
                  ),
                ]
              : [
                  GestureDetector(
                    onTap: () => setState(() => _editing = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('수정', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ),
                  ),
                  if (isCustom) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => widget.onSave(widget.defaultRate),
                      child: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 14),
                    ),
                  ],
                ],
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 프로젝트 경영환율 탭
// ─────────────────────────────────────────────────────────────
class _ProjectRatesTab extends StatefulWidget {
  const _ProjectRatesTab();

  @override
  State<_ProjectRatesTab> createState() => _ProjectRatesTabState();
}

class _ProjectRatesTabState extends State<_ProjectRatesTab> {
  String? _selectedProjectId;
  String _selectedYear = '2025';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final projects = provider.projectStore;
    final years = ['2024', '2025', '2026'];

    if (projects.isEmpty) {
      return const Center(child: Text('프로젝트가 없습니다', style: TextStyle(color: AppTheme.textMuted)));
    }

    _selectedProjectId ??= projects.first.id;

    final selectedProj = projects.firstWhere(
      (p) => p.id == _selectedProjectId, orElse: () => projects.first,
    );
    final annualConfig = provider.getAnnualRate(_selectedProjectId!, _selectedYear);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로젝트 + 연도 선택
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('프로젝트', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E3040)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProjectId,
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: projects.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.iconEmoji} ${p.name}'),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                    ),
                  ),
                ),
              ],
            )),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('경영 연도', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y년'))).toList(),
                      onChanged: (v) => setState(() => _selectedYear = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('기준 통화', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E3040)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CurrencyCode>(
                      value: annualConfig.baseCurrency,
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: [CurrencyCode.krw, CurrencyCode.usd, CurrencyCode.eur].map((c) =>
                        DropdownMenuItem(value: c, child: Text(c.code))).toList(),
                      onChanged: (v) {
                        if (v != null) provider.setAnnualBaseCurrency(_selectedProjectId!, _selectedYear, v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 20),

          // 프로젝트 정보 요약
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(int.parse('0xFF${selectedProj.colorHex.substring(1)}'))
                  .withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Text(selectedProj.iconEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(selectedProj.name, style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${_selectedYear}년 경영환율 설정 | 기준통화: ${annualConfig.baseCurrency.code}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('마지막 수정: ${DateFormat('MM/dd HH:mm').format(annualConfig.updatedAt)}',
                    style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10)),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          Text('$_selectedYear년 경영환율 (KRW 기준)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // 주요 통화만 표시
          ...[
            CurrencyCode.usd, CurrencyCode.eur, CurrencyCode.jpy,
            CurrencyCode.cny, CurrencyCode.gbp, CurrencyCode.hkd,
            CurrencyCode.sgd, CurrencyCode.aud, CurrencyCode.thb,
            CurrencyCode.vnd, CurrencyCode.aed, CurrencyCode.rub,
          ].map((c) => _ProjectRateRow(
            currency: c,
            currentRate: annualConfig.getRateFor(c),
            globalRate: provider.getRateToKrw(c),
            onSave: (rate) => provider.updateAnnualRate(_selectedProjectId!, _selectedYear, c, rate),
          )),
        ],
      ),
    );
  }
}

class _ProjectRateRow extends StatefulWidget {
  final CurrencyCode currency;
  final double currentRate;
  final double globalRate;
  final void Function(double) onSave;

  const _ProjectRateRow({
    required this.currency, required this.currentRate,
    required this.globalRate, required this.onSave,
  });

  @override
  State<_ProjectRateRow> createState() => _ProjectRateRowState();
}

class _ProjectRateRowState extends State<_ProjectRateRow> {
  bool _editing = false;
  late TextEditingController _ctrl;
  final fmt = NumberFormat('#,##0.####');

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentRate.toStringAsFixed(4));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.currency;
    final isCustom = (widget.currentRate - widget.globalRate).abs() > 0.001;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(bottom: BorderSide(color: Color(0xFF1E3040))),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: Row(children: [
          Text(c.symbol, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(c.label.split('(').first.trim(),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(flex: 1, child: Text(c.code,
            style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600))),
        Expanded(flex: 2, child: _editing
            ? TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  prefixText: '₩ ',
                ),
              )
            : Row(children: [
                Text('₩ ${fmt.format(widget.currentRate)}',
                    style: TextStyle(
                      color: isCustom ? AppTheme.warning : AppTheme.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w500,
                    )),
                if (isCustom) ...[
                  const SizedBox(width: 4),
                  const Text('경영', style: TextStyle(color: AppTheme.warning, fontSize: 9)),
                ],
              ])),
        Expanded(flex: 2, child: Text('글로벌: ₩${fmt.format(widget.globalRate)}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
        SizedBox(width: 100, child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: _editing
              ? [
                  GestureDetector(
                    onTap: () {
                      final v = double.tryParse(_ctrl.text.replaceAll(',', ''));
                      if (v != null && v > 0) widget.onSave(v);
                      setState(() => _editing = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('저장', style: TextStyle(color: AppTheme.success, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _editing = false),
                    child: const Icon(Icons.close, color: AppTheme.textMuted, size: 16),
                  ),
                ]
              : [
                  GestureDetector(
                    onTap: () => setState(() => _editing = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('수정', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ),
                  ),
                  if (isCustom) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => widget.onSave(widget.globalRate),
                      child: const Tooltip(
                        message: '글로벌값으로 초기화',
                        child: Icon(Icons.refresh, color: AppTheme.textMuted, size: 14),
                      ),
                    ),
                  ],
                ],
        )),
      ]),
    );
  }
}
