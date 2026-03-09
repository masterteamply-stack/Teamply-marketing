// ════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════
enum MemberRole { owner, admin, editor, viewer }
enum TaskStatus { todo, inProgress, inReview, done }
enum TaskPriority { low, medium, high, urgent }

/// 주요 무역국 전체 통화 코드
enum CurrencyCode {
  krw,  // 한국 원
  usd,  // 미국 달러
  eur,  // 유로
  jpy,  // 일본 엔
  cny,  // 중국 위안
  gbp,  // 영국 파운드
  hkd,  // 홍콩 달러
  sgd,  // 싱가포르 달러
  aud,  // 호주 달러
  cad,  // 캐나다 달러
  chf,  // 스위스 프랑
  thb,  // 태국 바트
  vnd,  // 베트남 동
  aed,  // UAE 디르함
  rub,  // 러시아 루블
  inr,  // 인도 루피
  brl,  // 브라질 레알
  mxn,  // 멕시코 페소
  idr,  // 인도네시아 루피아
  myr,  // 말레이시아 링깃
  php,  // 필리핀 페소
  nzd,  // 뉴질랜드 달러
  sek,  // 스웨덴 크로나
  nok,  // 노르웨이 크로나
  dkk,  // 덴마크 크로나
  pln,  // 폴란드 즐로티
  try_,  // 터키 리라
  zar,  // 남아프리카 랜드
  sar,  // 사우디 리얄
  twd,  // 대만 달러
}

enum ProjectStatus { active, paused, completed, archived }

// 직책 (직위) enum
enum JobTitle {
  ceo, coo, cmo, director, teamLead, partLead, senior, member, intern, advisor
}

extension JobTitleExt on JobTitle {
  String get label {
    switch (this) {
      case JobTitle.ceo: return '대표';
      case JobTitle.coo: return '임원(COO)';
      case JobTitle.cmo: return '임원(CMO)';
      case JobTitle.director: return '이사';
      case JobTitle.teamLead: return '팀장';
      case JobTitle.partLead: return '파트장';
      case JobTitle.senior: return '선임';
      case JobTitle.member: return '팀원';
      case JobTitle.intern: return '인턴';
      case JobTitle.advisor: return '어드바이저';
    }
  }
}

// 전략 Pillar enum
enum StrategyPillar {
  growth, retention, awareness, conversion, loyalty, innovation, efficiency, partnership
}

extension StrategyPillarExt on StrategyPillar {
  String get label {
    switch (this) {
      case StrategyPillar.growth: return '성장';
      case StrategyPillar.retention: return '리텐션';
      case StrategyPillar.awareness: return '인지도';
      case StrategyPillar.conversion: return '전환';
      case StrategyPillar.loyalty: return '충성도';
      case StrategyPillar.innovation: return '혁신';
      case StrategyPillar.efficiency: return '효율화';
      case StrategyPillar.partnership: return '파트너십';
    }
  }
  String get icon {
    switch (this) {
      case StrategyPillar.growth: return '🚀';
      case StrategyPillar.retention: return '🔄';
      case StrategyPillar.awareness: return '📢';
      case StrategyPillar.conversion: return '⚡';
      case StrategyPillar.loyalty: return '💎';
      case StrategyPillar.innovation: return '💡';
      case StrategyPillar.efficiency: return '⚙️';
      case StrategyPillar.partnership: return '🤝';
    }
  }
  String get colorHex {
    switch (this) {
      case StrategyPillar.growth: return '#00BFA5';
      case StrategyPillar.retention: return '#29B6F6';
      case StrategyPillar.awareness: return '#AB47BC';
      case StrategyPillar.conversion: return '#FF7043';
      case StrategyPillar.loyalty: return '#FFB300';
      case StrategyPillar.innovation: return '#66BB6A';
      case StrategyPillar.efficiency: return '#5C6BC0';
      case StrategyPillar.partnership: return '#EF5350';
    }
  }
}

extension MemberRoleExt on MemberRole {
  String get label {
    switch (this) {
      case MemberRole.owner: return '오너';
      case MemberRole.admin: return '관리자';
      case MemberRole.editor: return '에디터';
      case MemberRole.viewer: return '뷰어';
    }
  }
  bool get canEdit => this == MemberRole.owner || this == MemberRole.admin || this == MemberRole.editor;
}

extension CurrencyExt on CurrencyCode {
  String get symbol {
    switch (this) {
      case CurrencyCode.krw: return '₩';
      case CurrencyCode.usd: return '\$';
      case CurrencyCode.eur: return '€';
      case CurrencyCode.jpy: return '¥';
      case CurrencyCode.cny: return '¥';
      case CurrencyCode.gbp: return '£';
      case CurrencyCode.hkd: return 'HK\$';
      case CurrencyCode.sgd: return 'S\$';
      case CurrencyCode.aud: return 'A\$';
      case CurrencyCode.cad: return 'C\$';
      case CurrencyCode.chf: return 'Fr';
      case CurrencyCode.thb: return '฿';
      case CurrencyCode.vnd: return '₫';
      case CurrencyCode.aed: return 'د.إ';
      case CurrencyCode.rub: return '₽';
      case CurrencyCode.inr: return '₹';
      case CurrencyCode.brl: return 'R\$';
      case CurrencyCode.mxn: return '\$';
      case CurrencyCode.idr: return 'Rp';
      case CurrencyCode.myr: return 'RM';
      case CurrencyCode.php: return '₱';
      case CurrencyCode.nzd: return 'NZ\$';
      case CurrencyCode.sek: return 'kr';
      case CurrencyCode.nok: return 'kr';
      case CurrencyCode.dkk: return 'kr';
      case CurrencyCode.pln: return 'zł';
      case CurrencyCode.try_: return '₺';
      case CurrencyCode.zar: return 'R';
      case CurrencyCode.sar: return '﷼';
      case CurrencyCode.twd: return 'NT\$';
    }
  }

  String get code {
    switch (this) {
      case CurrencyCode.krw: return 'KRW';
      case CurrencyCode.usd: return 'USD';
      case CurrencyCode.eur: return 'EUR';
      case CurrencyCode.jpy: return 'JPY';
      case CurrencyCode.cny: return 'CNY';
      case CurrencyCode.gbp: return 'GBP';
      case CurrencyCode.hkd: return 'HKD';
      case CurrencyCode.sgd: return 'SGD';
      case CurrencyCode.aud: return 'AUD';
      case CurrencyCode.cad: return 'CAD';
      case CurrencyCode.chf: return 'CHF';
      case CurrencyCode.thb: return 'THB';
      case CurrencyCode.vnd: return 'VND';
      case CurrencyCode.aed: return 'AED';
      case CurrencyCode.rub: return 'RUB';
      case CurrencyCode.inr: return 'INR';
      case CurrencyCode.brl: return 'BRL';
      case CurrencyCode.mxn: return 'MXN';
      case CurrencyCode.idr: return 'IDR';
      case CurrencyCode.myr: return 'MYR';
      case CurrencyCode.php: return 'PHP';
      case CurrencyCode.nzd: return 'NZD';
      case CurrencyCode.sek: return 'SEK';
      case CurrencyCode.nok: return 'NOK';
      case CurrencyCode.dkk: return 'DKK';
      case CurrencyCode.pln: return 'PLN';
      case CurrencyCode.try_: return 'TRY';
      case CurrencyCode.zar: return 'ZAR';
      case CurrencyCode.sar: return 'SAR';
      case CurrencyCode.twd: return 'TWD';
    }
  }

