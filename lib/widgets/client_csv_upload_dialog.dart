import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// 고객사 CSV 벌크 업로드 다이얼로그
/// SAP 스타일 고객사 포맷 지원:
/// 비즈니스 파트너 | 이름 1 | 바이어 번호 | 국가코드 | 전화2 | 판매 조직 | 내역4(조직명) |
/// 유통경로 | 통화 | 판매 구역 | 인코텀스 | 내역6(인코텀스설명) | 판매처 | 판매처명 |
/// 청구처 | 청구처명 | 납품처 | 납품처명 | 결산기준유형 | 내역11 | PB오더구분 |
/// 지역이름2 | D_Country.영문명 | D_지역.Region
class ClientCsvUploadDialog extends StatefulWidget {
  final AppProvider provider;
  final String? teamId;

  const ClientCsvUploadDialog({
    super.key,
    required this.provider,
    this.teamId,
  });

  @override
  State<ClientCsvUploadDialog> createState() => _ClientCsvUploadDialogState();
}

class _ClientCsvUploadDialogState extends State<ClientCsvUploadDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _ctrl = TextEditingController();
  List<ClientAccount> _parsed = [];
  List<String> _parseErrors = [];
  List<String> _parseWarnings = [];
  bool _showPreview = false;
  bool _imported = false;
  int _importedCount = 0;
  int _skippedCount = 0;

  // SAP 형식 샘플 데이터 (탭 구분)
  static const _sampleTsv = '''비즈니스 파트너\t이름 1\t바이어 번호\t국가코드\t전화2\t판매 조직\t내역4\t유통경로\t통화\t판매 구역\t인코텀스\t내역6\t판매처\t판매처명\t청구처\t청구처명\t납품처\t납품처명\t결산기준유형\t내역11\tPB오더구분\t지역이름2\tD_Country.영문명\tD_지역.Region
289901\tTAN CO INVESTMENT AND DEVELOPMENT JOINT\t551-020\tVN\t\t4200\tCTR Vina\t11\tVND\t1\tEXW\t공장 인도 조건(EXW)\t289901\tTAN CO INVESTMENT AND DEVELOPMENT J\t289901\tTAN CO INVESTMENT AND DEVELOPMENT J\t289901\tTAN CO INVESTMENT AND DEVELOPMENT J\t40\t공장출고기준\t1\t아시아\tVietnam\tAsia & Pacific
200512\tCTR VINA\t001-001\tVN\t\t4200\tCTR Vina\t11\tVND\t1\tCIF\t운임 보험료 포함 조건(CIF)\t200512\tCTR VINA\t200512\tCTR VINA\t200512\tCTR VINA\t30\t수출선적기준\t\t아시아\tVietnam\tAsia & Pacific
289355\tVantage Logistics Joint Stock Company\t551-019\tVN\t\t1100\tCTR\t11\tUSD\t1\tCIF\t운임 보험료 포함 조건(CIF)\t289355\tVantage Logistics Joint Stock Compa\t289355\tVantage Logistics Joint Stock Compa\t289355\tVantage Logistics Joint Stock Compa\t30\t수출선적기준\t1\t아시아\tVietnam\tAsia & Pacific
288406\tLIFEPRO AUTO .,JSC\t551-806\tVN\t\t1100\tCTR\t11\tUSD\t1\tFOB\t본선 인도 조건(FOB)\t288406\tLIFEPRO AUTO .,JSC\t288406\tLIFEPRO AUTO .,JSC\t288406\tLIFEPRO AUTO .,JSC\t30\t수출선적기준\t1\t아시아\tVietnam\tAsia & Pacific''';

  // CSV 형식 샘플 (쉼표 구분)
  static const _sampleCsv = '''비즈니스 파트너,이름 1,바이어 번호,국가코드,전화2,판매 조직,내역4,유통경로,통화,판매 구역,인코텀스,내역6,판매처,판매처명,청구처,청구처명,납품처,납품처명,결산기준유형,내역11,PB오더구분,지역이름2,D_Country.영문명,D_지역.Region
289901,TAN CO INVESTMENT AND DEVELOPMENT JOINT,551-020,VN,,4200,CTR Vina,11,VND,1,EXW,공장 인도 조건(EXW),289901,TAN CO INVESTMENT AND DEVELOPMENT J,289901,TAN CO INVESTMENT AND DEVELOPMENT J,289901,TAN CO INVESTMENT AND DEVELOPMENT J,40,공장출고기준,1,아시아,Vietnam,Asia & Pacific
200512,CTR VINA,001-001,VN,,4200,CTR Vina,11,VND,1,CIF,운임 보험료 포함 조건(CIF),200512,CTR VINA,200512,CTR VINA,200512,CTR VINA,30,수출선적기준,,아시아,Vietnam,Asia & Pacific''';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ── 파싱 ─────────────────────────────────────────────────
  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 2) {
      setState(() {
        _parseErrors = ['헤더와 데이터 행이 최소 1개씩 필요합니다.'];
        _showPreview = true;
      });
      return;
    }

    // 탭 구분인지 쉼표 구분인지 자동 감지
    final firstLine = lines.first;
    final delimiter = firstLine.contains('\t') ? '\t' : ',';

    final headers = _splitLine(firstLine, delimiter).map((h) => h.trim().toLowerCase()).toList();

    // 헤더 매핑 (유연하게 처리)
    final colMap = _buildColumnMap(headers);

    final result = <ClientAccount>[];
    final errors = <String>[];
    final warnings = <String>[];

    for (int i = 1; i < lines.length; i++) {
      final cells = _splitLine(lines[i], delimiter);
      if (cells.every((c) => c.trim().isEmpty)) continue;

      String _get(String key) {
        final idx = colMap[key];
        if (idx == null || idx >= cells.length) return '';
        return cells[idx].trim();
      }

      final bpNum = _get('bp');       // 비즈니스 파트너 번호
      final name = _get('name');

      if (name.isEmpty && bpNum.isEmpty) {
        warnings.add('행 ${i + 1}: 이름과 BP번호가 모두 비어 있어 건너뜁니다');
        continue;
      }

      final displayName = name.isNotEmpty ? name : bpNum;

      // 중복 체크 (BP번호 기준)
      final buyerCode = _get('buyerCode');
      final existing = widget.provider.clients.where((c) =>
        (bpNum.isNotEmpty && c.id == 'bp_$bpNum') ||
        (buyerCode.isNotEmpty && c.buyerCode == buyerCode)
      ).firstOrNull;

      if (existing != null) {
        warnings.add('행 ${i + 1}: 이미 존재하는 고객사 "${existing.name}" (건너뜀)');
        continue;
      }

      result.add(ClientAccount(
        id: 'bp_${bpNum.isNotEmpty ? bpNum : 'new_${DateTime.now().millisecondsSinceEpoch}_$i'}',
        name: displayName,
        buyerCode: buyerCode.isNotEmpty ? buyerCode : null,
        country: _get('country').isNotEmpty ? _get('country') : null,
        countryName: _get('countryName').isNotEmpty ? _get('countryName') : null,
        region: _get('region').isNotEmpty ? _get('region') : null,
        regionEn: _get('regionEn').isNotEmpty ? _get('regionEn') : null,
        contactPhone: _get('phone').isNotEmpty ? _get('phone') : null,
        teamId: widget.teamId,
        salesOrg: _get('salesOrg').isNotEmpty ? _get('salesOrg') : null,
        salesOrgName: _get('salesOrgName').isNotEmpty ? _get('salesOrgName') : null,
        distributionChannel: _get('distChannel').isNotEmpty ? _get('distChannel') : null,
        currency: _get('currency').isNotEmpty ? _get('currency') : null,
        salesZone: _get('salesZone').isNotEmpty ? _get('salesZone') : null,
        incoterms: _get('incoterms').isNotEmpty ? _get('incoterms') : null,
        incotermsDesc: _get('incotermsDesc').isNotEmpty ? _get('incotermsDesc') : null,
        soldToParty: _get('soldTo').isNotEmpty ? _get('soldTo') : null,
        soldToPartyName: _get('soldToName').isNotEmpty ? _get('soldToName') : null,
        billToParty: _get('billTo').isNotEmpty ? _get('billTo') : null,
        billToPartyName: _get('billToName').isNotEmpty ? _get('billToName') : null,
        shipToParty: _get('shipTo').isNotEmpty ? _get('shipTo') : null,
        shipToPartyName: _get('shipToName').isNotEmpty ? _get('shipToName') : null,
        settlementType: _get('settlementType').isNotEmpty ? _get('settlementType') : null,
        settlementTypeDesc: _get('settlementTypeDesc').isNotEmpty ? _get('settlementTypeDesc') : null,
        pbOrderType: _get('pbOrder').isNotEmpty ? _get('pbOrder') : null,
        isActive: true,
        createdAt: DateTime.now(),
      ));
    }

    setState(() {
      _parsed = result;
      _parseErrors = errors;
      _parseWarnings = warnings;
      _showPreview = true;
    });
  }

  /// 헤더 → 컬럼 인덱스 맵 (유연한 매칭)
  Map<String, int> _buildColumnMap(List<String> headers) {
    final map = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      // 비즈니스 파트너 번호
      if (h.contains('비즈니스') || h == 'bp' || h == 'partner') map['bp'] = i;
      // 이름
      else if (h == '이름 1' || h == '이름1' || h == 'name' || h == '이름') map['name'] = i;
      // 바이어 번호
      else if (h.contains('바이어') || h.contains('buyer')) map['buyerCode'] = i;
      // 국가코드
      else if (h == '국가코드' || h == 'country' || h == '국가 코드') map['country'] = i;
      // 전화
      else if (h.contains('전화') || h.contains('phone')) map['phone'] = i;
      // 판매 조직
      else if (h.contains('판매 조직') || h.contains('salesorg') || h == '판매조직') map['salesOrg'] = i;
      // 판매 조직명 (내역4)
      else if (h == '내역4' || h == '조직명') map['salesOrgName'] = i;
      // 유통경로
      else if (h.contains('유통') || h.contains('distribution')) map['distChannel'] = i;
      // 통화
      else if (h == '통화' || h == 'currency') map['currency'] = i;
      // 판매 구역
      else if (h.contains('판매 구역') || h.contains('saleszone') || h == '판매구역') map['salesZone'] = i;
      // 인코텀스
      else if (h == '인코텀스' || h.contains('incoterm')) map['incoterms'] = i;
      // 인코텀스 설명 (내역6)
      else if (h == '내역6') map['incotermsDesc'] = i;
      // 판매처
      else if (h == '판매처' || h == 'soldto' || h == 'sold to') map['soldTo'] = i;
      // 판매처명
      else if (h == '판매처명') map['soldToName'] = i;
      // 청구처
      else if (h == '청구처' || h == 'billto' || h == 'bill to') map['billTo'] = i;
      // 청구처명
      else if (h == '청구처명') map['billToName'] = i;
      // 납품처
      else if (h == '납품처' || h == 'shipto' || h == 'ship to') map['shipTo'] = i;
      // 납품처명
      else if (h == '납품처명') map['shipToName'] = i;
      // 결산기준유형
      else if (h.contains('결산') || h.contains('settlement')) map['settlementType'] = i;
      // 결산기준설명 (내역11)
      else if (h == '내역11') map['settlementTypeDesc'] = i;
      // PB오더구분
      else if (h.contains('pb오더') || h.contains('pb order')) map['pbOrder'] = i;
      // 지역 (한글)
      else if (h == '지역이름2' || h == '지역' || h == 'region') map['region'] = i;
      // 국가 영문명
      else if (h == 'd_country.영문명' || h == '영문명' || h.contains('country.')) map['countryName'] = i;
      // 권역 영문 (Region)
      else if (h == 'd_지역.region' || h == 'd_region' || (h.contains('지역') && h.contains('region'))) map['regionEn'] = i;
    }
    return map;
  }

  List<String> _splitLine(String line, String delimiter) {
    if (delimiter == '\t') return line.split('\t');
    // CSV 파서 (따옴표 지원)
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
    final result = widget.provider.bulkAddClients(_parsed);
    setState(() {
      _imported = true;
      _importedCount = result['added'] as int? ?? _parsed.length;
      _skippedCount = result['skipped'] as int? ?? 0;
    });
  }

  // ── 빌드 ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (!_imported) ...[
              _buildTabBar(),
              Expanded(child: TabBarView(
                controller: _tabCtrl,
                children: [_buildInputTab(), _buildFormatGuideTab()],
              )),
            ] else
              Expanded(child: _buildImportResult()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.business, color: AppTheme.info, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('고객사 CSV 벌크 업로드',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          Text(
            widget.teamId != null
                ? '팀 고객사 목록 · SAP/ERP 내보내기 형식 지원 (탭 또는 쉼표 구분)'
                : '전사 고객사 목록 · SAP/ERP 내보내기 형식 지원',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ])),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: TabBar(
        controller: _tabCtrl,
        tabs: const [
          Tab(text: '데이터 입력 & 미리보기'),
          Tab(text: '포맷 가이드'),
        ],
        labelColor: AppTheme.mintPrimary,
        unselectedLabelColor: AppTheme.textMuted,
        indicatorColor: AppTheme.mintPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInputTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 좌측: 입력 ─────────────────────────────
        SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 빠른 샘플 버튼들
                Row(children: [
                  _SampleBtn(
                    label: 'TSV 샘플',
                    icon: Icons.table_rows,
                    color: AppTheme.info,
                    onTap: () {
                      _ctrl.text = _sampleTsv;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('TSV 샘플이 입력창에 로드되었습니다'),
                            backgroundColor: AppTheme.info, duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _SampleBtn(
                    label: 'CSV 샘플',
                    icon: Icons.table_chart,
                    color: AppTheme.mintPrimary,
                    onTap: () {
                      _ctrl.text = _sampleCsv;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('CSV 샘플이 입력창에 로드되었습니다'),
                            backgroundColor: AppTheme.mintPrimary, duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                  const Spacer(),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() { _parsed = []; _showPreview = false; });
                      },
                      child: const Icon(Icons.clear_all, color: AppTheme.textMuted, size: 18),
                    ),
                ]),
                const SizedBox(height: 10),

                // 핵심 컬럼 요약
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E3040)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('필수 → 선택 컬럼 순서',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _ColHint('비즈니스 파트너', '고객사 ID (자동 키)', AppTheme.warning),
                    _ColHint('이름 1', '고객사명 (필수)', AppTheme.mintPrimary),
                    _ColHint('바이어 번호', '내부 바이어 코드', AppTheme.textMuted),
                    _ColHint('국가코드', 'VN, KR, AE 등', AppTheme.textMuted),
                    _ColHint('D_Country.영문명', 'Vietnam, Korea 등', AppTheme.textMuted),
                    _ColHint('지역이름2', '아시아, 중동 등', AppTheme.textMuted),
                    _ColHint('D_지역.Region', 'Asia & Pacific 등', AppTheme.textMuted),
                  ]),
                ),
                const SizedBox(height: 12),

                // 입력창
                const Text('CSV / TSV 붙여넣기',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 11, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: '엑셀에서 복사 후 붙여넣기 (탭 구분자 자동 감지)\n또는 CSV 형식 입력',
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

        // ── 우측: 미리보기 ────────────────────────────
        const VerticalDivider(width: 1, color: Color(0xFF1E3040)),
        Expanded(
          child: _showPreview ? _buildPreviewPanel() : _buildEmptyPreview(),
        ),
      ],
    );
  }

  Widget _buildEmptyPreview() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.business_outlined, color: AppTheme.textMuted.withValues(alpha: 0.3), size: 56),
        const SizedBox(height: 14),
        const Text('CSV/TSV를 입력하고 파싱 버튼을 눌러주세요',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('엑셀에서 직접 복사&붙여넣기 가능합니다',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
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
              color: _parsed.isEmpty
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : AppTheme.success.withValues(alpha: 0.1),
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
                _parsed.isEmpty ? '파싱 실패' : '${_parsed.length}개 신규 고객사 파싱 완료',
                style: TextStyle(
                  color: _parsed.isEmpty ? AppTheme.error : AppTheme.success,
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          if (_parseWarnings.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${_parseWarnings.length}개 건너뜀',
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

        // 경고/스킵 목록
        if (_parseWarnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('건너뜀/경고 내역',
                    style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ..._parseWarnings.take(5).map((w) => Row(children: [
                  const Icon(Icons.warning_amber, color: AppTheme.warning, size: 11),
                  const SizedBox(width: 4),
                  Expanded(child: Text(w, style: const TextStyle(color: AppTheme.warning, fontSize: 10))),
                ])),
                if (_parseWarnings.length > 5)
                  Text('외 ${_parseWarnings.length - 5}건 더...',
                      style: const TextStyle(color: AppTheme.warning, fontSize: 10)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // 고객사 카드 목록
        Expanded(
          child: _parsed.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  itemCount: _parsed.length,
                  itemBuilder: (_, i) => _ClientPreviewCard(
                    client: _parsed[i],
                    index: i,
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildFormatGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _GuideSection('SAP/ERP 내보내기 형식', [
          '엑셀에서 복사 후 바로 붙여넣기 가능 (탭 구분자 자동 감지)',
          '헤더 행 포함 필수 (첫 번째 행)',
          '비즈니스 파트너 번호가 고객사 ID로 사용됩니다',
          '이미 존재하는 BP번호/바이어번호는 자동으로 건너뜁니다',
        ]),
        const SizedBox(height: 16),
        _GuideSection('컬럼 설명 (좌→우 순서)', []),
        const SizedBox(height: 8),
        _ColumnTable(),
        const SizedBox(height: 16),
        _GuideSection('업로드 후 연동되는 기능', [
          '대시보드 → 고객사별 ROI, 국가별 성과 위젯 자동 반영',
          '캠페인 → 태스크에 고객사 연결 가능',
          'KPI 관리 → 고객사별 KPI 타겟 설정 가능',
          '팀 프로젝트 → 태스크에 대상 고객사 지정 가능',
          '마케팅 퍼널 → 고객사별 퍼널 단계 추적',
        ]),
      ]),
    );
  }

  Widget _buildImportResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.business_center, color: AppTheme.success, size: 52),
          ),
          const SizedBox(height: 20),
          Text('$_importedCount개 고객사 등록 완료!',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_skippedCount > 0)
            Text('$_skippedCount개 중복 건너뜀',
                style: const TextStyle(color: AppTheme.warning, fontSize: 14)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3040)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('자동 연동 완료', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _ResultItem(Icons.dashboard_outlined, '대시보드 고객사 ROI 위젯 갱신'),
              _ResultItem(Icons.campaign_outlined, '캠페인 고객사 연결 활성화'),
              _ResultItem(Icons.track_changes_outlined, 'KPI 고객사별 타겟 설정 가능'),
              _ResultItem(Icons.folder_outlined, '팀 프로젝트 태스크 고객사 지정 가능'),
            ]),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _imported = false;
                  _parsed = [];
                  _parseErrors = [];
                  _parseWarnings = [];
                  _showPreview = false;
                  _ctrl.clear();
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: Color(0xFF1E3040)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('추가 업로드'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── 보조 위젯들 ─────────────────────────────────────────────

class _SampleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SampleBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

Widget _ColHint(String col, String desc, Color color) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Container(
        width: 110,
        child: Text(col, style: TextStyle(color: color, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
      Expanded(child: Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9))),
    ]),
  );
}

