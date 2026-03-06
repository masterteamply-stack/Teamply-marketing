import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

// ════════════════════════════════════════════════════════
//  고객사 관리 페이지
// ════════════════════════════════════════════════════════
class ClientManagementPage extends StatefulWidget {
  const ClientManagementPage({super.key});
  @override
  State<ClientManagementPage> createState() => _ClientManagementPageState();
}

class _ClientManagementPageState extends State<ClientManagementPage> {
  String _search = '';
  String? _regionFilter;
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final regions  = provider.regions;
    var clients    = provider.clients.where((c) {
      if (!_showInactive && !c.isActive) return false;
      if (_regionFilter != null && c.region != _regionFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return c.name.toLowerCase().contains(q) ||
            (c.buyerCode ?? '').toLowerCase().contains(q) ||
            (c.country ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: const Text('고객사 관리', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          // CSV 벌크 업로드
          TextButton.icon(
            onPressed: () => _showBulkUploadDialog(context, provider),
            icon: const Icon(Icons.upload_file_rounded, size: 16, color: AppTheme.accentBlue),
            label: const Text('CSV 업로드', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          // 새 고객사 추가
          ElevatedButton.icon(
            onPressed: () => _showClientDialog(context, provider, null),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('고객사 추가', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // ── 검색 / 필터 바 ──────────────────────────────
          Container(
            color: AppTheme.bgCard,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              // 검색
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '고객사명, 바이어코드, 국가 검색...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppTheme.bgSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 권역 필터
              Expanded(
                flex: 2,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _regionFilter,
                      hint: const Text('전체 권역', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      isExpanded: true,
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('전체 권역', style: TextStyle(color: AppTheme.textMuted))),
                        ...regions.map((r) => DropdownMenuItem<String>(
                          value: r.name,
                          child: Row(children: [
                            Text(r.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(r.name),
                          ]),
                        )),
                      ],
                      onChanged: (v) => setState(() => _regionFilter = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 비활성 포함 토글
              Row(children: [
                Switch(
                  value: _showInactive,
                  onChanged: (v) => setState(() => _showInactive = v),
                  activeColor: AppTheme.mintPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text('비활성 포함', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]),
            ]),
          ),
          // ── 통계 요약 바 ─────────────────────────────────
          _SummaryBar(clients: clients),
          // ── 테이블 헤더 ──────────────────────────────────
          Container(
            color: AppTheme.bgCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _th('바이어코드', flex: 2),
              _th('고객사명',   flex: 3),
              _th('권역',      flex: 2),
              _th('국가',      flex: 2),
              _th('업종',      flex: 2),
              _th('매출 (₩)', flex: 2, align: TextAlign.right),
              _th('ROI',      flex: 1, align: TextAlign.right),
              _th('상태',     flex: 1, align: TextAlign.center),
              _th('',         flex: 1),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // ── 목록 ─────────────────────────────────────────
          Expanded(
            child: clients.isEmpty
                ? _EmptyState(onAdd: () => _showClientDialog(context, provider, null))
                : ListView.separated(
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (_, i) {
                      final c = clients[i];
                      return _ClientRow(
                        client: c,
                        onEdit: () => _showClientDialog(context, provider, c),
                        onDelete: () => _confirmDelete(context, provider, c),
                        onToggle: () => provider.updateClient(c.copyWith(isActive: !c.isActive)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) => Expanded(
    flex: flex,
    child: Text(label, textAlign: align,
      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  );

  void _showClientDialog(BuildContext ctx, AppProvider provider, ClientAccount? client) {
    showDialog(
      context: ctx,
      builder: (_) => _ClientEditDialog(
        client: client,
        provider: provider,
        regions: provider.regions,
      ),
    );
  }

  void _showBulkUploadDialog(BuildContext ctx, AppProvider provider) {
    showDialog(
      context: ctx,
      builder: (_) => _ClientBulkUploadDialog(provider: provider),
    );
  }

  void _confirmDelete(BuildContext ctx, AppProvider provider, ClientAccount c) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('고객사 삭제', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('「${c.name}」를 삭제하시겠습니까?\n연결된 데이터는 유지됩니다.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () { provider.deleteClient(c.id); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 통계 요약 바 ───────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<ClientAccount> clients;
  const _SummaryBar({required this.clients});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final total    = clients.length;
    final active   = clients.where((c) => c.isActive).length;
    final totalRev = clients.fold(0.0, (s, c) => s + c.revenue);
    final regions  = clients.map((c) => c.region).whereType<String>().toSet().length;

    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _stat('전체 고객사', '$total개', AppTheme.textSecondary),
        _divider(),
        _stat('활성', '$active개', AppTheme.success),
        _divider(),
        _stat('권역 수', '$regions개', AppTheme.accentBlue),
        _divider(),
        _stat('총 매출', '₩${fmt.format(totalRev)}', AppTheme.mintPrimary),
        const Spacer(),
        Text('마지막 업데이트: ${DateFormat('MM.dd HH:mm').format(DateTime.now())}',
            style: const TextStyle(color: AppTheme.textDisabled, fontSize: 11)),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _divider() => Container(height: 28, width: 1, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 4));
}

// ── 고객사 행 ──────────────────────────────────────────
class _ClientRow extends StatelessWidget {
  final ClientAccount client;
  final VoidCallback onEdit, onDelete, onToggle;
  const _ClientRow({required this.client, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final roi = client.roi;
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
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: client.isActive ? AppTheme.success : AppTheme.textDisabled,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(client.name,
                style: TextStyle(
                  color: client.isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                  fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ])),
          // 권역
          Expanded(flex: 2, child: Text(client.region ?? '—',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          // 국가
          Expanded(flex: 2, child: Text(client.country ?? '—',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          // 업종
          Expanded(flex: 2, child: Text(client.industry ?? '—',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              overflow: TextOverflow.ellipsis)),
          // 매출
          Expanded(flex: 2, child: Text(
              client.revenue > 0 ? '₩${fmt.format(client.revenue)}' : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: client.revenue > 0 ? AppTheme.mintPrimary : AppTheme.textDisabled,
                fontSize: 12, fontWeight: FontWeight.w600))),
          // ROI
          Expanded(flex: 1, child: Text(
              client.adSpend > 0 ? '${roi.toStringAsFixed(1)}%' : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: roi >= 0 ? AppTheme.success : AppTheme.error,
                fontSize: 12, fontWeight: FontWeight.w600))),
          // 상태 토글
          Expanded(flex: 1, child: Center(
            child: Switch(
              value: client.isActive,
              onChanged: (_) => onToggle(),
              activeColor: AppTheme.mintPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )),
          // 액션
          Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 15, color: AppTheme.textMuted),
              onPressed: onEdit, tooltip: '편집',
              constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.error),
              onPressed: onDelete, tooltip: '삭제',
              constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
              padding: EdgeInsets.zero,
            ),
          ])),
        ]),
      ),
    );
  }
}

// ── 빈 상태 ────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.business_rounded, size: 32, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),
        const Text('등록된 고객사가 없습니다', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('개별 추가하거나 CSV로 일괄 업로드하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('고객사 추가'),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════
//  고객사 편집/추가 다이얼로그
// ════════════════════════════════════════════════════════
class _ClientEditDialog extends StatefulWidget {
  final ClientAccount? client;
  final AppProvider provider;
  final List<MarketingRegion> regions;
  const _ClientEditDialog({required this.client, required this.provider, required this.regions});

  @override
  State<_ClientEditDialog> createState() => _ClientEditDialogState();
}

class _ClientEditDialogState extends State<_ClientEditDialog> {
  late TextEditingController _nameCtrl, _buyerCodeCtrl, _industryCtrl;
  late TextEditingController _contactNameCtrl, _contactEmailCtrl, _contactPhoneCtrl;
  late TextEditingController _noteCtrl, _revenueCtrl, _adSpendCtrl, _countryCtrl;
  String? _selectedRegion;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameCtrl        = TextEditingController(text: c?.name ?? '');
    _buyerCodeCtrl   = TextEditingController(text: c?.buyerCode ?? '');
    _industryCtrl    = TextEditingController(text: c?.industry ?? '');
    _contactNameCtrl = TextEditingController(text: c?.contactName ?? '');
    _contactEmailCtrl= TextEditingController(text: c?.contactEmail ?? '');
    _contactPhoneCtrl= TextEditingController(text: c?.contactPhone ?? '');
    _noteCtrl        = TextEditingController(text: c?.note ?? '');
    _revenueCtrl     = TextEditingController(text: c != null && c.revenue > 0 ? c.revenue.toStringAsFixed(0) : '');
    _adSpendCtrl     = TextEditingController(text: c != null && c.adSpend > 0 ? c.adSpend.toStringAsFixed(0) : '');
    _countryCtrl     = TextEditingController(text: c?.country ?? '');
    _selectedRegion  = c?.region;
    _isActive        = c?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _buyerCodeCtrl, _industryCtrl, _contactNameCtrl,
      _contactEmailCtrl, _contactPhoneCtrl, _noteCtrl, _revenueCtrl, _adSpendCtrl, _countryCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final now = DateTime.now();
    final id = widget.client?.id ?? 'c_${now.millisecondsSinceEpoch}';
    final updated = ClientAccount(
      id: id,
      name: _nameCtrl.text.trim(),
      buyerCode: _buyerCodeCtrl.text.trim().isEmpty ? null : _buyerCodeCtrl.text.trim(),
      country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
      region: _selectedRegion,
      industry: _industryCtrl.text.trim().isEmpty ? null : _industryCtrl.text.trim(),
      contactName: _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim(),
      contactEmail: _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim(),
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
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business_rounded, color: AppTheme.accentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(isNew ? '고객사 추가' : '고객사 편집',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // 폼
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 기본 정보
                _sectionTitle('기본 정보'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 3, child: _field('고객사명 *', _nameCtrl, hint: '예: 베트남 파트너스')),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _field('바이어 코드', _buyerCodeCtrl, hint: 'B-001')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(flex: 2, child: _regionDropdown()),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _field('국가', _countryCtrl, hint: 'KR, VN, AE…')),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _field('업종', _industryCtrl, hint: '유통, 제조…')),
                ]),
                const SizedBox(height: 20),

                // 담당자 정보
                _sectionTitle('담당자 정보'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('담당자명', _contactNameCtrl, hint: '홍길동')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('이메일', _contactEmailCtrl, hint: 'buyer@example.com')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('연락처', _contactPhoneCtrl, hint: '+82-10-0000-0000')),
                ]),
                const SizedBox(height: 20),

                // 성과 데이터
                _sectionTitle('성과 데이터 (선택)'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('매출 (₩)', _revenueCtrl,
                      hint: '0', keyboardType: TextInputType.number, prefix: '₩')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('광고비 (₩)', _adSpendCtrl,
                      hint: '0', keyboardType: TextInputType.number, prefix: '₩')),
                ]),
                const SizedBox(height: 12),
                _field('메모', _noteCtrl, hint: '추가 메모 (선택)', maxLines: 2),
                const SizedBox(height: 12),

                // 활성 상태
                Row(children: [
                  Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v),
                      activeColor: AppTheme.mintPrimary),
                  const SizedBox(width: 8),
                  Text(_isActive ? '활성 고객사' : '비활성 고객사',
                      style: TextStyle(
                        color: _isActive ? AppTheme.success : AppTheme.textMuted,
                        fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
          ),
          // 하단 버튼
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
                  label: Text(isNew ? '추가' : '저장', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.mintPrimary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ]),
  );

  Widget _field(String label, TextEditingController ctrl, {
    String? hint, int maxLines = 1, TextInputType? keyboardType, String? prefix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix != null ? '$prefix ' : null,
          hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
          prefixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: AppTheme.bgSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _regionDropdown() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('권역', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
    const SizedBox(height: 4),
    Container(
      height: 42,
      decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.regions.any((r) => r.name == _selectedRegion) ? _selectedRegion : null,
          hint: const Text('권역 선택', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('(없음)', style: TextStyle(color: AppTheme.textMuted))),
            ...widget.regions.map((r) => DropdownMenuItem<String>(
              value: r.name,
              child: Row(children: [
                Text(r.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(r.name),
              ]),
            )),
          ],
          onChanged: (v) => setState(() => _selectedRegion = v),
        ),
      ),
    ),
  ]);
}

// ════════════════════════════════════════════════════════
//  CSV 벌크 업로드 다이얼로그
// ════════════════════════════════════════════════════════
class _ClientBulkUploadDialog extends StatefulWidget {
  final AppProvider provider;
  const _ClientBulkUploadDialog({required this.provider});

  @override
  State<_ClientBulkUploadDialog> createState() => _ClientBulkUploadDialogState();
}

class _ClientBulkUploadDialogState extends State<_ClientBulkUploadDialog> {
  final _ctrl = TextEditingController();
  List<ClientAccount> _parsed = [];
  String? _error;
  bool _parsed_ok = false;

  static const _template = 
    'buyerCode,name,region,country,industry,contactName,contactEmail,revenue,adSpend\n'
    'B-001,베트남 파트너스,동남아,VN,유통,nguyen,nguyen@vn.com,50000000,5000000\n'
    'B-002,두바이 트레이딩,중동,AE,제조,ahmed,ahmed@ae.com,80000000,8000000\n'
    'B-003,서울 리테일,국내,KR,리테일,김민준,min@kr.com,30000000,3000000';

  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) { setState(() { _error = 'CSV 데이터를 입력하세요'; _parsed_ok = false; }); return; }
    try {
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) { setState(() { _error = '데이터가 없습니다'; _parsed_ok = false; }); return; }

      final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      final nameIdx    = _idx(header, ['name', '고객사명', '고객사']);
      final codeIdx    = _idx(header, ['buyercode', 'buyer_code', '바이어코드', '코드']);
      final regionIdx  = _idx(header, ['region', '권역']);
      final countryIdx = _idx(header, ['country', '국가']);
      final industryIdx= _idx(header, ['industry', '업종']);
      final contactIdx = _idx(header, ['contactname', 'contact_name', '담당자명', '담당자']);
      final emailIdx   = _idx(header, ['email', 'contactemail', 'contact_email', '이메일']);
      final revenueIdx = _idx(header, ['revenue', '매출']);
      final adIdx      = _idx(header, ['adspend', 'ad_spend', '광고비']);

      if (nameIdx < 0) throw '필수 컬럼 "name"이 없습니다';

      final results = <ClientAccount>[];
      for (final line in lines.skip(1)) {
        final cols = line.split(',').map((c) => c.trim()).toList();
        if (cols.isEmpty || (cols.length == 1 && cols.first.isEmpty)) continue;
        String get(int idx) => idx >= 0 && idx < cols.length ? cols[idx] : '';
        results.add(ClientAccount(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}_${results.length}',
          name: get(nameIdx),
          buyerCode: codeIdx >= 0 ? (get(codeIdx).isEmpty ? null : get(codeIdx)) : null,
          region: regionIdx >= 0 ? (get(regionIdx).isEmpty ? null : get(regionIdx)) : null,
          country: countryIdx >= 0 ? (get(countryIdx).isEmpty ? null : get(countryIdx)) : null,
          industry: industryIdx >= 0 ? (get(industryIdx).isEmpty ? null : get(industryIdx)) : null,
          contactName: contactIdx >= 0 ? (get(contactIdx).isEmpty ? null : get(contactIdx)) : null,
          contactEmail: emailIdx >= 0 ? (get(emailIdx).isEmpty ? null : get(emailIdx)) : null,
          revenue: double.tryParse(get(revenueIdx).replaceAll(',', '')) ?? 0,
          adSpend: double.tryParse(get(adIdx).replaceAll(',', '')) ?? 0,
          createdAt: DateTime.now(),
        ));
      }
      setState(() { _parsed = results; _parsed_ok = true; _error = null; });
    } catch (e) {
      setState(() { _error = '파싱 오류: $e'; _parsed_ok = false; _parsed = []; });
    }
  }

  int _idx(List<String> header, List<String> keys) {
    for (final k in keys) {
      final i = header.indexWhere((h) => h == k);
      if (i >= 0) return i;
    }
    return -1;
  }

  void _import() {
    for (final c in _parsed) {
      widget.provider.addClient(c);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_parsed.length}개 고객사가 추가되었습니다'),
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
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.upload_file_rounded, color: AppTheme.accentBlue, size: 22),
              const SizedBox(width: 12),
              const Text('고객사 CSV 일괄 업로드',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              // 템플릿 복사
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: _template));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('템플릿이 클립보드에 복사되었습니다'),
                    behavior: SnackBarBehavior.floating,
                  ));
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
                      Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 14),
                      SizedBox(width: 6),
                      Text('CSV 형식 안내', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    const Text('필수: name (고객사명)\n선택: buyerCode, region, country, industry, contactName, contactEmail, revenue, adSpend',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(6)),
                      child: const Text(_template, style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontFamily: 'monospace')),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                // CSV 입력
                const Text('CSV 데이터 붙여넣기', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrl,
                  maxLines: 8,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '위 템플릿을 복사하여 데이터를 붙여넣으세요...',
                    hintStyle: const TextStyle(color: AppTheme.textDisabled, fontSize: 12),
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
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12))),
                    ]),
                  ),
                if (_parsed_ok && _parsed.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 14),
                      const SizedBox(width: 6),
                      Text('${_parsed.length}개 행이 파싱되었습니다 → 미리보기:',
                          style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
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
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _parsed_ok && _parsed.isNotEmpty ? _import : null,
                      icon: const Icon(Icons.upload_rounded, size: 16),
                      label: Text(_parsed.isNotEmpty ? '${_parsed.length}개 가져오기' : '가져오기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintPrimary,
                        disabledBackgroundColor: AppTheme.bgCardLight,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