  String get label {
    switch (this) {
      case CurrencyCode.krw: return '한국 원 (KRW)';
      case CurrencyCode.usd: return '미국 달러 (USD)';
      case CurrencyCode.eur: return '유로 (EUR)';
      case CurrencyCode.jpy: return '일본 엔 (JPY)';
      case CurrencyCode.cny: return '중국 위안 (CNY)';
      case CurrencyCode.gbp: return '영국 파운드 (GBP)';
      case CurrencyCode.hkd: return '홍콩 달러 (HKD)';
      case CurrencyCode.sgd: return '싱가포르 달러 (SGD)';
      case CurrencyCode.aud: return '호주 달러 (AUD)';
      case CurrencyCode.cad: return '캐나다 달러 (CAD)';
      case CurrencyCode.chf: return '스위스 프랑 (CHF)';
      case CurrencyCode.thb: return '태국 바트 (THB)';
      case CurrencyCode.vnd: return '베트남 동 (VND)';
      case CurrencyCode.aed: return 'UAE 디르함 (AED)';
      case CurrencyCode.rub: return '러시아 루블 (RUB)';
      case CurrencyCode.inr: return '인도 루피 (INR)';
      case CurrencyCode.brl: return '브라질 레알 (BRL)';
      case CurrencyCode.mxn: return '멕시코 페소 (MXN)';
      case CurrencyCode.idr: return '인도네시아 루피아 (IDR)';
      case CurrencyCode.myr: return '말레이시아 링깃 (MYR)';
      case CurrencyCode.php: return '필리핀 페소 (PHP)';
      case CurrencyCode.nzd: return '뉴질랜드 달러 (NZD)';
      case CurrencyCode.sek: return '스웨덴 크로나 (SEK)';
      case CurrencyCode.nok: return '노르웨이 크로나 (NOK)';
      case CurrencyCode.dkk: return '덴마크 크로나 (DKK)';
      case CurrencyCode.pln: return '폴란드 즐로티 (PLN)';
      case CurrencyCode.try_: return '터키 리라 (TRY)';
      case CurrencyCode.zar: return '남아공 랜드 (ZAR)';
      case CurrencyCode.sar: return '사우디 리얄 (SAR)';
      case CurrencyCode.twd: return '대만 달러 (TWD)';
    }
  }

  /// 기본 KRW 환율 (참고용 - 실제는 ExchangeRateConfig 사용)
  double get defaultRateToKrw {
    switch (this) {
      case CurrencyCode.krw: return 1.0;
      case CurrencyCode.usd: return 1340.0;
      case CurrencyCode.eur: return 1460.0;
      case CurrencyCode.jpy: return 8.9;
      case CurrencyCode.cny: return 185.0;
      case CurrencyCode.gbp: return 1700.0;
      case CurrencyCode.hkd: return 172.0;
      case CurrencyCode.sgd: return 990.0;
      case CurrencyCode.aud: return 875.0;
      case CurrencyCode.cad: return 980.0;
      case CurrencyCode.chf: return 1510.0;
      case CurrencyCode.thb: return 37.5;
      case CurrencyCode.vnd: return 0.053;
      case CurrencyCode.aed: return 365.0;
      case CurrencyCode.rub: return 14.8;
      case CurrencyCode.inr: return 16.1;
      case CurrencyCode.brl: return 268.0;
      case CurrencyCode.mxn: return 78.0;
      case CurrencyCode.idr: return 0.084;
      case CurrencyCode.myr: return 286.0;
      case CurrencyCode.php: return 23.5;
      case CurrencyCode.nzd: return 805.0;
      case CurrencyCode.sek: return 126.0;
      case CurrencyCode.nok: return 122.0;
      case CurrencyCode.dkk: return 196.0;
      case CurrencyCode.pln: return 338.0;
      case CurrencyCode.try_: return 40.5;
      case CurrencyCode.zar: return 73.0;
      case CurrencyCode.sar: return 357.0;
      case CurrencyCode.twd: return 41.5;
    }
  }

  // 하위 호환 (기존 코드에서 rateToKrw 사용하는 경우)
  double get rateToKrw => defaultRateToKrw;

  // 기존 name getter 하위호환
  String get name => code;
}

// ════════════════════════════════════════════════════════
//  환율 설정 모델 (연도별 경영환율 + 집행환율)
// ════════════════════════════════════════════════════════

/// 연도별 경영환율 (프로젝트 단위 설정)
class AnnualExchangeRateConfig {
  final String year;           // 예: '2025'
  final String projectId;      // 프로젝트 ID
  final CurrencyCode baseCurrency;   // 종합분석 기준 통화 (보통 KRW 또는 USD)
  final Map<String, double> rates;   // currencyCode → 경영환율(KRW 기준)
  final DateTime updatedAt;

  AnnualExchangeRateConfig({
    required this.year,
    required this.projectId,
    required this.baseCurrency,
    required this.rates,
    required this.updatedAt,
  });

  double getRateFor(CurrencyCode currency) =>
      rates[currency.code] ?? currency.defaultRateToKrw;

  AnnualExchangeRateConfig copyWith({
    String? year, String? projectId, CurrencyCode? baseCurrency,
    Map<String, double>? rates,
  }) => AnnualExchangeRateConfig(
    year: year ?? this.year,
    projectId: projectId ?? this.projectId,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    rates: rates ?? Map.from(this.rates),
    updatedAt: DateTime.now(),
  );
}

/// 글로벌 환율 설정 (앱 전체)
class GlobalExchangeRateConfig {
  final Map<String, double> rates;  // currencyCode → KRW 환율
  final DateTime updatedAt;

  GlobalExchangeRateConfig({required this.rates, required this.updatedAt});

  double getRateFor(CurrencyCode currency) =>
      rates[currency.code] ?? currency.defaultRateToKrw;

  static GlobalExchangeRateConfig defaults() {
    final m = <String, double>{};
    for (final c in CurrencyCode.values) {
      m[c.code] = c.defaultRateToKrw;
    }
    return GlobalExchangeRateConfig(rates: m, updatedAt: DateTime.now());
  }
}

// ════════════════════════════════════════════════════════
//  USER / MEMBER
// ════════════════════════════════════════════════════════
class AppUser {
  final String id;
  String name;
  String? nickname;       // 닉네임 (선택)
  String email;
  String avatarInitials;
  String? avatarColor;
  JobTitle jobTitle;      // 직책/직위
  String? department;     // 부서

  AppUser({
    required this.id,
    required this.name,
    this.nickname,
    required this.email,
    required this.avatarInitials,
    this.avatarColor,
    this.jobTitle = JobTitle.member,
    this.department,
  });

  // 표시 이름: 닉네임 있으면 닉네임 우선
  String get displayName => nickname?.isNotEmpty == true ? nickname! : name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nickname': nickname,
    'email': email,
    'avatarInitials': avatarInitials,
    'avatarColor': avatarColor,
    'jobTitle': jobTitle.name,
    'department': department,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    nickname: j['nickname'] as String?,
    email: j['email'] as String? ?? '',
    avatarInitials: j['avatarInitials'] as String? ?? '',
    avatarColor: j['avatarColor'] as String?,
    jobTitle: JobTitle.values.firstWhere(
        (e) => e.name == j['jobTitle'], orElse: () => JobTitle.member),
    department: j['department'] as String?,
  );

  AppUser copyWith({
    String? name, String? nickname, String? email,
    String? avatarInitials, String? avatarColor,
    JobTitle? jobTitle, String? department,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    nickname: nickname ?? this.nickname,
    email: email ?? this.email,
    avatarInitials: avatarInitials ?? this.avatarInitials,
    avatarColor: avatarColor ?? this.avatarColor,
    jobTitle: jobTitle ?? this.jobTitle,
    department: department ?? this.department,
  );
}

class TeamMember {
  final String id;
  final AppUser user;
  final MemberRole role;
  final DateTime joinedAt;
  bool isActive;

  TeamMember({
    required this.id,
    required this.user,
    required this.role,
    required this.joinedAt,
    this.isActive = true,
  });

  TeamMember copyWith({MemberRole? role, bool? isActive}) => TeamMember(
    id: id, user: user,
    role: role ?? this.role,
    joinedAt: joinedAt,
    isActive: isActive ?? this.isActive,
  );
}

// ════════════════════════════════════════════════════════
//  TEAM
// ════════════════════════════════════════════════════════
class Team {
  final String id;
  String name;
  String description;
  String colorHex;
  String iconEmoji;
  final List<TeamMember> members;
  final List<String> projectIds;
  final DateTime createdAt;

  Team({
    required this.id,
    required this.name,
    required this.description,
    required this.colorHex,
    required this.iconEmoji,
    required this.members,
    required this.projectIds,
    required this.createdAt,
  });