class _ClientPreviewCard extends StatelessWidget {
  final ClientAccount client;
  final int index;
  const _ClientPreviewCard({required this.client, required this.index});

  @override
  Widget build(BuildContext context) {
    final regionColor = _regionColor(client.regionEn ?? client.region ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: regionColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: regionColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(5)),
            child: Center(child: Text('${index + 1}',
                style: TextStyle(color: regionColor, fontSize: 9, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(client.name,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            if (client.buyerCode != null || client.id.startsWith('bp_'))
              Text(
                [
                  if (client.buyerCode != null) '바이어: ${client.buyerCode}',
                  if (client.id.startsWith('bp_')) 'BP: ${client.id.substring(3)}',
                ].join(' · '),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
          ])),
          // 국가 + 권역 배지
          if (client.country != null || client.countryName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: regionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${client.country ?? ''} ${client.countryName != null ? "· ${client.countryName}" : ""}'.trim(),
                style: TextStyle(color: regionColor, fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (client.salesOrg != null)
            _MiniTag('조직 ${client.salesOrg}${client.salesOrgName != null ? " (${client.salesOrgName})" : ""}', AppTheme.info),
          if (client.currency != null)
            _MiniTag(client.currency!, AppTheme.warning),
          if (client.incoterms != null)
            _MiniTag(client.incoterms!, AppTheme.success),
          if (client.region != null)
            _MiniTag(client.region!, regionColor),
          if (client.regionEn != null && client.regionEn != client.region)
            _MiniTag(client.regionEn!, regionColor.withValues(alpha: 0.7)),
        ]),
      ]),
    );
  }

  Color _regionColor(String region) {
    final lower = region.toLowerCase();
    if (lower.contains('asia') || lower.contains('아시아')) return const Color(0xFF4CAF50);
    if (lower.contains('middle') || lower.contains('중동')) return const Color(0xFFFF9800);
    if (lower.contains('europe') || lower.contains('유럽')) return const Color(0xFF2196F3);
    if (lower.contains('america') || lower.contains('미주')) return const Color(0xFF9C27B0);
    if (lower.contains('africa') || lower.contains('아프리카')) return const Color(0xFFFF5722);
    if (lower.contains('국내') || lower.contains('korea')) return AppTheme.mintPrimary;
    return AppTheme.textSecondary;
  }
}

