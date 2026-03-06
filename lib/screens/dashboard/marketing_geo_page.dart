import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class MarketingGeoPage extends StatefulWidget {
  const MarketingGeoPage({super.key});
  @override
  State<MarketingGeoPage> createState() => _MarketingGeoPageState();
}

class _MarketingGeoPageState extends State<MarketingGeoPage> with SingleTickerProviderStateMixin {
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 28, isMobile ? 14 : 24, isMobile ? 16 : 28, 0),
              color: AppTheme.bgCard,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isMobile)
                  const Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('지역/권역별 마케팅 비용 분석', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('권역 · 나라 · 고객사별 마케팅 투자 현황 및 성과 분석',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ])),
                  ]),
                if (!isMobile) const SizedBox(height: 16),
                TabBar(
                  controller: _tab,
                  labelColor: AppTheme.mintPrimary,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: AppTheme.mintPrimary,
                  tabs: const [
                    Tab(text: '권역별 분석'),
                    Tab(text: '고객사별 분석'),
                    Tab(text: '권역·고객 설정'),
                  ],
                ),
              ]),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  _RegionAnalysisTab(),
                  _ClientAnalysisTab(),
                  _GeoSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 권역별 분석 탭
// ══════════════════════════════════════════════════════════
class _RegionAnalysisTab extends StatelessWidget {
  const _RegionAnalysisTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###');
    final costByRegion = p.costByRegion;
    final costByCountry = p.costByCountry;
    final totalCost = costByRegion.values.fold(0.0, (s, v) => s + v);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final regionsSorted = costByRegion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final countriesSorted = costByCountry.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 권역 색상 매핑
    final regionColors = _buildRegionColorMap(p.regions);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // 총 비용 요약
        Row(children: [
          _SummaryCard(
            label: '전체 마케팅 비용',
            value: '₩${_short(totalCost)}',
            sub: '${fmt.format(totalCost)}원',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.mintPrimary,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: '권역 수',
            value: '${regionsSorted.where((e) => e.key != "미분류").length}개',
            sub: '미분류 포함 ${regionsSorted.length}개',
            icon: Icons.public,
            color: AppTheme.info,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: '나라 수',
            value: '${countriesSorted.where((e) => e.key != "미분류").length}개국',
            sub: '비용 집행 기준',
            icon: Icons.flag_outlined,
            color: AppTheme.warning,
          ),
        ]),
        const SizedBox(height: 24),