  TeamMember? getMember(String userId) =>
      members.where((m) => m.user.id == userId).firstOrNull;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'colorHex': colorHex,
    'iconEmoji': iconEmoji,
    'members': members.map((m) => {
      'id': m.id,
      'userId': m.user.id,
      'role': m.role.name,
      'joinedAt': m.joinedAt.toIso8601String(),
      'isActive': m.isActive,
      'user': m.user.toJson(),
    }).toList(),
    'projectIds': projectIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Team.fromJson(Map<String, dynamic> j) {
    final members = (j['members'] as List<dynamic>? ?? []).map((m) {
      final mMap = m as Map<String, dynamic>;
      return TeamMember(
        id: mMap['id'] as String,
        user: AppUser.fromJson(mMap['user'] as Map<String, dynamic>),
        role: MemberRole.values.firstWhere(
            (e) => e.name == mMap['role'], orElse: () => MemberRole.viewer),
        joinedAt: DateTime.parse(mMap['joinedAt'] as String),
        isActive: mMap['isActive'] as bool? ?? true,
      );
    }).toList();
    return Team(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      colorHex: j['colorHex'] as String? ?? '#00BFA5',
      iconEmoji: j['iconEmoji'] as String? ?? '👥',
      members: members,
      projectIds: List<String>.from(j['projectIds'] as List? ?? []),
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

// ════════════════════════════════════════════════════════
//  CHECKLIST ITEM
// ════════════════════════════════════════════════════════
class ChecklistItem {
  final String id;
  String title;
  bool isDone;
  String? assigneeId;
  DateTime? dueDate;

  // ── 고객사·지역·예산 연결 ─────────────────────────
  String? clientId;          // 연결 고객사 ID
  String? region;            // 권역 (예: '동남아', '중동')
  String? country;           // 국가 코드 (예: 'KR', 'SG')
  double? allocatedBudget;   // 이 항목에 할당된 예산 (원 기준)
  double? executedAmount;    // 실제 집행 금액 (원 기준)
  CurrencyCode? currency;    // 예산 통화
  String? costNote;          // 비용 메모

  ChecklistItem({
    required this.id,
    required this.title,
    this.isDone = false,
    this.assigneeId,
    this.dueDate,
    this.clientId,
    this.region,
    this.country,
    this.allocatedBudget,
    this.executedAmount,
    this.currency,
    this.costNote,
  });

  double get budgetUsageRate {
    if (allocatedBudget == null || allocatedBudget! <= 0) return 0;
    return ((executedAmount ?? 0) / allocatedBudget! * 100).clamp(0, 200);
  }

  double get remainingBudget => (allocatedBudget ?? 0) - (executedAmount ?? 0);

  ChecklistItem copyWith({
    String? title, bool? isDone, String? assigneeId, DateTime? dueDate,
    String? clientId, String? region, String? country,
    double? allocatedBudget, double? executedAmount,
    CurrencyCode? currency, String? costNote,
  }) => ChecklistItem(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    assigneeId: assigneeId ?? this.assigneeId,
    dueDate: dueDate ?? this.dueDate,
    clientId: clientId ?? this.clientId,
    region: region ?? this.region,
    country: country ?? this.country,
    allocatedBudget: allocatedBudget ?? this.allocatedBudget,
    executedAmount: executedAmount ?? this.executedAmount,
    currency: currency ?? this.currency,
    costNote: costNote ?? this.costNote,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'isDone': isDone,
    'assigneeId': assigneeId,
    'dueDate': dueDate?.toIso8601String(),
    'clientId': clientId, 'region': region, 'country': country,
    'allocatedBudget': allocatedBudget, 'executedAmount': executedAmount,
    'currency': currency?.name, 'costNote': costNote,
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    isDone: j['isDone'] as bool? ?? false,
    assigneeId: j['assigneeId'] as String?,
    dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate'] as String) : null,
    clientId: j['clientId'] as String?,
    region: j['region'] as String?,
    country: j['country'] as String?,
    allocatedBudget: (j['allocatedBudget'] as num?)?.toDouble(),
    executedAmount: (j['executedAmount'] as num?)?.toDouble(),
    currency: j['currency'] != null ? CurrencyCode.values.firstWhere(
        (e) => e.name == j['currency'], orElse: () => CurrencyCode.krw) : null,
    costNote: j['costNote'] as String?,
  );
}

// ════════════════════════════════════════════════════════
//  SCHEDULE ITEM
// ════════════════════════════════════════════════════════
class ScheduleItem {
  final String id;
  String title;
  DateTime startDate;
  DateTime endDate;
  bool isDone;
  String? color;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.isDone = false,
    this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'isDone': isDone, 'color': color,
  };

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    startDate: j['startDate'] != null ? DateTime.parse(j['startDate'] as String) : DateTime.now(),
    endDate: j['endDate'] != null ? DateTime.parse(j['endDate'] as String) : DateTime.now(),
    isDone: j['isDone'] as bool? ?? false,
    color: j['color'] as String?,
  );
}

// ════════════════════════════════════════════════════════
//  COST BUDGET (비용 집행)
// ════════════════════════════════════════════════════════
class CostEntry {
  final String id;
  String title;
  double amount;
  CurrencyCode currency;
  DateTime date;
  String category; // '광고비','인건비','외주','툴/소프트웨어','기타'
  String? note;
  bool isExecuted;
  double? executionRate;     // 집행 시 실제 적용 환율 (KRW 기준, null이면 경영환율 사용)
  String? executionRateNote; // 집행환율 메모 (예: '실시간 환율 적용')

  // ── 지역/권역/고객 할당 ──────────────────────────
  String? region;       // 마케팅 권역 (예: '동남아', '중동', '북미')
  String? country;      // 나라 코드 or 이름 (예: 'KR', 'US', 'VN')
  String? clientId;     // 고객사 ID (ClientAccount.id)
  String? assignedTo;   // 담당자 userId

  CostEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.date,
    required this.category,
    this.note,
    this.isExecuted = false,
    this.executionRate,
    this.executionRateNote,
    this.region,
    this.country,
    this.clientId,
    this.assignedTo,
  });

  /// 집행환율 우선, 없으면 기본환율
  double get effectiveRateToKrw => executionRate ?? currency.defaultRateToKrw;

  double get amountInKrw => amount * effectiveRateToKrw;

  /// USD 환산 (KRW → USD)
  double amountInUsd(double usdRateToKrw) =>
      usdRateToKrw > 0 ? amountInKrw / usdRateToKrw : 0;

  CostEntry copyWith({
    String? title, double? amount, CurrencyCode? currency,
    DateTime? date, String? category, String? note, bool? isExecuted,
    double? executionRate, String? executionRateNote,
    String? region, String? country, String? clientId, String? assignedTo,
  }) => CostEntry(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    date: date ?? this.date,
    category: category ?? this.category,
    note: note ?? this.note,
    isExecuted: isExecuted ?? this.isExecuted,
    executionRate: executionRate ?? this.executionRate,
    executionRateNote: executionRateNote ?? this.executionRateNote,
    region: region ?? this.region,
    country: country ?? this.country,
    clientId: clientId ?? this.clientId,
    assignedTo: assignedTo ?? this.assignedTo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'currency': currency.name,
    'date': date.toIso8601String(),
    'category': category,
    'note': note,
    'isExecuted': isExecuted,
    'executionRate': executionRate,
    'executionRateNote': executionRateNote,
    'region': region,
    'country': country,
    'clientId': clientId,
    'assignedTo': assignedTo,
  };

  factory CostEntry.fromJson(Map<String, dynamic> j) => CostEntry(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    currency: CurrencyCode.values.firstWhere(
        (e) => e.name == j['currency'], orElse: () => CurrencyCode.krw),
    date: j['date'] != null ? DateTime.parse(j['date'] as String) : DateTime.now(),
    category: j['category'] as String? ?? '기타',
    note: j['note'] as String?,
    isExecuted: j['isExecuted'] as bool? ?? false,
    executionRate: (j['executionRate'] as num?)?.toDouble(),
    executionRateNote: j['executionRateNote'] as String?,
    region: j['region'] as String?,
    country: j['country'] as String?,
    clientId: j['clientId'] as String?,
    assignedTo: j['assignedTo'] as String?,
  );
}

class BudgetConfig {
  double totalBudget;
  CurrencyCode currency;
  double exchangeRateToKrw;

  BudgetConfig({
    required this.totalBudget,
    required this.currency,
    required this.exchangeRateToKrw,
  });

  double get totalInKrw => totalBudget * exchangeRateToKrw;

  double totalInUsd(double usdRateToKrw) =>
      usdRateToKrw > 0 ? totalInKrw / usdRateToKrw : 0;

  Map<String, dynamic> toJson() => {
    'totalBudget': totalBudget,
    'currency': currency.name,
    'exchangeRateToKrw': exchangeRateToKrw,
  };

