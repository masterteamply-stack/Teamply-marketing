import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class GeoAnalysisPage extends StatefulWidget {
  const GeoAnalysisPage({super.key});

  @override
  State<GeoAnalysisPage> createState() => _GeoAnalysisPageState();
}

class _GeoAnalysisPageState extends State<GeoAnalysisPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###');

    // 전체 비용 KRW 합산
    final allCosts = provider.allCostEntries;
    final totalKrw = allCosts.fold(
        0.0, (s, e) => s + provider.getAmountInKrwForEntry(e.entry, e.projectId));

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          // ── 상단 헤더 ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            color: AppTheme.bgDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.public, color: AppTheme.accentPurple, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('마케팅 비용 지역 분석',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text('권역 · 국가 · 고객사별 마케팅 투자 현황',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 요약 카드
                _SummaryCards(
                  totalKrw: totalKrw,
                  regionCount: provider.costByRegion.length,
                  clientCount: provider.clients.where((c) => c.isActive).length,
                  fmt: fmt,
                  provider: provider,
                ),
                const SizedBox(height: 16),
                // 탭바
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.accentPurple,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: AppTheme.accentPurple,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(icon: Icon(Icons.map_outlined, size: 16), text: '권역별'),
                    Tab(icon: Icon(Icons.flag_outlined, size: 16), text: '국가별'),
                    Tab(icon: Icon(Icons.business_center_outlined, size: 16), text: '고객사별'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // ── 탭 콘텐츠 ───────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RegionTab(provider: provider, totalKrw: totalKrw),
                _CountryTab(provider: provider, totalKrw: totalKrw),
                _ClientTab(provider: provider, totalKrw: totalKrw),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  요약 카드
// ═══════════════════════════════════════════════════════════
class _SummaryCards extends StatelessWidget {
  final double totalKrw;
  final int regionCount;
  final int clientCount;
  final NumberFormat fmt;
  final AppProvider provider;
  const _SummaryCards({
    required this.totalKrw,
    required this.regionCount,
    required this.clientCount,
    required this.fmt,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final assignedKrw = provider.allCostEntries
        .where((e) => e.entry.region != null)
        .fold(0.0, (s, e) => s + provider.getAmountInKrwForEntry(e.entry, e.projectId));
    final assignedPct = totalKrw > 0 ? (assignedKrw / totalKrw * 100) : 0.0;

    return Row(
      children: [
        Expanded(child: _StatCard(
          label: '전체 마케팅 비용',
          value: '₩${fmt.format(totalKrw)}',
          icon: Icons.account_balance_wallet,
          color: AppTheme.accentPurple,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: '권역 할당 비용',
          value: '₩${fmt.format(assignedKrw)}',
          sub: '${assignedPct.toStringAsFixed(1)}% 할당됨',
          icon: Icons.public,
          color: AppTheme.accentBlue,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: '활성 권역 수',
          value: '$regionCount개 권역',
          sub: '${provider.costByCountry.length}개 국가',
          icon: Icons.map_outlined,
          color: AppTheme.accentGreen,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: '활성 고객사',
          value: '$clientCount개사',
          icon: Icons.business_center,
          color: AppTheme.accentOrange,
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: color, fontSize: 14, fontWeight: FontWeight.w700)),
                if (sub != null)
                  Text(sub!,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  권역별 탭
// ═══════════════════════════════════════════════════════════
class _RegionTab extends StatelessWidget {
  final AppProvider provider;
  final double totalKrw;
  const _RegionTab({required this.provider, required this.totalKrw});

  @override
  Widget build(BuildContext context) {
    final costMap = provider.costByRegion;
    final sorted = costMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return _EmptyState(
        message: '아직 권역이 할당된 비용 항목이 없습니다.\n태스크 비용 추가 시 권역을 지정해 보세요.',
        icon: Icons.map_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final entry = sorted[i];
        final region = provider.regions.where((r) => r.name == entry.key).firstOrNull;
        final pct = totalKrw > 0 ? entry.value / totalKrw * 100 : 0.0;
        final color = region != null
            ? _hexColor(region.colorHex)
            : AppTheme.textMuted;

        // 해당 권역의 나라별 세부 분류
        final subCosts = <String, double>{};
        for (final cm in provider.allCostEntries) {
          if (cm.entry.region == entry.key) {
            final k = cm.entry.country ?? '기타';
            subCosts[k] = (subCosts[k] ?? 0) + provider.getAmountInKrwForEntry(cm.entry, cm.projectId);
          }
        }
        final subSorted = subCosts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return _RegionCard(
          region: region,
          name: entry.key,
          costKrw: entry.value,
          totalKrw: totalKrw,
          pct: pct,
          color: color,
          subCountries: subSorted,
        );
      },
    );
  }
}

class _RegionCard extends StatefulWidget {
  final MarketingRegion? region;
  final String name;
  final double costKrw;
  final double totalKrw;
  final double pct;
  final Color color;
  final List<MapEntry<String, double>> subCountries;
  const _RegionCard({
    required this.region,
    required this.name,
    required this.costKrw,
    required this.totalKrw,
    required this.pct,
    required this.color,
    required this.subCountries,
  });

  @override
  State<_RegionCard> createState() => _RegionCardState();
}

class _RegionCardState extends State<_RegionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // 헤더
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.region != null)
                    Text(widget.region!.icon, style: const TextStyle(fontSize: 22))
                  else
                    Icon(Icons.public, color: widget.color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        if (widget.region?.countries.isNotEmpty == true)
                          Text(widget.region!.countries.join(' · '),
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₩${fmt.format(widget.costKrw)}',
                          style: TextStyle(
                              color: widget.color,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text('전체의 ${widget.pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          // 진행 바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.pct / 100,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                minHeight: 6,
              ),
            ),
          ),
          // 확장: 나라별 세부
          if (_expanded && widget.subCountries.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('국가별 분포',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...widget.subCountries.map((e) {
                    final pct = widget.costKrw > 0 ? e.value / widget.costKrw * 100 : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(e.key,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                backgroundColor: AppTheme.border,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.color.withValues(alpha: 0.7)),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: Text('₩${fmt.format(e.value)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 10)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  국가별 탭
// ═══════════════════════════════════════════════════════════
class _CountryTab extends StatelessWidget {
  final AppProvider provider;
  final double totalKrw;
  const _CountryTab({required this.provider, required this.totalKrw});

  @override
  Widget build(BuildContext context) {
    final costMap = provider.costByCountry;
    final sorted = costMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty || (sorted.length == 1 && sorted[0].key == '미분류')) {
      return _EmptyState(
        message: '아직 국가가 할당된 비용 항목이 없습니다.',
        icon: Icons.flag_outlined,
      );
    }

    final fmt = NumberFormat('#,###');
    final maxCost = sorted.isNotEmpty ? sorted.first.value : 1.0;

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final e = sorted[i];
        final pct = totalKrw > 0 ? e.value / totalKrw * 100 : 0.0;
        final barPct = maxCost > 0 ? e.value / maxCost : 0.0;
        // 해당 국가의 권역 찾기
        final region = provider.regions
            .where((r) => r.countries.contains(e.key))
            .firstOrNull;
        final color = region != null
            ? _hexColor(region.colorHex)
            : AppTheme.accentPurple;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  children: [
                    Text('${i + 1}',
                        style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(e.key,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        if (region != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${region.icon} ${region.name}',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: barPct,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₩${fmt.format(e.value)}',
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  고객사별 탭
// ═══════════════════════════════════════════════════════════
class _ClientTab extends StatelessWidget {
  final AppProvider provider;
  final double totalKrw;
  const _ClientTab({required this.provider, required this.totalKrw});

  @override
  Widget build(BuildContext context) {
    final activeClients = provider.clients.where((c) => c.isActive).toList();
    // 비용 기준으로 정렬
    activeClients.sort((a, b) =>
        provider.clientTotalCost(b.id).compareTo(provider.clientTotalCost(a.id)));

    if (activeClients.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('등록된 고객사가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('"마케팅 비용 분석" → "권역·고객 설정" 탭에서 추가하세요',
              style: TextStyle(color: AppTheme.textDisabled, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // 마케팅 비용 분석 탭으로 이동 안내
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('상단 메뉴 > 마케팅 비용 분석 > 권역·고객 설정에서 고객사를 추가하세요'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('고객사 관리로 이동'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    }

    return Column(children: [
      // 툴바
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('총 ${activeClients.length}개 고객사',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: activeClients.length,
          itemBuilder: (context, i) {
            final client = activeClients[i];
            return _ClientCard(
              client: client,
              totalKrw: totalKrw,
              provider: provider,
            );
          },
        ),
      ),
    ]);
  }
}

class _ClientCard extends StatefulWidget {
  final ClientAccount client;
  final double totalKrw;
  final AppProvider provider;
  const _ClientCard({
    required this.client,
    required this.totalKrw,
    required this.provider,
  });

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final clientCost = widget.provider.clientTotalCost(widget.client.id);
    final roi = widget.provider.clientRoi(widget.client.id);
    final pct = widget.totalKrw > 0 ? clientCost / widget.totalKrw * 100 : 0.0;
    final revenue = widget.client.revenue;

    // 해당 고객 비용 항목
    final entries = widget.provider.allCostEntries
        .where((e) => e.entry.clientId == widget.client.id)
        .toList();

    // 카테고리별 집계
    final catMap = <String, double>{};
    for (final cm in entries) {
      final k = cm.entry.category;
      catMap[k] = (catMap[k] ?? 0) + widget.provider.getAmountInKrwForEntry(cm.entry, cm.projectId);
    }
    final catSorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final roiColor = roi > 0 ? AppTheme.accentGreen : AppTheme.accentRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 아바타
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            widget.client.name.substring(0, 1),
                            style: const TextStyle(
                                color: AppTheme.accentPurple,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.client.name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Row(
                              children: [
                                if (widget.client.country != null) ...[
                                  const Icon(Icons.flag, size: 11,
                                      color: AppTheme.textMuted),
                                  const SizedBox(width: 3),
                                  Text(widget.client.country!,
                                      style: const TextStyle(
                                          color: AppTheme.textMuted, fontSize: 11)),
                                  const SizedBox(width: 8),
                                ],
                                if (widget.client.region != null) ...[
                                  const Icon(Icons.public, size: 11,
                                      color: AppTheme.textMuted),
                                  const SizedBox(width: 3),
                                  Text(widget.client.region!,
                                      style: const TextStyle(
                                          color: AppTheme.textMuted, fontSize: 11)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 비용/매출/ROI 메트릭
                  Row(
                    children: [
                      Expanded(child: _MetricTile(
                        label: '투자 비용',
                        value: '₩${fmt.format(clientCost)}',
                        sub: '전체의 ${pct.toStringAsFixed(1)}%',
                        color: AppTheme.accentBlue,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _MetricTile(
                        label: '발생 매출',
                        value: '₩${fmt.format(revenue)}',
                        color: AppTheme.accentGreen,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _MetricTile(
                        label: '고객 ROI',
                        value: '${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(1)}%',
                        color: roiColor,
                        isHighlighted: true,
                      )),
                    ],
                  ),
                  if (clientCost > 0) ...[
                    const SizedBox(height: 10),
                    // 전체 대비 비율 바
                    Row(
                      children: [
                        const Text('전체 비용 비율:',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 10)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: AppTheme.border,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.accentPurple),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: AppTheme.accentPurple,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 확장: 비용 항목 세부 & 카테고리
          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리별 분포
                  if (catSorted.isNotEmpty) ...[
                    const Text('카테고리별 비용',
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...catSorted.map((cat) {
                      final catPct = clientCost > 0 ? cat.value / clientCost * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(cat.key,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 11)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: catPct / 100,
                                  backgroundColor: AppTheme.border,
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppTheme.accentPurple),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '₩${fmt.format(cat.value)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 16, color: AppTheme.border),
                  ],
                  // 비용 항목 목록
                  const Text('비용 항목',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Text('비용 항목 없음',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11))
                  else
                    ...entries.map((cm) {
                      final amtKrw = widget.provider
                          .getAmountInKrwForEntry(cm.entry, cm.projectId);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.bgDark,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: cm.entry.isExecuted
                                    ? AppTheme.accentGreen
                                    : AppTheme.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cm.entry.title,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 12)),
                                  Text(
                                    '${cm.projectName} · ${cm.entry.category} · ${DateFormat('yyyy.MM.dd').format(cm.entry.date)}',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${cm.entry.currency.symbol}${fmt.format(cm.entry.amount)}',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (cm.entry.currency != CurrencyCode.krw)
                                  Text('₩${fmt.format(amtKrw)}',
                                      style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 보조 위젯 ──────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final bool isHighlighted;
  const _MetricTile({
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.1)
            : AppTheme.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? color.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w700)),
          if (sub != null)
            Text(sub!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppTheme.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// hex 컬러 파싱
Color _hexColor(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return AppTheme.accentPurple;
  }
}