Widget _MiniTag(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 9)),
  );
}

class _GuideSection extends StatelessWidget {
  final String title;
  final List<String> items;
  const _GuideSection(this.title, this.items);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('• ', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            Expanded(child: Text(item, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          ]),
        )),
      ],
    ]);
  }
}

class _ColumnTable extends StatelessWidget {
  const _ColumnTable();

  static const _cols = [
    ('비즈니스 파트너', '고객사 고유 ID (BP 번호)', '필수'),
    ('이름 1', '고객사 공식 명칭', '필수'),
    ('바이어 번호', '내부 바이어 코드 (551-020 등)', '선택'),
    ('국가코드', 'ISO 2자리 국가코드 (VN, KR, AE)', '선택'),
    ('전화2', '연락처 전화번호', '선택'),
    ('판매 조직', '판매 조직 코드 (4200, 1100)', '선택'),
    ('내역4', '판매 조직명 (CTR Vina, CTR)', '선택'),
    ('유통경로', '유통 채널 코드 (11)', '선택'),
    ('통화', '거래 통화 (VND, USD, KRW)', '선택'),
    ('판매 구역', '판매 구역 코드', '선택'),
    ('인코텀스', '무역 조건 코드 (EXW, CIF, FOB)', '선택'),
    ('내역6', '인코텀스 설명', '선택'),
    ('판매처 / 청구처 / 납품처', '각 파티 번호 및 명칭 (6개 컬럼)', '선택'),
    ('결산기준유형 / 내역11', '정산 방식 및 설명', '선택'),
    ('PB오더구분', 'PB 오더 구분 플래그', '선택'),
    ('지역이름2', '권역 한글명 (아시아, 중동)', '선택'),
    ('D_Country.영문명', '국가 영문명 (Vietnam, UAE)', '선택'),
    ('D_지역.Region', '권역 영문명 (Asia & Pacific)', '선택'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1E3040)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1E2C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(children: [
              SizedBox(width: 160, child: Text('컬럼명', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
              Expanded(child: Text('설명', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
              SizedBox(width: 60, child: Text('필수여부', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
            ]),
          ),
          ..._cols.asMap().entries.map((e) {
            final isRequired = e.value.$3 == '필수';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: e.key.isEven ? Colors.transparent : const Color(0xFF0A1825),
                border: const Border(top: BorderSide(color: Color(0xFF1E3040), width: 0.5)),
              ),
              child: Row(children: [
                SizedBox(width: 160, child: Text(e.value.$1,
                    style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis)),
                Expanded(child: Text(e.value.$2,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10))),
                SizedBox(width: 60, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRequired
                        ? AppTheme.warning.withValues(alpha: 0.15)
                        : AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(e.value.$3,
                      style: TextStyle(
                        color: isRequired ? AppTheme.warning : AppTheme.textMuted,
                        fontSize: 9, fontWeight: FontWeight.w600,
                      )),
                )),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ResultItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, color: AppTheme.success, size: 14),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    );
  }
}