  factory BudgetConfig.fromJson(Map<String, dynamic> j) => BudgetConfig(
    totalBudget: (j['totalBudget'] as num?)?.toDouble() ?? 0,
    currency: CurrencyCode.values.firstWhere(
        (e) => e.name == j['currency'], orElse: () => CurrencyCode.krw),
    exchangeRateToKrw: (j['exchangeRateToKrw'] as num?)?.toDouble() ?? 1,
  );
}

// ════════════════════════════════════════════════════════
//  MENTION
// ════════════════════════════════════════════════════════
class Mention {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String message;
  final DateTime createdAt;
  bool isRead;

  Mention({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}

// ════════════════════════════════════════════════════════
//  TASK DETAIL
// ════════════════════════════════════════════════════════
class TaskDetail {
  final String id;
  String title;
  String description;
  TaskStatus status;
  TaskPriority priority;
  final String createdBy;
  final List<String> assigneeIds;
  final List<String> mentionedUserIds;
  final List<ChecklistItem> checklist;
  final List<ScheduleItem> schedules;
  final List<CostEntry> costEntries;
  BudgetConfig? budget;
  final List<String> tags;
  DateTime? startDate;
  DateTime? dueDate;
  String? kpiId;
  StrategyPillar? pillar;         // 전략 Pillar 연결
  final List<TaskKpiTarget> kpiTargets;  // 태스크별 월별 KPI 목표
  final List<TaskComment> comments;      // 코멘트 목록
  final List<TaskAttachment> attachments; // 첨부파일 & 링크
  final DateTime createdAt;
  DateTime updatedAt;

  // ── CSV 가져오기 확장 필드 ───────────────────────────────
  String? externalId;   // 외부 시스템 ID (e.g. B2D-01)
  int?    year;         // 대상 연도 (e.g. 2026)
  double? target;       // KPI 목표값 (e.g. 24)
  String? unit;         // 목표값 단위 (e.g. EA, 건)
  String? theme;        // 테마/서브 카테고리 (e.g. Brand Equity)
  String? ownerName;    // 담당자 이름(CSV Owner 열)

  // ── 태스크 레벨 고객사·지역 기본값 ──────────────────────
  String? defaultClientId;   // 이 태스크의 기본 고객사 ID
  String? defaultRegion;     // 기본 권역
  String? defaultCountry;    // 기본 국가
  double? taskAllocatedBudget;  // 태스크 전체 할당 예산 (원 기준)
  CurrencyCode? taskBudgetCurrency; // 태스크 예산 통화

  TaskDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdBy,
    required this.assigneeIds,
    required this.mentionedUserIds,
    required this.checklist,
    required this.schedules,
    required this.costEntries,
    this.budget,
    required this.tags,
    this.startDate,
    this.dueDate,
    this.kpiId,
    this.pillar,
    List<TaskKpiTarget>? kpiTargets,
    List<TaskComment>? comments,
    List<TaskAttachment>? attachments,
    required this.createdAt,
    required this.updatedAt,
    this.externalId,
    this.year,
    this.target,
    this.unit,
    this.theme,
    this.ownerName,
    this.defaultClientId,
    this.defaultRegion,
    this.defaultCountry,
    this.taskAllocatedBudget,
    this.taskBudgetCurrency,
  }) : kpiTargets = kpiTargets ?? [],
       comments = comments ?? [],
       attachments = attachments ?? [];

  // 체크리스트 완성률
  double get checklistProgress {
    if (checklist.isEmpty) return 0;
    return checklist.where((c) => c.isDone).length / checklist.length * 100;
  }

  // 비용 집행률 (KRW 기준)
  double get costExecutionRate {
    if (budget == null || budget!.totalInKrw == 0) return 0;
    final executed = costEntries.where((c) => c.isExecuted).fold(0.0, (s, c) => s + c.amountInKrw);
    return (executed / budget!.totalInKrw * 100).clamp(0, 200);
  }

  double get totalBudgetKrw => budget?.totalInKrw ?? 0;
  double get executedAmountKrw =>
      costEntries.where((c) => c.isExecuted).fold(0.0, (s, c) => s + c.amountInKrw);
  double get plannedAmountKrw =>
      costEntries.fold(0.0, (s, c) => s + c.amountInKrw);
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && status != TaskStatus.done;

  // ── 체크리스트 항목 기준 예산 집계 ──────────────────────
  double get checklistTotalAllocated =>
      checklist.fold(0.0, (s, c) => s + (c.allocatedBudget ?? 0));
  double get checklistTotalExecuted =>
      checklist.fold(0.0, (s, c) => s + (c.executedAmount ?? 0));
  double get checklistBudgetUsageRate {
    if (checklistTotalAllocated <= 0) return 0;
    return (checklistTotalExecuted / checklistTotalAllocated * 100).clamp(0, 200);
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'status': status.name, 'priority': priority.name,
    'createdBy': createdBy, 'assigneeIds': assigneeIds,
    'mentionedUserIds': mentionedUserIds,
    'checklist': checklist.map((c) => c.toJson()).toList(),
    'schedules': schedules.map((s) => s.toJson()).toList(),
    'costEntries': costEntries.map((c) => c.toJson()).toList(),
    'budget': budget?.toJson(),
    'tags': tags,
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'kpiId': kpiId, 'pillar': pillar?.name,
    'kpiTargets': kpiTargets.map((k) => k.toJson()).toList(),
    'comments': comments.map((c) => c.toJson()).toList(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'externalId': externalId, 'year': year,
    'target': target, 'unit': unit, 'theme': theme, 'ownerName': ownerName,
    'defaultClientId': defaultClientId, 'defaultRegion': defaultRegion,
    'defaultCountry': defaultCountry,
    'taskAllocatedBudget': taskAllocatedBudget,
    'taskBudgetCurrency': taskBudgetCurrency?.name,
  };

  factory TaskDetail.fromJson(Map<String, dynamic> j) => TaskDetail(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    status: TaskStatus.values.firstWhere(
        (e) => e.name == j['status'], orElse: () => TaskStatus.todo),
    priority: TaskPriority.values.firstWhere(
        (e) => e.name == j['priority'], orElse: () => TaskPriority.medium),
    createdBy: j['createdBy'] as String? ?? '',
    assigneeIds: List<String>.from(j['assigneeIds'] as List? ?? []),
    mentionedUserIds: List<String>.from(j['mentionedUserIds'] as List? ?? []),
    checklist: (j['checklist'] as List<dynamic>? ?? [])
        .map((c) => ChecklistItem.fromJson(c as Map<String, dynamic>)).toList(),
    schedules: (j['schedules'] as List<dynamic>? ?? [])
        .map((s) => ScheduleItem.fromJson(s as Map<String, dynamic>)).toList(),
    costEntries: (j['costEntries'] as List<dynamic>? ?? [])
        .map((c) => CostEntry.fromJson(c as Map<String, dynamic>)).toList(),
    budget: j['budget'] != null
        ? BudgetConfig.fromJson(j['budget'] as Map<String, dynamic>) : null,
    tags: List<String>.from(j['tags'] as List? ?? []),
    startDate: j['startDate'] != null ? DateTime.parse(j['startDate'] as String) : null,
    dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate'] as String) : null,
    kpiId: j['kpiId'] as String?,
    pillar: j['pillar'] != null ? StrategyPillar.values.firstWhere(
        (e) => e.name == j['pillar'], orElse: () => StrategyPillar.growth) : null,
    kpiTargets: (j['kpiTargets'] as List<dynamic>? ?? [])
        .map((k) => TaskKpiTarget.fromJson(k as Map<String, dynamic>)).toList(),
    comments: (j['comments'] as List<dynamic>? ?? [])
        .map((c) => TaskComment.fromJson(c as Map<String, dynamic>)).toList(),
    attachments: (j['attachments'] as List<dynamic>? ?? [])
        .map((a) => TaskAttachment.fromJson(a as Map<String, dynamic>)).toList(),
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : DateTime.now(),
    updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt'] as String) : DateTime.now(),
    externalId: j['externalId'] as String?,
    year: j['year'] as int?,
    target: (j['target'] as num?)?.toDouble(),
    unit: j['unit'] as String?,
    theme: j['theme'] as String?,
    ownerName: j['ownerName'] as String?,
    defaultClientId: j['defaultClientId'] as String?,
    defaultRegion: j['defaultRegion'] as String?,
    defaultCountry: j['defaultCountry'] as String?,
    taskAllocatedBudget: (j['taskAllocatedBudget'] as num?)?.toDouble(),
    taskBudgetCurrency: j['taskBudgetCurrency'] != null
        ? CurrencyCode.values.firstWhere(
            (e) => e.name == j['taskBudgetCurrency'], orElse: () => CurrencyCode.krw) : null,
  );
}

// ════════════════════════════════════════════════════════
//  PROJECT
// ════════════════════════════════════════════════════════
class Project {
  final String id;
  String name;
  String description;
  String category;
  ProjectStatus status;
  final String teamId;
  final String ownerId;
  final List<String> memberIds;
  final List<TaskDetail> tasks;
  BudgetConfig? budget;
  final List<CostEntry> projectCosts;
  String colorHex;
  String iconEmoji;
  final DateTime createdAt;
  DateTime? dueDate;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.status,
    required this.teamId,
    required this.ownerId,
    required this.memberIds,
    required this.tasks,
    this.budget,
    required this.projectCosts,
    required this.colorHex,
    required this.iconEmoji,
    required this.createdAt,
    this.dueDate,
  });

  double get completionRate {
    if (tasks.isEmpty) return 0;
    return tasks.where((t) => t.status == TaskStatus.done).length / tasks.length * 100;
  }

  double get totalBudgetKrw => budget?.totalInKrw ?? 0;
  double get executedCostKrw =>
      projectCosts.where((c) => c.isExecuted).fold(0.0, (s, c) => s + c.amountInKrw) +
      tasks.fold(0.0, (s, t) => s + t.executedAmountKrw);
  double get budgetUsageRate =>
      totalBudgetKrw > 0 ? (executedCostKrw / totalBudgetKrw * 100).clamp(0, 200) : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'status': status.name,
    'teamId': teamId,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'budget': budget?.toJson(),
    'projectCosts': projectCosts.map((c) => c.toJson()).toList(),
    'colorHex': colorHex,
    'iconEmoji': iconEmoji,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
  };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    category: j['category'] as String? ?? '',
    status: ProjectStatus.values.firstWhere(
        (e) => e.name == j['status'], orElse: () => ProjectStatus.active),
    teamId: j['teamId'] as String? ?? '',
    ownerId: j['ownerId'] as String? ?? '',
    memberIds: List<String>.from(j['memberIds'] as List? ?? []),
    tasks: (j['tasks'] as List<dynamic>? ?? [])
        .map((t) => TaskDetail.fromJson(t as Map<String, dynamic>))
        .toList(),
    budget: j['budget'] != null
        ? BudgetConfig.fromJson(j['budget'] as Map<String, dynamic>)
        : null,
    projectCosts: (j['projectCosts'] as List<dynamic>? ?? [])
        .map((c) => CostEntry.fromJson(c as Map<String, dynamic>))
        .toList(),
    colorHex: j['colorHex'] as String? ?? '#00BFA5',
    iconEmoji: j['iconEmoji'] as String? ?? '📁',
    createdAt: DateTime.parse(j['createdAt'] as String),
    dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate'] as String) : null,
  );
}