        if (!isMobile)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 권역별 차트
            Expanded(child: _RegionBarSection(
              title: '권역별 마케팅 비용',
              data: regionsSorted,
              total: totalCost,
              colorMap: regionColors,
              fmt: fmt,
            )),
            const SizedBox(width: 16),
            // 나라별 차트
            Expanded(child: _RegionBarSection(
              title: '나라별 마케팅 비용 (Top 10)',
              data: countriesSorted.take(10).toList(),
              total: totalCost,
              colorMap: const {},
              fmt: fmt,
            )),
          ])
        else ...[
          _RegionBarSection(
            title: '권역별 마케팅 비용',
            data: regionsSorted,
            total: totalCost,
            colorMap: regionColors,
            fmt: fmt,
          ),
          const SizedBox(height: 16),
          _RegionBarSection(
            title: '나라별 마케팅 비용 (Top 10)',
            data: countriesSorted.take(10).toList(),
            total: totalCost,
            colorMap: const {},
            fmt: fmt,
          ),
        ],
        const SizedBox(height: 20),

        // 권역별 상세 테이블
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E3040)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text('권역별 상세 현황', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            if (!isMobile)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(flex: 2, child: Text('권역', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                  Expanded(flex: 2, child: Text('투자 비용', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                  Expanded(flex: 1, child: Text('비중', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                  Expanded(flex: 3, child: Text('비용 분포', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                ]),
              ),
            const Divider(color: Color(0xFF1E3040), height: 16),
            ...regionsSorted.map((e) {
              final pct = totalCost > 0 ? e.value / totalCost : 0.0;
              final color = regionColors[e.key] ?? AppTheme.textMuted;
              return _RegionTableRow(
                regionName: e.key,
                cost: e.value,
                pct: pct,
                color: color,
                fmt: fmt,
                isMobile: isMobile,
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Map<String, Color> _buildRegionColorMap(List<MarketingRegion> regions) {
    final colorStrs = ['00BFA5', '29B6F6', 'FFB300', 'AB47BC', 'FF7043', 'EF5350', '66BB6A', '7E57C2'];
    final map = <String, Color>{};
    for (int i = 0; i < regions.length; i++) {
      try {
        map[regions[i].name] = Color(int.parse('0xFF${regions[i].colorHex.replaceAll("#", "")}'));
      } catch (_) {
        map[regions[i].name] = Color(int.parse('0xFF${colorStrs[i % colorStrs.length]}'));
      }
    }
    return map;
  }
}

class _RegionBarSection extends StatelessWidget {
  final String title;
  final List<MapEntry<String, double>> data;
  final double total;
  final Map<String, Color> colorMap;
  final NumberFormat fmt;

  const _RegionBarSection({
    required this.title, required this.data,
    required this.total, required this.colorMap, required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3040)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (data.isEmpty)
          const Center(child: Text('데이터 없음', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)))
        else
          ...data.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            final color = colorMap[e.key] ?? AppTheme.mintPrimary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('₩${fmt.format(e.value)}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text('${(pct * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right),
                  ),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppTheme.bgCardLight,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

class _RegionTableRow extends StatelessWidget {
  final String regionName;
  final double cost;
  final double pct;
  final Color color;
  final NumberFormat fmt;
  final bool isMobile;

  const _RegionTableRow({
    required this.regionName, required this.cost,
    required this.pct, required this.color,
    required this.fmt, required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(regionName, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Text('₩${fmt.format(cost)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                const Spacer(),
                Text('${(pct * 100).toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct, backgroundColor: AppTheme.bgCardLight,
                  valueColor: AlwaysStoppedAnimation(color), minHeight: 4,
                ),
              ),
            ])
          : Row(children: [
              Expanded(flex: 2, child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(regionName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              ])),
              Expanded(flex: 2, child: Text('₩${fmt.format(cost)}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('${(pct * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, backgroundColor: AppTheme.bgCardLight,
                  valueColor: AlwaysStoppedAnimation(color), minHeight: 6,
                ),
              )),
            ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 고객사별 분석 탭
// ══════════════════════════════════════════════════════════
class _ClientAnalysisTab extends StatefulWidget {
  const _ClientAnalysisTab();
  @override
  State<_ClientAnalysisTab> createState() => _ClientAnalysisTabState();
}

class _ClientAnalysisTabState extends State<_ClientAnalysisTab> {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final clients = p.activeClients;
    final fmt = NumberFormat('#,###');
    final isMobile = MediaQuery.of(context).size.width < 768;

    final totalCost = clients.fold(0.0, (s, c) => s + p.clientTotalCost(c.id));
    final totalRevenue = clients.fold(0.0, (s, c) => s + c.revenue);
    final totalRoi = totalCost > 0 ? (totalRevenue - totalCost) / totalCost * 100 : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 요약 카드
        Row(children: [
          _SummaryCard(label: '전체 고객사 투자', value: '₩${_short(totalCost)}', sub: '${fmt.format(totalCost)}원', icon: Icons.business_outlined, color: AppTheme.mintPrimary),
          const SizedBox(width: 12),
          _SummaryCard(label: '총 매출 기여', value: '₩${_short(totalRevenue)}', sub: '${fmt.format(totalRevenue)}원', icon: Icons.trending_up, color: AppTheme.success),
          const SizedBox(width: 12),
          _SummaryCard(label: '전체 ROI', value: '${totalRoi.toStringAsFixed(0)}%', sub: clients.isNotEmpty ? '${clients.length}개 고객사 기준' : '데이터 없음', icon: Icons.analytics_outlined, color: totalRoi >= 100 ? AppTheme.success : AppTheme.warning),
        ]),
        const SizedBox(height: 20),

        // 툴바: 고객사 추가 / CSV 일괄 업로드
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => _ClientBulkDialog(provider: p)),
            icon: const Icon(Icons.upload_file_rounded, size: 13, color: AppTheme.accentBlue),
            label: const Text('CSV 일괄 업로드', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => _ClientFullDialog(client: null, provider: p)),
            icon: const Icon(Icons.add_rounded, size: 14),
            label: const Text('고객사 추가', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // 고객사 카드 리스트
        if (clients.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.business_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('등록된 고객사가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => _ClientFullDialog(client: null, provider: p)),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('고객사 추가'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white),
                ),
              ]),
            ),
          )
        else ...[
          // 테이블 헤더
          if (!isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  left: BorderSide(color: Color(0xFF1E3040)),
                  right: BorderSide(color: Color(0xFF1E3040)),
                  top: BorderSide(color: Color(0xFF1E3040)),
                ),
              ),
              child: const Row(children: [
                Expanded(flex: 2, child: Text('바이어코드', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                Expanded(flex: 3, child: Text('고객사', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                Expanded(flex: 1, child: Text('권역', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                Expanded(flex: 1, child: Text('나라', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                Expanded(flex: 2, child: Text('투자 비용', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                Expanded(flex: 2, child: Text('발생 매출', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                Expanded(flex: 1, child: Text('ROI', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                Expanded(flex: 2, child: Text('비용 비중', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              ]),
            ),
          ...clients.map((c) {
            final cost = p.clientTotalCost(c.id);
            final roi = p.clientRoi(c.id);
            final pct = totalCost > 0 ? cost / totalCost : 0.0;
            return _ClientTableRow(
              client: c, cost: cost, roi: roi, pct: pct, fmt: fmt,
              isMobile: isMobile,
              onEdit: () => showDialog(context: context, builder: (_) => _ClientFullDialog(client: c, provider: p)),
            );
          }),
        ],
      ]),
    );
  }

}

// ── _ClientAnalysisTab 에서 쓰는 단순 분석용 편집 헬퍼 (deprecated → _ClientFullDialog 사용으로 제거)

class _ClientTableRow extends StatelessWidget {
  final ClientAccount client;
  final double cost, roi, pct;
  final NumberFormat fmt;
  final bool isMobile;
  final VoidCallback onEdit;

  const _ClientTableRow({
    required this.client, required this.cost, required this.roi,
    required this.pct, required this.fmt, required this.isMobile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final roiColor = roi >= 200 ? AppTheme.success : roi >= 100 ? AppTheme.mintPrimary : roi >= 0 ? AppTheme.warning : AppTheme.error;

    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E3040)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(client.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
            GestureDetector(onTap: onEdit, child: const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 16)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            if (client.region != null) _Chip(client.region!, AppTheme.info),
            const SizedBox(width: 6),
            if (client.country != null) _Chip(client.country!, AppTheme.textMuted),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('투자 비용', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('₩${fmt.format(cost)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('발생 매출', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('₩${fmt.format(client.revenue)}', style: const TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('ROI', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('${roi.toStringAsFixed(0)}%', style: TextStyle(color: roiColor, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct, backgroundColor: AppTheme.bgCardLight,
              valueColor: const AlwaysStoppedAnimation(AppTheme.mintPrimary), minHeight: 4,
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E3040)),
          left: BorderSide(color: Color(0xFF1E3040)),
          right: BorderSide(color: Color(0xFF1E3040)),
        ),
      ),
      child: Row(children: [
        // 바이어코드
        Expanded(flex: 2, child: client.buyerCode != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                ),
                child: Text(client.buyerCode!, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 10, fontWeight: FontWeight.w600)),
              )
            : const Text('—', style: TextStyle(color: AppTheme.textDisabled, fontSize: 11))),
        Expanded(flex: 3, child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(client.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            if (client.contactName != null)
              Text(client.contactName!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
          const SizedBox(width: 8),
          GestureDetector(onTap: onEdit, child: const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 14)),
        ])),
        Expanded(flex: 1, child: client.region != null
            ? _Chip(client.region!, AppTheme.info) : const SizedBox.shrink()),
        Expanded(flex: 1, child: Text(client.country ?? '-',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        Expanded(flex: 2, child: Text('₩${fmt.format(cost)}',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(flex: 2, child: Text('₩${fmt.format(client.revenue)}',
            style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(flex: 1, child: Text('${roi.toStringAsFixed(0)}%',
            style: TextStyle(color: roiColor, fontSize: 13, fontWeight: FontWeight.w700))),
        Expanded(flex: 2, child: Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct, backgroundColor: AppTheme.bgCardLight,
              valueColor: const AlwaysStoppedAnimation(AppTheme.mintPrimary), minHeight: 5,
            ),
          )),
          const SizedBox(width: 6),
          Text('${(pct * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 권역·고객 설정 탭 (완전 재구성)
// ══════════════════════════════════════════════════════════
class _GeoSettingsTab extends StatefulWidget {
  const _GeoSettingsTab();
  @override
  State<_GeoSettingsTab> createState() => _GeoSettingsTabState();
}

class _GeoSettingsTabState extends State<_GeoSettingsTab> with SingleTickerProviderStateMixin {
  late TabController _innerTab;
  String _clientSearch = '';
  String? _clientRegionFilter;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(children: [
      // ── 이너 탭 바 ──
      Container(
        color: AppTheme.bgCard,
        child: TabBar(
          controller: _innerTab,
          labelColor: AppTheme.accentBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.accentBlue,
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded, size: 16), text: '고객사 관리'),
            Tab(icon: Icon(Icons.map_rounded, size: 16), text: '권역 관리'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _innerTab,
          children: [
            // ════ 고객사 관리 탭 ════
            _buildClientTab(context, p, isMobile),
            // ════ 권역 관리 탭 ════
            _buildRegionTab(context, p, isMobile),
          ],
        ),
      ),
    ]);
  }

  // ── 고객사 관리 탭 빌드 ─────────────────────────────────
  Widget _buildClientTab(BuildContext context, AppProvider p, bool isMobile) {
    final fmt = NumberFormat('#,###');

    // 필터 적용
    var clients = p.clients.where((c) {
      if (!_showInactive && !c.isActive) return false;
      if (_clientRegionFilter != null && c.region != _clientRegionFilter) return false;
      if (_clientSearch.isNotEmpty) {
        final q = _clientSearch.toLowerCase();
        return c.name.toLowerCase().contains(q) ||
            (c.buyerCode ?? '').toLowerCase().contains(q) ||
            (c.country ?? '').toLowerCase().contains(q) ||
            (c.region ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // 통계
    final total     = p.clients.length;
    final active    = p.clients.where((c) => c.isActive).length;
    final totalRev  = p.clients.fold(0.0, (s, c) => s + c.revenue);
    final totalCost = p.clients.fold(0.0, (s, c) => s + p.clientTotalCost(c.id));

    return Column(children: [
      // ── 툴바 ──
      Container(
        color: AppTheme.bgCard,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(children: [
          // 통계 바
          Row(children: [
            _statBadge('전체', '$total', AppTheme.textSecondary),
            const SizedBox(width: 12),
            _statBadge('활성', '$active', AppTheme.success),
            const SizedBox(width: 12),
            _statBadge('총매출', '₩${_short(totalRev)}', AppTheme.mintPrimary),
            const SizedBox(width: 12),
            _statBadge('광고비', '₩${_short(totalCost)}', AppTheme.warning),
            const Spacer(),
            // 버튼들
            TextButton.icon(
              onPressed: () => _showBulkUploadDialog(context, p),
              icon: const Icon(Icons.upload_file_rounded, size: 14, color: AppTheme.accentBlue),
              label: const Text('CSV 일괄 업로드', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showClientDialog(context, p, null),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('고객사 추가', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // 검색 + 필터
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                onChanged: (v) => setState(() => _clientSearch = v),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '고객사명, 바이어코드, 국가, 권역 검색...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 16),
                  hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  filled: true, fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _clientRegionFilter,
                    hint: const Text('전체 권역', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
                    isExpanded: true,
                    dropdownColor: AppTheme.bgCard,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('전체 권역', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                      ...p.regions.map((r) => DropdownMenuItem<String>(
                        value: r.name,
                        child: Row(children: [Text(r.icon), const SizedBox(width: 6), Text(r.name)]),
                      )),
                    ],
                    onChanged: (v) => setState(() => _clientRegionFilter = v),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(children: [
              Switch(
                value: _showInactive,
                onChanged: (v) => setState(() => _showInactive = v),
                activeColor: AppTheme.mintPrimary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text('비활성 포함', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ]),
        ]),
      ),
      // ── 테이블 헤더 ──
      Container(
        color: AppTheme.bgCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _th('바이어코드', flex: 2),
          _th('고객사명',   flex: 3),
          _th('권역',     flex: 2),
          _th('국가',     flex: 1),
          _th('업종',     flex: 2),
          _th('광고비',   flex: 2, align: TextAlign.right),
          _th('매출',     flex: 2, align: TextAlign.right),
          _th('ROI',     flex: 1, align: TextAlign.right),
          _th('상태',    flex: 1, align: TextAlign.center),
          _th('',        flex: 1),
        ]),
      ),
      const Divider(height: 1, color: AppTheme.border),
      // ── 목록 ──
      Expanded(
        child: clients.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.business_outlined, size: 40, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                const Text('등록된 고객사가 없습니다', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('CSV 업로드 또는 개별 추가 버튼을 이용하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]))
            : ListView.separated(
                itemCount: clients.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                itemBuilder: (_, i) {
                  final c = clients[i];
                  final cost = p.clientTotalCost(c.id);
                  final roi  = p.clientRoi(c.id);
                  return _ClientListRow(
                    client: c,
                    cost: cost,
                    roi: roi,
                    fmt: fmt,
                    onEdit:   () => _showClientDialog(context, p, c),
                    onDelete: () => _confirmDelete(context, p, c),
                    onToggle: () => p.updateClient(c.copyWith(isActive: !c.isActive)),
                  );
                },
              ),
      ),
    ]);
  }

  // ── 권역 관리 탭 빌드 ────────────────────────────────────
  Widget _buildRegionTab(BuildContext context, AppProvider p, bool isMobile) {
    return Column(children: [
      Container(
        color: AppTheme.bgCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Text('총 ${p.regions.length}개 권역',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showRegionBulkDialog(context, p),
            icon: const Icon(Icons.upload_file_rounded, size: 14, color: AppTheme.accentBlue),
            label: const Text('CSV 업로드', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showRegionDialog(context, p, null),
            icon: const Icon(Icons.add_rounded, size: 14),
            label: const Text('권역 추가', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: AppTheme.border),
      Expanded(
        child: p.regions.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.map_outlined, size: 40, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                const Text('등록된 권역이 없습니다', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: () => _showRegionDialog(context, p, null),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('권역 추가'),
                ),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: p.regions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = p.regions[i];
                  final clientCount = p.clients.where((c) => c.region == r.name).length;
                  return _RegionChipCard(
                    region: r,
                    clientCount: clientCount,
                    onEdit:   () => _showRegionDialog(context, p, r),
                    onDelete: () { if (mounted) p.deleteRegion(r.id); },
                  );
                },
              ),
      ),
    ]);
  }

  // ── 헬퍼 위젯 ───────────────────────────────────────────
  Widget _statBadge(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppTheme.textDisabled, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ],
  );

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) => Expanded(
    flex: flex,
    child: Text(label, textAlign: align,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
  );

  // ── 다이얼로그들 ─────────────────────────────────────────
  void _showClientDialog(BuildContext ctx, AppProvider p, ClientAccount? client) {
    showDialog(
      context: ctx,
      builder: (_) => _ClientFullDialog(client: client, provider: p),
    );
  }

  void _showBulkUploadDialog(BuildContext ctx, AppProvider p) {
    showDialog(
      context: ctx,
      builder: (_) => _ClientBulkDialog(provider: p),
    );
  }

  void _showRegionDialog(BuildContext ctx, AppProvider p, MarketingRegion? region) {
    showDialog(
      context: ctx,
      builder: (_) => _RegionDialog(region: region, provider: p),
    );
  }

  void _showRegionBulkDialog(BuildContext ctx, AppProvider p) {
    showDialog(
      context: ctx,
      builder: (_) => _RegionBulkDialog(provider: p),
    );
  }

  void _confirmDelete(BuildContext ctx, AppProvider p, ClientAccount c) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
        title: const Text('고객사 삭제', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('「${c.name}」를 삭제하시겠습니까?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () { p.deleteClient(c.id); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 고객사 리스트 행
// ══════════════════════════════════════════════════════════
class _ClientListRow extends StatelessWidget {
  final ClientAccount client;
  final double cost, roi;
  final NumberFormat fmt;
  final VoidCallback onEdit, onDelete, onToggle;
  const _ClientListRow({
    required this.client, required this.cost, required this.roi,
    required this.fmt, required this.onEdit, required this.onDelete, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final roiColor = roi >= 100 ? AppTheme.success : roi >= 0 ? AppTheme.warning : AppTheme.error;
    return InkWell(
      onTap: onEdit,
      hoverColor: AppTheme.mintPrimary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // 바이어코드
          Expanded(flex: 2, child: client.buyerCode != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                  ),
                  child: Text(client.buyerCode!, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                )
              : const Text('—', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12))),
          // 고객사명
          Expanded(flex: 3, child: Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(
              color: client.isActive ? AppTheme.success : AppTheme.textDisabled, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Expanded(child: Text(client.name,
                style: TextStyle(color: client.isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ])),
          // 권역
          Expanded(flex: 2, child: client.region != null
              ? _Chip(client.region!, AppTheme.accentBlue)
              : const Text('—', style: TextStyle(color: AppTheme.textDisabled, fontSize: 11))),
          // 국가
          Expanded(flex: 1, child: Text(client.country ?? '—',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          // 업종
          Expanded(flex: 2, child: Text(client.industry ?? '—',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
          // 광고비
          Expanded(flex: 2, child: Text(
              cost > 0 ? '₩${fmt.format(cost)}' : '—',
              textAlign: TextAlign.right,
              style: TextStyle(color: cost > 0 ? AppTheme.accentOrange : AppTheme.textDisabled, fontSize: 12, fontWeight: FontWeight.w600))),
          // 매출
          Expanded(flex: 2, child: Text(
              client.revenue > 0 ? '₩${fmt.format(client.revenue)}' : '—',
              textAlign: TextAlign.right,
              style: TextStyle(color: client.revenue > 0 ? AppTheme.mintPrimary : AppTheme.textDisabled, fontSize: 12, fontWeight: FontWeight.w600))),
          // ROI
          Expanded(flex: 1, child: Text(
              cost > 0 ? '${roi.toStringAsFixed(0)}%' : '—',
              textAlign: TextAlign.right,
              style: TextStyle(color: roiColor, fontSize: 12, fontWeight: FontWeight.w700))),
          // 상태 스위치
          Expanded(flex: 1, child: Center(
            child: Switch(value: client.isActive, onChanged: (_) => onToggle(),
                activeColor: AppTheme.mintPrimary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          )),
          // 액션
          Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.textMuted),
              onPressed: onEdit, tooltip: '편집',
              constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28), padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.error),
              onPressed: onDelete, tooltip: '삭제',
              constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28), padding: EdgeInsets.zero,
            ),
          ])),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 고객사 추가/편집 다이얼로그 (풀 버전)
// ══════════════════════════════════════════════════════════
class _ClientFullDialog extends StatefulWidget {
  final ClientAccount? client;
  final AppProvider provider;
  const _ClientFullDialog({required this.client, required this.provider});

  @override
  State<_ClientFullDialog> createState() => _ClientFullDialogState();
}

class _ClientFullDialogState extends State<_ClientFullDialog> {
  late TextEditingController _nameCtrl, _buyerCodeCtrl, _countryCtrl, _industryCtrl;
  late TextEditingController _contactCtrl, _emailCtrl, _phoneCtrl;
  late TextEditingController _revenueCtrl, _adSpendCtrl, _noteCtrl;
  String? _selectedRegion;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameCtrl      = TextEditingController(text: c?.name ?? '');
    _buyerCodeCtrl = TextEditingController(text: c?.buyerCode ?? '');
    _countryCtrl   = TextEditingController(text: c?.country ?? '');
    _industryCtrl  = TextEditingController(text: c?.industry ?? '');
    _contactCtrl   = TextEditingController(text: c?.contactName ?? '');
    _emailCtrl     = TextEditingController(text: c?.contactEmail ?? '');
    _phoneCtrl     = TextEditingController(text: c?.contactPhone ?? '');
    _revenueCtrl   = TextEditingController(text: c != null && c.revenue > 0 ? c.revenue.toStringAsFixed(0) : '');
    _adSpendCtrl   = TextEditingController(text: c != null && c.adSpend > 0 ? c.adSpend.toStringAsFixed(0) : '');
    _noteCtrl      = TextEditingController(text: c?.note ?? '');
    _selectedRegion = c?.region;
    _isActive       = c?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _buyerCodeCtrl, _countryCtrl, _industryCtrl,
      _contactCtrl, _emailCtrl, _phoneCtrl, _revenueCtrl, _adSpendCtrl, _noteCtrl]) { c.dispose(); }
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final now = DateTime.now();
    final updated = ClientAccount(
      id: widget.client?.id ?? 'c_${now.millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      buyerCode: _buyerCodeCtrl.text.trim().isEmpty ? null : _buyerCodeCtrl.text.trim(),
      country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim().toUpperCase(),
      region: _selectedRegion,
      industry: _industryCtrl.text.trim().isEmpty ? null : _industryCtrl.text.trim(),
      contactName: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      contactEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      contactPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      isActive: _isActive,
      revenue: double.tryParse(_revenueCtrl.text.replaceAll(',', '')) ?? 0,
      adSpend: double.tryParse(_adSpendCtrl.text.replaceAll(',', '')) ?? 0,
      createdAt: widget.client?.createdAt ?? now,
    );
    if (widget.client == null) {
      widget.provider.addClient(updated);
    } else {
      widget.provider.updateClient(updated);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.client == null;
    final regions = widget.provider.regions;

    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.business_rounded, color: AppTheme.accentBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Text(isNew ? '고객사 추가' : '고객사 편집',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 기본 정보
                _sec('기본 정보'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 3, child: _fld('고객사명 *', _nameCtrl, hint: '예: 베트남 파트너스')),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _fld('바이어 코드', _buyerCodeCtrl, hint: 'B-001')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 2, child: _regionDrop(regions)),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _fld('국가 코드', _countryCtrl, hint: 'KR, VN, AE…')),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _fld('업종', _industryCtrl, hint: '유통, 제조…')),
                ]),
                const SizedBox(height: 16),

                // 담당자
                _sec('담당자 정보'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _fld('담당자명', _contactCtrl, hint: '홍길동')),
                  const SizedBox(width: 10),
                  Expanded(child: _fld('이메일', _emailCtrl, hint: 'buyer@example.com')),
                  const SizedBox(width: 10),
                  Expanded(child: _fld('연락처', _phoneCtrl, hint: '+82-10-0000-0000')),
                ]),
                const SizedBox(height: 16),

                // 성과
                _sec('성과 데이터'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _fld('매출 (₩)', _revenueCtrl, hint: '0', isNumber: true, prefix: '₩')),
                  const SizedBox(width: 10),
                  Expanded(child: _fld('광고비 (₩)', _adSpendCtrl, hint: '0', isNumber: true, prefix: '₩')),
                ]),
                const SizedBox(height: 10),
                _fld('메모', _noteCtrl, hint: '추가 메모 (선택)', maxLines: 2),
                const SizedBox(height: 12),

                // 상태
                Row(children: [
                  Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v),
                      activeColor: AppTheme.mintPrimary),
                  const SizedBox(width: 8),
                  Text(_isActive ? '활성 고객사' : '비활성 고객사',
                      style: TextStyle(color: _isActive ? AppTheme.success : AppTheme.textMuted,
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted, side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 14),
                  label: Text(isNew ? '추가' : '저장'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
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

  Widget _sec(String t) => Row(children: [
    Container(width: 3, height: 13, decoration: BoxDecoration(color: AppTheme.mintPrimary, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
  ]);

  Widget _fld(String label, TextEditingController ctrl, {
    String? hint, int maxLines = 1, bool isNumber = false, String? prefix,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
    const SizedBox(height: 4),
    TextField(
      controller: ctrl, maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, prefixText: prefix != null ? '$prefix ' : null,
        hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
        prefixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        filled: true, fillColor: AppTheme.bgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
      ),
    ),
  ]);

  Widget _regionDrop(List<MarketingRegion> regions) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('권역', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Container(
        height: 40,
        decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: regions.any((r) => r.name == _selectedRegion) ? _selectedRegion : null,
            hint: const Text('권역 선택', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
            isExpanded: true, dropdownColor: AppTheme.bgCard,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('(없음)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
              ...regions.map((r) => DropdownMenuItem<String>(
                value: r.name,
                child: Row(children: [Text(r.icon), const SizedBox(width: 6), Text(r.name)]),
              )),
            ],
            onChanged: (v) => setState(() => _selectedRegion = v),
          ),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════
// 고객사 CSV 벌크 업로드 다이얼로그
// ══════════════════════════════════════════════════════════
class _ClientBulkDialog extends StatefulWidget {
  final AppProvider provider;
  const _ClientBulkDialog({required this.provider});
  @override
  State<_ClientBulkDialog> createState() => _ClientBulkDialogState();
}

class _ClientBulkDialogState extends State<_ClientBulkDialog> {
  final _ctrl = TextEditingController();
  List<ClientAccount> _parsed = [];
  String? _error;
  bool _ok = false;
  bool _skipDuplicates = true;

  static const _template =
    'buyerCode,name,region,country,industry,contactName,contactEmail,revenue,adSpend\n'
    'B-001,베트남 파트너스,동남아,VN,유통,Nguyen Van A,nguyen@vn.com,50000000,5000000\n'
    'B-002,두바이 트레이딩,중동,AE,제조,Ahmed Al-Rashid,ahmed@ae.com,80000000,8000000\n'
    'B-003,서울 리테일,국내,KR,리테일,김민준,min@kr.com,30000000,3000000\n'
    'B-004,US Startup Inc,북미,US,IT,John Smith,john@us.com,120000000,15000000';

  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) { setState(() { _error = 'CSV 데이터를 입력하세요'; _ok = false; }); return; }
    try {
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 2) throw '헤더 행과 데이터 행이 필요합니다';
      final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();

      int col(List<String> keys) {
        for (final k in keys) {
          final i = header.indexWhere((h) => h == k);
          if (i >= 0) return i;
        }
        return -1;
      }

      final nameIdx    = col(['name', '고객사명', '고객사']);
      if (nameIdx < 0) throw '필수 컬럼 "name"이 없습니다';

      final codeIdx    = col(['buyercode', 'buyer_code', '바이어코드', '코드']);
      final regionIdx  = col(['region', '권역']);
      final countryIdx = col(['country', '국가']);
      final industryIdx= col(['industry', '업종']);
      final contactIdx = col(['contactname', 'contact_name', '담당자명', '담당자']);
      final emailIdx   = col(['email', 'contactemail', '이메일']);
      final revenueIdx = col(['revenue', '매출']);
      final adIdx      = col(['adspend', 'ad_spend', '광고비']);

      final results = <ClientAccount>[];
      final existingNames = widget.provider.clients.map((c) => c.name.toLowerCase()).toSet();
      final existingCodes = widget.provider.clients.map((c) => c.buyerCode?.toLowerCase() ?? '').where((c) => c.isNotEmpty).toSet();

      for (int li = 1; li < lines.length; li++) {
        final cols = lines[li].split(',').map((c) => c.trim()).toList();
        if (cols.length <= nameIdx) continue;
        String g(int idx) => idx >= 0 && idx < cols.length ? cols[idx] : '';

        final name = g(nameIdx);
        final code = codeIdx >= 0 ? g(codeIdx) : '';
        if (name.isEmpty) continue;

        // 중복 체크
        if (_skipDuplicates) {
          if (existingNames.contains(name.toLowerCase())) continue;
          if (code.isNotEmpty && existingCodes.contains(code.toLowerCase())) continue;
        }

        results.add(ClientAccount(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}_${results.length}',
          name: name,
          buyerCode: code.isEmpty ? null : code,
          region: regionIdx >= 0 ? (g(regionIdx).isEmpty ? null : g(regionIdx)) : null,
          country: countryIdx >= 0 ? (g(countryIdx).isEmpty ? null : g(countryIdx).toUpperCase()) : null,
          industry: industryIdx >= 0 ? (g(industryIdx).isEmpty ? null : g(industryIdx)) : null,
          contactName: contactIdx >= 0 ? (g(contactIdx).isEmpty ? null : g(contactIdx)) : null,
          contactEmail: emailIdx >= 0 ? (g(emailIdx).isEmpty ? null : g(emailIdx)) : null,
          revenue: double.tryParse(g(revenueIdx).replaceAll(',', '')) ?? 0,
          adSpend: double.tryParse(g(adIdx).replaceAll(',', '')) ?? 0,
          createdAt: DateTime.now(),
        ));
      }
      setState(() { _parsed = results; _ok = true; _error = null; });
    } catch (e) {
      setState(() { _error = '파싱 오류: $e'; _ok = false; _parsed = []; });
    }
  }

  void _import() {
    int added = 0;
    for (final c in _parsed) {
      widget.provider.addClient(c);
      added++;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$added개 고객사가 추가되었습니다'),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 680),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              const Icon(Icons.upload_file_rounded, color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 10),
              const Text('고객사 CSV 일괄 업로드',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              // 중복 제외 옵션
              Row(children: [
                Checkbox(
                  value: _skipDuplicates, onChanged: (v) => setState(() => _skipDuplicates = v ?? true),
                  activeColor: AppTheme.mintPrimary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text('중복 제외', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  _ctrl.text = _template;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('템플릿이 입력되었습니다'), behavior: SnackBarBehavior.floating));
                },
                icon: const Icon(Icons.content_paste_rounded, size: 13),
                label: const Text('템플릿 불러오기', style: TextStyle(fontSize: 12)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 안내
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 13),
                      SizedBox(width: 6),
                      Text('CSV 컬럼 안내', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    const Text('필수: name\n선택: buyerCode, region, country, industry, contactName, contactEmail, revenue, adSpend',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.6)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(6)),
                      child: Text(_template, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontFamily: 'monospace')),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text('CSV 데이터 입력', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrl,
                  maxLines: 9,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '위 템플릿을 참고하여 CSV 데이터를 붙여넣으세요...',
                    hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 11),
                    filled: true, fillColor: AppTheme.bgSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 10),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 13),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12))),
                    ]),
                  ),
                if (_ok && _parsed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 13),
                    const SizedBox(width: 6),
                    Text('${_parsed.length}개 행 파싱 완료 (미리보기)',
                        style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _parsed.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                      itemBuilder: (_, i) {
                        final c = _parsed[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(children: [
                            if (c.buyerCode != null)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text(c.buyerCode!, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 10)),
                              ),
                            Expanded(child: Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                            Text(c.region ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            const SizedBox(width: 8),
                            Text(c.country ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ]),
                        );
                      },
                    ),
                  ),
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
                      child: const Text('파싱 확인', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _ok && _parsed.isNotEmpty ? _import : null,
                      icon: const Icon(Icons.upload_rounded, size: 14),
                      label: Text(_parsed.isNotEmpty ? '${_parsed.length}개 가져오기' : '가져오기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintPrimary,
                        disabledBackgroundColor: AppTheme.bgCardLight,
                        foregroundColor: Colors.white,
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

// ══════════════════════════════════════════════════════════
// 권역 추가/편집 다이얼로그
// ══════════════════════════════════════════════════════════
class _RegionDialog extends StatefulWidget {
  final MarketingRegion? region;
  final AppProvider provider;
  const _RegionDialog({required this.region, required this.provider});
  @override
  State<_RegionDialog> createState() => _RegionDialogState();
}

class _RegionDialogState extends State<_RegionDialog> {
  late TextEditingController _nameCtrl, _codeCtrl, _descCtrl, _countryCtrl;
  List<String> _countries = [];
  String _colorHex = '#00C9A7';
  String _icon = '🌍';

  static const _colorOpts = ['#00C9A7','#4DB8FF','#BD7FEB','#FF8C5A','#FFC93C','#6EE79C','#FF6B6B','#29B6F6','#AB47BC','#FF7043'];
  static const _iconOpts  = ['🌏','🌍','🌎','🌐','🗺️','🏔️','🏙️','⭐','🔵','🟢','🟡','🔴'];

  @override
  void initState() {
    super.initState();
    final r = widget.region;
    _nameCtrl    = TextEditingController(text: r?.name ?? '');
    _codeCtrl    = TextEditingController(text: r?.regionCode ?? '');
    _descCtrl    = TextEditingController(text: r?.description ?? '');
    _countryCtrl = TextEditingController();
    _countries   = List<String>.from(r?.countries ?? []);
    _colorHex    = r?.colorHex ?? '#00C9A7';
    _icon        = r?.icon ?? '🌍';
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
    final updated = MarketingRegion(
      id: widget.region?.id ?? 'reg_${now.millisecondsSinceEpoch}',
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              const Icon(Icons.map_rounded, color: AppTheme.mintPrimary, size: 20),
              const SizedBox(width: 10),
              Text(isNew ? '권역 추가' : '권역 편집',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(flex: 3, child: _fld('권역명 *', _nameCtrl, hint: '예: 동남아, 중동')),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _fld('권역 코드', _codeCtrl, hint: 'SEA, ME, NA…')),
                ]),
                const SizedBox(height: 10),
                _fld('설명', _descCtrl, hint: '권역 설명 (선택)', maxLines: 2),
                const SizedBox(height: 14),
                // 색상
                const Text('색상', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _colorOpts.map((hex) {
                  final color = Color(int.tryParse('0xFF${hex.replaceFirst('#', '')}') ?? 0xFF00C9A7);
                  final selected = _colorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                        border: Border.all(color: selected ? Colors.white : Colors.transparent, width: selected ? 2.5 : 0),
                        boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)] : [],
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                    ),
                  );
                }).toList()),
                const SizedBox(height: 14),
                // 아이콘
                const Text('아이콘', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: _iconOpts.map((icon) {
                  final selected = _icon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.mintPrimary.withValues(alpha: 0.2) : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: selected ? AppTheme.mintPrimary : AppTheme.border, width: selected ? 1.5 : 1),
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 17))),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 14),
                // 포함 국가
                const Text('포함 국가 코드', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _countryCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'KR, VN, AE … (입력 후 엔터)',
                        hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                      backgroundColor: AppTheme.bgSurface, foregroundColor: AppTheme.mintPrimary,
                      side: BorderSide(color: AppTheme.mintPrimary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('추가'),
                  ),
                ]),
                if (_countries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: _countries.map((c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 11)),
                    onDeleted: () => setState(() => _countries.remove(c)),
                    deleteIcon: const Icon(Icons.close, size: 12),
                    backgroundColor: AppTheme.bgSurface,
                    side: const BorderSide(color: AppTheme.border),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  )).toList()),
                ],
              ]),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted, side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 14),
                  label: Text(isNew ? '추가' : '저장'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _fld(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, maxLines: maxLines,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          filled: true, fillColor: AppTheme.bgSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
        ),
      ),
    ]);
}

// ══════════════════════════════════════════════════════════
// 권역 CSV 벌크 업로드 다이얼로그
// ══════════════════════════════════════════════════════════
class _RegionBulkDialog extends StatefulWidget {
  final AppProvider provider;
  const _RegionBulkDialog({required this.provider});
  @override
  State<_RegionBulkDialog> createState() => _RegionBulkDialogState();
}

class _RegionBulkDialogState extends State<_RegionBulkDialog> {
  final _ctrl = TextEditingController();
  List<MarketingRegion> _parsed = [];
  String? _error;
  bool _ok = false;

  static const _template =
    'name,regionCode,icon,colorHex,countries,description\n'
    '동남아,SEA,🌏,#00C9A7,"VN,TH,SG,MY,ID",동남아시아 지역\n'
    '중동,ME,🌍,#FFC93C,"AE,SA,QA,KW",중동 지역\n'
    '북미,NA,🌎,#4DB8FF,"US,CA,MX",북미 지역\n'
    '국내,DOM,🏙️,#6EE79C,KR,국내 시장';

  List<String> _parseLine(String line) {
    final result = <String>[]; final buf = StringBuffer(); bool inQ = false;
    for (final ch in line.runes) {
      final c = String.fromCharCode(ch);
      if (c == '"') { inQ = !inQ; }
      else if (c == ',' && !inQ) { result.add(buf.toString()); buf.clear(); }
      else { buf.write(c); }
    }
    result.add(buf.toString());
    return result;
  }

  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) { setState(() { _error = '데이터를 입력하세요'; _ok = false; }); return; }
    try {
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 2) throw '헤더+데이터 행이 필요합니다';
      final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      int col(List<String> keys) {
        for (final k in keys) { final i = header.indexOf(k); if (i >= 0) return i; }
        return -1;
      }
      final nameIdx    = col(['name', '권역명']);
      if (nameIdx < 0) throw '"name" 컬럼이 없습니다';
      final codeIdx    = col(['regioncode', 'region_code', '코드']);
      final iconIdx    = col(['icon', '아이콘']);
      final colorIdx   = col(['colorhex', 'color', '색상']);
      final countryIdx = col(['countries', '국가', '나라']);
      final descIdx    = col(['description', '설명']);

      final results = <MarketingRegion>[];
      for (int li = 1; li < lines.length; li++) {
        final cols = _parseLine(lines[li]);
        String g(int idx) => idx >= 0 && idx < cols.length ? cols[idx].trim() : '';
        if (g(nameIdx).isEmpty) continue;
        final countries = g(countryIdx).split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        results.add(MarketingRegion(
          id: 'reg_${DateTime.now().millisecondsSinceEpoch}_${results.length}',
          name: g(nameIdx),
          regionCode: codeIdx >= 0 && g(codeIdx).isNotEmpty ? g(codeIdx) : null,
          icon: iconIdx >= 0 && g(iconIdx).isNotEmpty ? g(iconIdx) : '🌍',
          colorHex: colorIdx >= 0 && g(colorIdx).isNotEmpty ? g(colorIdx) : '#00C9A7',
          countries: countries,
          description: descIdx >= 0 && g(descIdx).isNotEmpty ? g(descIdx) : null,
        ));
      }
      setState(() { _parsed = results; _ok = true; _error = null; });
    } catch (e) {
      setState(() { _error = '파싱 오류: $e'; _ok = false; _parsed = []; });
    }
  }

  void _import() {
    for (final r in _parsed) widget.provider.addRegion(r);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_parsed.length}개 권역이 추가되었습니다'),
      backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 580),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              const Icon(Icons.upload_file_rounded, color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 10),
              const Text('권역 CSV 일괄 업로드', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () { _ctrl.text = _template; },
                icon: const Icon(Icons.content_paste_rounded, size: 13),
                label: const Text('템플릿 불러오기', style: TextStyle(fontSize: 12)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('컬럼: name*, regionCode, icon, colorHex, countries(쉼표구분 → 따옴표로 묶기), description',
                        style: TextStyle(color: AppTheme.accentBlue, fontSize: 11)),
                    const SizedBox(height: 6),
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(6)),
                        child: Text(_template, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontFamily: 'monospace'))),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl, maxLines: 8,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'CSV 데이터 붙여넣기...',
                    hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 11),
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
                if (_ok && _parsed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${_parsed.length}개 권역 파싱 완료', style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: _parse,
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentBlue, side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: const Text('파싱 확인'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: _ok && _parsed.isNotEmpty ? _import : null,
                    icon: const Icon(Icons.upload_rounded, size: 14),
                    label: Text(_parsed.isNotEmpty ? '${_parsed.length}개 추가' : '가져오기'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary, disabledBackgroundColor: AppTheme.bgCardLight, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 10)),
                  )),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 권역 카드 (설정 탭)
// ══════════════════════════════════════════════════════════
class _RegionChipCard extends StatelessWidget {
  final MarketingRegion region;
  final int clientCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RegionChipCard({
    required this.region, required this.clientCount,
    required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.tryParse('0xFF${region.colorHex.replaceFirst('#', '')}') ?? 0xFF00C9A7);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Text(region.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(region.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              if (region.regionCode != null)
                Text(region.regionCode!, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text('고객사 $clientCount개', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            IconButton(icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.textMuted),
                onPressed: onEdit, constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28), padding: EdgeInsets.zero),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.error),
                onPressed: onDelete, constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28), padding: EdgeInsets.zero),
          ]),
        ),
        if (region.countries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Wrap(spacing: 5, runSpacing: 5, children: region.countries.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppTheme.border)),
              child: Text(c, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            )).toList()),
          )
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Text('포함 국가 없음', style: TextStyle(color: AppTheme.textDisabled, fontSize: 11)),
          ),
        if (region.description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(region.description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 공용 위젯
// ══════════════════════════════════════════════════════════
class _SummaryCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(color: AppTheme.textDisabled, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
    child: Center(child: Text(message, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13))),
  );
}

String _short(double v) {
  if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
  if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
  return v.toStringAsFixed(0);
}