// ════════════════════════════════════════════════════════
//  KPI / FUNNEL (기존 호환)
// ════════════════════════════════════════════════════════
class KpiModel {
  final String id;
  String title;
  String category;
  double target;
  double current;
  String unit;
  String period;
  String? assignedTo;
  bool isTeamKpi;
  DateTime dueDate;
  String? teamId;
  String? projectId;
  StrategyPillar? pillar;      // 전략 Pillar
  String? pillarDescription;   // Pillar 설명

  KpiModel({
    required this.id,
    required this.title,
    required this.category,
    required this.target,
    required this.current,
    required this.unit,
    required this.period,
    this.assignedTo,
    required this.isTeamKpi,
    required this.dueDate,
    this.teamId,
    this.projectId,
    this.pillar,
    this.pillarDescription,
  });

  double get achievementRate => target > 0 ? (current / target * 100).clamp(0, 200) : 0;
  bool get isOnTrack => achievementRate >= 80;

  KpiModel copyWith({
    String? title, String? category, double? target, double? current,
    String? unit, String? period, String? assignedTo, bool? isTeamKpi,
    DateTime? dueDate, String? teamId, String? projectId,
    StrategyPillar? pillar, String? pillarDescription,
  }) => KpiModel(
    id: id,
    title: title ?? this.title,
    category: category ?? this.category,
    target: target ?? this.target,
    current: current ?? this.current,
    unit: unit ?? this.unit,
    period: period ?? this.period,
    assignedTo: assignedTo ?? this.assignedTo,
    isTeamKpi: isTeamKpi ?? this.isTeamKpi,
    dueDate: dueDate ?? this.dueDate,
    teamId: teamId ?? this.teamId,
    projectId: projectId ?? this.projectId,
    pillar: pillar ?? this.pillar,
    pillarDescription: pillarDescription ?? this.pillarDescription,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'target': target,
    'current': current,
    'unit': unit,
    'period': period,
    'assignedTo': assignedTo,
    'isTeamKpi': isTeamKpi,
    'dueDate': dueDate.toIso8601String(),
    'teamId': teamId,
    'projectId': projectId,
    'pillar': pillar?.name,
    'pillarDescription': pillarDescription,
  };

  factory KpiModel.fromJson(Map<String, dynamic> j) => KpiModel(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    category: j['category'] as String? ?? '',
    target: (j['target'] as num?)?.toDouble() ?? 0,
    current: (j['current'] as num?)?.toDouble() ?? 0,
    unit: j['unit'] as String? ?? '',
    period: j['period'] as String? ?? '',
    assignedTo: j['assignedTo'] as String?,
    isTeamKpi: j['isTeamKpi'] as bool? ?? false,
    dueDate: j['dueDate'] != null
        ? DateTime.parse(j['dueDate'] as String)
        : DateTime.now(),
    teamId: j['teamId'] as String?,
    projectId: j['projectId'] as String?,
    pillar: j['pillar'] != null
        ? StrategyPillar.values.firstWhere(
            (e) => e.name == j['pillar'], orElse: () => StrategyPillar.growth)
        : null,
    pillarDescription: j['pillarDescription'] as String?,
  );
}

class FunnelStage {
  final String name, label, icon;
  final double value, previousValue;
  FunnelStage({required this.name, required this.label, required this.value,
    required this.previousValue, required this.icon});
  double get conversionRate => previousValue > 0 ? (value / previousValue * 100) : 100;
  double get dropOffRate => 100 - conversionRate;
}

class MonthlyData {
  final String month;      // 표시용 레이블 ('1월', '10월' 등)
  final String? monthKey;  // 정렬/필터용 키 ('2025-01', '2024-10' 등)
  final double revenue, adSpend;
  final int leads;
  MonthlyData({required this.month, this.monthKey, required this.revenue, required this.adSpend, required this.leads});
  double get roi => adSpend > 0 ? ((revenue - adSpend) / adSpend * 100) : 0;
}

class MonthlyKpiRecord {
  final String kpiId, month, monthLabel, unit;
  final double target, actual;
  MonthlyKpiRecord({required this.kpiId, required this.month, required this.monthLabel,
    required this.target, required this.actual, required this.unit});
  double get achievementRate => target > 0 ? (actual / target * 100).clamp(0, 200) : 0;
  bool get isOnTrack => achievementRate >= 80;
  double get gap => actual - target;
}

class RiskItem {
  final String id, title, type, assignedTo, riskLevel, reason;
  final double riskScore;
  final DateTime? dueDate;
  final double? progressPercent, kpiAchievementRate;
  RiskItem({required this.id, required this.title, required this.type,
    required this.assignedTo, required this.riskScore, required this.riskLevel,
    required this.reason, this.dueDate, this.progressPercent, this.kpiAchievementRate});
}

// ════════════════════════════════════════════════════════
//  TASK COMMENT (태스크 코멘트)
// ════════════════════════════════════════════════════════
class TaskComment {
  final String id;
  final String taskId;
  final String authorId;
  String content;
  final List<String> mentionedUserIds; // @멘션된 유저 ID
  final DateTime createdAt;
  DateTime updatedAt;
  bool isEdited;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.content,
    required this.mentionedUserIds,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'taskId': taskId, 'authorId': authorId, 'content': content,
    'mentionedUserIds': mentionedUserIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isEdited': isEdited,
  };

  factory TaskComment.fromJson(Map<String, dynamic> j) => TaskComment(
    id: j['id'] as String,
    taskId: j['taskId'] as String? ?? '',
    authorId: j['authorId'] as String? ?? '',
    content: j['content'] as String? ?? '',
    mentionedUserIds: List<String>.from(j['mentionedUserIds'] as List? ?? []),
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : DateTime.now(),
    updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt'] as String) : DateTime.now(),
    isEdited: j['isEdited'] as bool? ?? false,
  );
}

// ════════════════════════════════════════════════════════
//  TASK ATTACHMENT (태스크 첨부파일 & 링크)
// ════════════════════════════════════════════════════════

/// 첨부파일/링크의 출처 유형
enum AttachmentSourceType {
  file,         // 직접 업로드 파일 (웹 기준 URL 저장)
  link,         // 외부 URL 링크
  googleDrive,  // Google Drive 링크
  oneDrive,     // Microsoft OneDrive 링크
  email,        // 이메일 링크
}

extension AttachmentSourceTypeX on AttachmentSourceType {
  String get label {
    switch (this) {
      case AttachmentSourceType.file:        return '파일';
      case AttachmentSourceType.link:        return '링크';
      case AttachmentSourceType.googleDrive: return 'Google Drive';
      case AttachmentSourceType.oneDrive:    return 'OneDrive';
      case AttachmentSourceType.email:       return '이메일';
    }
  }
  String get emoji {
    switch (this) {
      case AttachmentSourceType.file:        return '📎';
      case AttachmentSourceType.link:        return '🔗';
      case AttachmentSourceType.googleDrive: return '📂';
      case AttachmentSourceType.oneDrive:    return '☁️';
      case AttachmentSourceType.email:       return '📧';
    }
  }
}

/// 파일 종류 (확장자/MIME 기반)
enum AttachmentFileType {
  pdf, ppt, word, excel, image, video, audio,
  code, zip, csv, text, link, unknown,
}

extension AttachmentFileTypeX on AttachmentFileType {
  String get label {
    switch (this) {
      case AttachmentFileType.pdf:     return 'PDF';
      case AttachmentFileType.ppt:     return 'PPT';
      case AttachmentFileType.word:    return 'Word';
      case AttachmentFileType.excel:   return 'Excel';
      case AttachmentFileType.image:   return '이미지';
      case AttachmentFileType.video:   return '동영상';
      case AttachmentFileType.audio:   return '오디오';
      case AttachmentFileType.code:    return '소스코드';
      case AttachmentFileType.zip:     return 'ZIP';
      case AttachmentFileType.csv:     return 'CSV';
      case AttachmentFileType.text:    return '텍스트';
      case AttachmentFileType.link:    return '링크';
      case AttachmentFileType.unknown: return '파일';
    }
  }
  /// 파일 아이콘 이모지
  String get icon {
    switch (this) {
      case AttachmentFileType.pdf:     return '📄';
      case AttachmentFileType.ppt:     return '📊';
      case AttachmentFileType.word:    return '📝';
      case AttachmentFileType.excel:   return '📈';
      case AttachmentFileType.image:   return '🖼️';
      case AttachmentFileType.video:   return '🎬';
      case AttachmentFileType.audio:   return '🎵';
      case AttachmentFileType.code:    return '💻';
      case AttachmentFileType.zip:     return '📦';
      case AttachmentFileType.csv:     return '📋';
      case AttachmentFileType.text:    return '📃';
      case AttachmentFileType.link:    return '🔗';
      case AttachmentFileType.unknown: return '📎';
    }
  }
  /// 배경 색상 (hex)
  String get colorHex {
    switch (this) {
      case AttachmentFileType.pdf:     return '#FF5252';
      case AttachmentFileType.ppt:     return '#FF6D00';
      case AttachmentFileType.word:    return '#2196F3';
      case AttachmentFileType.excel:   return '#4CAF50';
      case AttachmentFileType.image:   return '#AB47BC';
      case AttachmentFileType.video:   return '#00BCD4';
      case AttachmentFileType.audio:   return '#FF4081';
      case AttachmentFileType.code:    return '#607D8B';
      case AttachmentFileType.zip:     return '#795548';
      case AttachmentFileType.csv:     return '#009688';
      case AttachmentFileType.text:    return '#90A4AE';
      case AttachmentFileType.link:    return '#29B6F6';
      case AttachmentFileType.unknown: return '#546E7A';
    }
  }

  /// 확장자 → 유형 추론
  static AttachmentFileType fromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return AttachmentFileType.pdf;
      case 'ppt': case 'pptx': return AttachmentFileType.ppt;
      case 'doc': case 'docx': return AttachmentFileType.word;
      case 'xls': case 'xlsx': return AttachmentFileType.excel;
      case 'csv': return AttachmentFileType.csv;
      case 'jpg': case 'jpeg': case 'png': case 'gif':
      case 'webp': case 'svg': return AttachmentFileType.image;
      case 'mp4': case 'mov': case 'avi': case 'mkv':
      case 'webm': return AttachmentFileType.video;
      case 'mp3': case 'wav': case 'ogg': case 'm4a': return AttachmentFileType.audio;
      case 'js': case 'ts': case 'dart': case 'py':
      case 'java': case 'kt': case 'swift': case 'go':
      case 'cpp': case 'c': case 'cs': case 'rb': return AttachmentFileType.code;
      case 'zip': case 'tar': case 'gz': case 'rar': return AttachmentFileType.zip;
      case 'txt': case 'md': return AttachmentFileType.text;
      default: return AttachmentFileType.unknown;
    }
  }
}

class TaskAttachment {
  final String id;
  String name;           // 표시 이름 (사용자가 편집 가능)
  String url;            // 파일 URL 또는 외부 링크
  AttachmentFileType fileType;
  AttachmentSourceType sourceType;
  String? description;   // 간단한 설명
  String? checklistItemId; // 특정 체크리스트 항목에 연결 (optional)
  final String uploadedBy;
  final DateTime createdAt;
  int? fileSizeBytes;    // 파일 크기 (파일 업로드 시)

  TaskAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.fileType,
    required this.sourceType,
    this.description,
    this.checklistItemId,
    required this.uploadedBy,
    required this.createdAt,
    this.fileSizeBytes,
  });

  /// URL에서 파일 타입 추론
  static AttachmentFileType inferFileType(String url, AttachmentSourceType source) {
    if (source == AttachmentSourceType.link ||
        source == AttachmentSourceType.googleDrive ||
        source == AttachmentSourceType.oneDrive ||
        source == AttachmentSourceType.email) {
      // 클라우드/링크는 URL의 확장자로 추론
      final ext = url.split('.').last.split('?').first;
      final inferred = AttachmentFileTypeX.fromExtension(ext);
      if (inferred != AttachmentFileType.unknown) return inferred;
      return AttachmentFileType.link;
    }
    final ext = url.split('.').last.split('?').first;
    return AttachmentFileTypeX.fromExtension(ext);
  }

  /// 파일 크기 포맷
  String get fileSizeLabel {
    if (fileSizeBytes == null) return '';
    final b = fileSizeBytes!;
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'url': url,
    'fileType': fileType.name, 'sourceType': sourceType.name,
    'description': description, 'checklistItemId': checklistItemId,
    'uploadedBy': uploadedBy,
    'createdAt': createdAt.toIso8601String(),
    'fileSizeBytes': fileSizeBytes,
  };

  factory TaskAttachment.fromJson(Map<String, dynamic> j) => TaskAttachment(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    url: j['url'] as String? ?? '',
    fileType: AttachmentFileType.values.firstWhere(
        (e) => e.name == j['fileType'], orElse: () => AttachmentFileType.unknown),
    sourceType: AttachmentSourceType.values.firstWhere(
        (e) => e.name == j['sourceType'], orElse: () => AttachmentSourceType.link),
    description: j['description'] as String?,
    checklistItemId: j['checklistItemId'] as String?,
    uploadedBy: j['uploadedBy'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : DateTime.now(),
    fileSizeBytes: j['fileSizeBytes'] as int?,
  );
}

// ════════════════════════════════════════════════════════
//  DM MESSAGE (다이렉트 메시지)
// ════════════════════════════════════════════════════════
class DmMessage {
  final String id;
  final String fromUserId;
  final String toUserId;
  String content;
  final DateTime createdAt;
  bool isRead;

  DmMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });
}

// DM 대화방
class DmConversation {
  final String id;
  final String userId1;
  final String userId2;
  final List<DmMessage> messages;
  DateTime lastActivity;

  DmConversation({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.messages,
    required this.lastActivity,
  });

  String otherUserId(String myId) => myId == userId1 ? userId2 : userId1;
  DmMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
  int unreadCount(String myId) => messages.where((m) => m.toUserId == myId && !m.isRead).length;
}

// ════════════════════════════════════════════════════════
//  APP NOTIFICATION (알림)
// ════════════════════════════════════════════════════════
enum NotificationType { mention, comment, dm, taskAssigned, taskDue, kpiAlert, teamInvite }

class AppNotification {
  final String id;
  final String toUserId;
  final String fromUserId;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedId;    // taskId / kpiId / dmId 등
  final String? relatedType;  // 'task' | 'kpi' | 'dm'
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.toUserId,
    required this.fromUserId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    this.relatedType,
    required this.createdAt,
    this.isRead = false,
  });
}

// ════════════════════════════════════════════════════════
//  TASK KPI TARGET (태스크별 월별 KPI 목표)
// ════════════════════════════════════════════════════════
class TaskKpiTarget {
  final String id;
  final String taskId;
  String kpiName;           // KPI 이름 (자유 설정)
  String unit;              // 단위 (억원, %, 건, 명 등)
  String? linkedKpiId;      // 연결된 전체 KPI ID (선택)
  StrategyPillar? pillar;   // 연결 Pillar
  final List<MonthlyKpiEntry> monthlyTargets; // 월별 목표/실적

  TaskKpiTarget({
    required this.id,
    required this.taskId,
    required this.kpiName,
    required this.unit,
    this.linkedKpiId,
    this.pillar,
    required this.monthlyTargets,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'taskId': taskId, 'kpiName': kpiName, 'unit': unit,
    'linkedKpiId': linkedKpiId, 'pillar': pillar?.name,
    'monthlyTargets': monthlyTargets.map((m) => m.toJson()).toList(),
  };

  factory TaskKpiTarget.fromJson(Map<String, dynamic> j) => TaskKpiTarget(
    id: j['id'] as String,
    taskId: j['taskId'] as String? ?? '',
    kpiName: j['kpiName'] as String? ?? '',
    unit: j['unit'] as String? ?? '',
    linkedKpiId: j['linkedKpiId'] as String?,
    pillar: j['pillar'] != null ? StrategyPillar.values.firstWhere(
        (e) => e.name == j['pillar'], orElse: () => StrategyPillar.growth) : null,
    monthlyTargets: (j['monthlyTargets'] as List<dynamic>? ?? [])
        .map((m) => MonthlyKpiEntry.fromJson(m as Map<String, dynamic>)).toList(),
  );
}

class MonthlyKpiEntry {
  final String month;       // '2025-01'
  final String monthLabel;  // '1월'
  double target;            // 목표치
  double actual;            // 실제치
  String? note;

  MonthlyKpiEntry({
    required this.month,
    required this.monthLabel,
    required this.target,
    required this.actual,
    this.note,
  });

  double get achievementRate => target > 0 ? (actual / target * 100).clamp(0, 200) : 0;
  double get gap => actual - target;
  bool get isOnTrack => achievementRate >= 80;

  Map<String, dynamic> toJson() => {
    'month': month, 'monthLabel': monthLabel,
    'target': target, 'actual': actual, 'note': note,
  };

  factory MonthlyKpiEntry.fromJson(Map<String, dynamic> j) => MonthlyKpiEntry(
    month: j['month'] as String? ?? '',
    monthLabel: j['monthLabel'] as String? ?? '',
    target: (j['target'] as num?)?.toDouble() ?? 0,
    actual: (j['actual'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String?,
  );
}

// ════════════════════════════════════════════════════════
//  AI DEVELOPER CHAT
// ════════════════════════════════════════════════════════
class AiMessage {
  final String id;
  final bool isUser;
  String content;
  final DateTime createdAt;
  bool isLoading;

  AiMessage({
    required this.id,
    required this.isUser,
    required this.content,
    required this.createdAt,
    this.isLoading = false,
  });
}

class CampaignModel {
  final String id, name, type, status, channel;
  final double budget, spent, revenue, impressions, clicks, conversions;
  final DateTime startDate, endDate;
  CampaignModel({required this.id, required this.name, required this.type,
    required this.status, required this.budget, required this.spent,
    required this.revenue, required this.impressions, required this.clicks,
    required this.conversions, required this.startDate, required this.endDate,
    required this.channel});
  double get roi => spent > 0 ? ((revenue - spent) / spent * 100) : 0;
  double get ctr => impressions > 0 ? (clicks / impressions * 100) : 0;
  double get conversionRate => clicks > 0 ? (conversions / clicks * 100) : 0;
  double get cpa => conversions > 0 ? (spent / conversions) : 0;
  double get roas => spent > 0 ? (revenue / spent) : 0;
  double get budgetUsedPercent => budget > 0 ? (spent / budget * 100).clamp(0, 100) : 0;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'type': type, 'status': status, 'channel': channel,
    'budget': budget, 'spent': spent, 'revenue': revenue,
    'impressions': impressions, 'clicks': clicks, 'conversions': conversions,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
  };

  factory CampaignModel.fromJson(Map<String, dynamic> j) => CampaignModel(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    type: j['type'] as String? ?? '',
    status: j['status'] as String? ?? '',
    channel: j['channel'] as String? ?? '',
    budget: (j['budget'] as num?)?.toDouble() ?? 0,
    spent: (j['spent'] as num?)?.toDouble() ?? 0,
    revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
    impressions: (j['impressions'] as num?)?.toDouble() ?? 0,
    clicks: (j['clicks'] as num?)?.toDouble() ?? 0,
    conversions: (j['conversions'] as num?)?.toDouble() ?? 0,
    startDate: j['startDate'] != null ? DateTime.parse(j['startDate'] as String) : DateTime.now(),
    endDate: j['endDate'] != null ? DateTime.parse(j['endDate'] as String) : DateTime.now(),
  );
}

// ════════════════════════════════════════════════════════
//  마케팅 권역 (MarketingRegion)
// ════════════════════════════════════════════════════════
class MarketingRegion {
  final String id;
  String name;         // 예: '동남아', '중동', '북미', '국내'
  String? description;
  final List<String> countries; // ISO 국가코드 or 이름 목록
  String colorHex;     // UI 색상
  String icon;         // 이모지 또는 아이콘
  String? regionCode;  // 권역 코드 (예: SEA, ME, NA, DOM)

  MarketingRegion({
    required this.id,
    required this.name,
    this.description,
    required this.countries,
    this.colorHex = '#00C9A7',
    this.icon = '🌍',
    this.regionCode,
  });

  MarketingRegion copyWith({
    String? name, String? description, List<String>? countries,
    String? colorHex, String? icon, String? regionCode,
  }) => MarketingRegion(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    countries: countries ?? List.from(this.countries),
    colorHex: colorHex ?? this.colorHex,
    icon: icon ?? this.icon,
    regionCode: regionCode ?? this.regionCode,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'countries': countries, 'colorHex': colorHex,
    'icon': icon, 'regionCode': regionCode,
  };

  factory MarketingRegion.fromJson(Map<String, dynamic> j) => MarketingRegion(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    description: j['description'] as String?,
    countries: List<String>.from(j['countries'] as List? ?? []),
    colorHex: j['colorHex'] as String? ?? '#00C9A7',
    icon: j['icon'] as String? ?? '🌍',
    regionCode: j['regionCode'] as String?,
  );
}

// ════════════════════════════════════════════════════════
//  고객사 (ClientAccount)
// ════════════════════════════════════════════════════════
class ClientAccount {
  final String id;
  String name;           // 고객사명
  String? buyerCode;     // 바이어 코드 (예: B-001, KR-BUYER-01)
  String? country;       // 나라
  String? region;        // 권역
  String? industry;      // 업종
  String? contactName;   // 담당자 이름
  String? contactEmail;
  String? contactPhone;  // 담당자 연락처
  String? note;
  bool isActive;
  // 성과 데이터 (수동 입력 or 집계)
  double revenue;        // 해당 고객사 발생 매출
  double adSpend;        // 광고비
  DateTime createdAt;

  ClientAccount({
    required this.id,
    required this.name,
    this.buyerCode,
    this.country,
    this.region,
    this.industry,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.note,
    this.isActive = true,
    this.revenue = 0,
    this.adSpend = 0,
    required this.createdAt,
  });

  double get roi => adSpend > 0 ? ((revenue - adSpend) / adSpend * 100) : 0;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'buyerCode': buyerCode,
    'country': country, 'region': region, 'industry': industry,
    'contactName': contactName, 'contactEmail': contactEmail,
    'contactPhone': contactPhone, 'note': note,
    'isActive': isActive, 'revenue': revenue, 'adSpend': adSpend,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ClientAccount.fromJson(Map<String, dynamic> j) => ClientAccount(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    buyerCode: j['buyerCode'] as String?,
    country: j['country'] as String?,
    region: j['region'] as String?,
    industry: j['industry'] as String?,
    contactName: j['contactName'] as String?,
    contactEmail: j['contactEmail'] as String?,
    contactPhone: j['contactPhone'] as String?,
    note: j['note'] as String?,
    isActive: j['isActive'] as bool? ?? true,
    revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
    adSpend: (j['adSpend'] as num?)?.toDouble() ?? 0,
    createdAt: j['createdAt'] != null
        ? DateTime.parse(j['createdAt'] as String) : DateTime.now(),
  );

  ClientAccount copyWith({
    String? name, String? buyerCode, String? country, String? region,
    String? industry, String? contactName, String? contactEmail,
    String? contactPhone, String? note, bool? isActive,
    double? revenue, double? adSpend,
  }) => ClientAccount(
    id: id,
    name: name ?? this.name,
    buyerCode: buyerCode ?? this.buyerCode,
    country: country ?? this.country,
    region: region ?? this.region,
    industry: industry ?? this.industry,
    contactName: contactName ?? this.contactName,
    contactEmail: contactEmail ?? this.contactEmail,
    contactPhone: contactPhone ?? this.contactPhone,
    note: note ?? this.note,
    isActive: isActive ?? this.isActive,
    revenue: revenue ?? this.revenue,
    adSpend: adSpend ?? this.adSpend,
    createdAt: createdAt,
  );
}

// ════════════════════════════════════════════════════════
//  DASHBOARD WIDGET CONFIG (대시보드 위젯 커스터마이즈)
// ════════════════════════════════════════════════════════

/// 대시보드 위젯 종류
enum DashboardWidgetType {
  summaryCards,      // 요약 카드 (매출/광고비/ROI/...)
  revenueChart,      // 매출 트렌드 차트
  kpiAchievement,    // KPI 달성률
  activeCampaigns,   // 활성 캠페인
  riskTop5,          // 위험 태스크 Top5
  allTasks,          // 전체 태스크
  regionRoi,         // 권역별 ROI
  countryRoi,        // 국가별 ROI
  clientRoi,         // 고객사별 ROI
  funnelSummary,     // 퍼널 요약
  teamProgress,      // 팀 진행률
  budgetBurn,        // 예산 소진율
}

extension DashboardWidgetTypeX on DashboardWidgetType {
  String get label {
    switch (this) {
      case DashboardWidgetType.summaryCards:    return '요약 카드';
      case DashboardWidgetType.revenueChart:    return '매출 트렌드';
      case DashboardWidgetType.kpiAchievement:  return 'KPI 달성률';
      case DashboardWidgetType.activeCampaigns: return '활성 캠페인';
      case DashboardWidgetType.riskTop5:        return '위험 태스크';
      case DashboardWidgetType.allTasks:        return '전체 태스크';
      case DashboardWidgetType.regionRoi:       return '권역별 ROI';
      case DashboardWidgetType.countryRoi:      return '국가별 ROI';
      case DashboardWidgetType.clientRoi:       return '고객사별 ROI';
      case DashboardWidgetType.funnelSummary:   return '퍼널 요약';
      case DashboardWidgetType.teamProgress:    return '팀 진행률';
      case DashboardWidgetType.budgetBurn:      return '예산 소진율';
    }
  }
  String get icon {
    switch (this) {
      case DashboardWidgetType.summaryCards:    return '📊';
      case DashboardWidgetType.revenueChart:    return '📈';
      case DashboardWidgetType.kpiAchievement:  return '🎯';
      case DashboardWidgetType.activeCampaigns: return '📢';
      case DashboardWidgetType.riskTop5:        return '⚠️';
      case DashboardWidgetType.allTasks:        return '✅';
      case DashboardWidgetType.regionRoi:       return '🌏';
      case DashboardWidgetType.countryRoi:      return '🗺️';
      case DashboardWidgetType.clientRoi:       return '🏢';
      case DashboardWidgetType.funnelSummary:   return '🔻';
      case DashboardWidgetType.teamProgress:    return '👥';
      case DashboardWidgetType.budgetBurn:      return '💰';
    }
  }
}

/// 개별 위젯 설정
class DashboardWidgetConfig {
  final DashboardWidgetType type;
  bool isVisible;
  int order;            // 표시 순서 (낮을수록 앞)
  String customTitle;  // 사용자 지정 제목 (비어있으면 기본값 사용)
  bool isExpanded;     // 확장 여부

  DashboardWidgetConfig({
    required this.type,
    this.isVisible = true,
    required this.order,
    this.customTitle = '',
    this.isExpanded = true,
  });

  String get displayTitle => customTitle.isNotEmpty ? customTitle : type.label;

  DashboardWidgetConfig copyWith({
    bool? isVisible,
    int? order,
    String? customTitle,
    bool? isExpanded,
  }) => DashboardWidgetConfig(
    type: type,
    isVisible: isVisible ?? this.isVisible,
    order: order ?? this.order,
    customTitle: customTitle ?? this.customTitle,
    isExpanded: isExpanded ?? this.isExpanded,
  );
}

/// 대시보드 전체 설정
class DashboardConfig {
  List<DashboardWidgetConfig> widgets;
  List<String> selectedSummaryMetrics;
  String campaignTypeFilter; // 'all' 또는 특정 캠페인 분류
  bool showRoiWidgets;

  DashboardConfig({
    required this.widgets,
    List<String>? selectedSummaryMetrics,
    this.campaignTypeFilter = 'all',
    this.showRoiWidgets = true,
  }) : selectedSummaryMetrics = selectedSummaryMetrics ??
      ['매출', '마케팅 ROI', '광고비', '신규 리드', 'KPI 달성률', '활성 캠페인'];

  /// 기본 설정 생성
  factory DashboardConfig.defaults() {
    final types = [
      DashboardWidgetType.summaryCards,
      DashboardWidgetType.revenueChart,
      DashboardWidgetType.kpiAchievement,
      DashboardWidgetType.activeCampaigns,
      DashboardWidgetType.riskTop5,
      DashboardWidgetType.regionRoi,
      DashboardWidgetType.countryRoi,
      DashboardWidgetType.clientRoi,
      DashboardWidgetType.allTasks,
      DashboardWidgetType.budgetBurn,
      DashboardWidgetType.funnelSummary,
      DashboardWidgetType.teamProgress,
    ];
    return DashboardConfig(
      widgets: types.asMap().entries.map((e) => DashboardWidgetConfig(
        type: e.value,
        order: e.key,
        isVisible: e.key < 8, // 처음 8개만 기본 표시
      )).toList(),
    );
  }

  DashboardWidgetConfig? getConfig(DashboardWidgetType type) {
    try { return widgets.firstWhere((w) => w.type == type); } catch (_) { return null; }
  }

  List<DashboardWidgetConfig> get visibleWidgets =>
      widgets.where((w) => w.isVisible).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
}

// ════════════════════════════════════════════════════════
//  PROJECT ORDER / REVENUE (프로젝트 매출 & 오더)
// ════════════════════════════════════════════════════════
class ProjectRevenueEntry {
  final String id;
  String clientId;      // 고객사 ID
  String? country;      // 직접 입력 국가 (clientId 없을 때)
  String? region;       // 직접 입력 권역
  double orderAmount;   // 수주 금액
  double revenue;       // 실현 매출
  double adSpend;       // 해당 수주에 투입된 광고비
  String currency;      // USD, KRW, EUR 등
  String? note;
  DateTime date;

  ProjectRevenueEntry({
    required this.id,
    required this.clientId,
    this.country,
    this.region,
    required this.orderAmount,
    required this.revenue,
    required this.adSpend,
    this.currency = 'KRW',
    this.note,
    required this.date,
  });

  double get roi => adSpend > 0 ? ((revenue - adSpend) / adSpend * 100) : 0;
  double get roas => adSpend > 0 ? (revenue / adSpend) : 0;
}
