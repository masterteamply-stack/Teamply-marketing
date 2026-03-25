// ════════════════════════════════════════════════════════════
//  SupabaseService – FirestoreService와 동일 인터페이스
//  Supabase PostgreSQL + Realtime 기반
//
//  테이블 구조 (Supabase에서 생성 필요):
//    user_data  : id(uuid), uid(text), table_name(text), data(jsonb)
//    user_meta  : uid(text PK), email, display_name, last_login, prefs(jsonb)
//    shared_projects : id, team_id(text), data(jsonb)
//
//  ※ Supabase 미연결 시 isAvailable=false → 모든 작업 no-op
// ════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// ── UserDataBundle ────────────────────────────────────────────
class UserDataBundle {
  final List<Team> teams;
  final List<Project> projects;
  final List<KpiModel> kpis;
  final List<CampaignModel> campaigns;
  final List<MarketingRegion> regions;
  final List<ClientAccount> clients;
  final List<AppUser> members;

  const UserDataBundle({
    required this.teams,
    required this.projects,
    required this.kpis,
    required this.campaigns,
    required this.regions,
    required this.clients,
    required this.members,
  });

  static const empty = UserDataBundle(
    teams: [], projects: [], kpis: [],
    campaigns: [], regions: [], clients: [], members: [],
  );

  bool get isEmpty =>
      teams.isEmpty && projects.isEmpty && kpis.isEmpty &&
      campaigns.isEmpty && regions.isEmpty && clients.isEmpty &&
      members.isEmpty;
}

// ─── SupabaseService ─────────────────────────────────────────
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // ── 가용 여부 ─────────────────────────────────────────────
  bool get isAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] not available: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  //  내부 헬퍼: user_data 테이블 upsert / fetch / delete
  //  구조: uid | table_name | record_id | data(jsonb)
  // ════════════════════════════════════════════════════════
  Future<void> _upsert(String uid, String table, String id,
      Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('user_data').upsert({
        'uid': uid,
        'table_name': table,
        'record_id': id,
        'data': data,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'uid,table_name,record_id');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] upsert $table/$id error: $e');
    }
  }

  Future<void> _delete(
      String uid, String table, String id) async {
    final db = _db;
    if (db == null) return;
    try {
      await db
          .from('user_data')
          .delete()
          .eq('uid', uid)
          .eq('table_name', table)
          .eq('record_id', id);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] delete $table/$id error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(
      String uid, String table) async {
    final db = _db;
    if (db == null) return [];
    try {
      final rows = await db
          .from('user_data')
          .select('data')
          .eq('uid', uid)
          .eq('table_name', table);
      return rows.map<Map<String, dynamic>>(
          (r) => Map<String, dynamic>.from(r['data'] as Map)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] fetch $table error: $e');
      return [];
    }
  }

  List<T> _parse<T>(List<Map<String, dynamic>> rows,
      T Function(Map<String, dynamic>) fromJson) {
    return rows.map((r) {
      try {
        return fromJson(r);
      } catch (e) {
        if (kDebugMode) debugPrint('[Supabase] parse error: $e');
        return null;
      }
    }).whereType<T>().toList();
  }

  // ════════════════════════════════════════════════════════
  //  신규 유저 판별
  // ════════════════════════════════════════════════════════
  Future<bool> isNewUser(String uid) async {
    if (!isAvailable) return true;
    try {
      final rows = await _db!
          .from('user_data')
          .select('record_id')
          .eq('uid', uid)
          .eq('table_name', 'teams')
          .limit(1);
      return (rows as List).isEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] isNewUser error: $e');
      return true;
    }
  }

  // ════════════════════════════════════════════════════════
  //  전체 데이터 로드
  // ════════════════════════════════════════════════════════
  Future<UserDataBundle> loadAllUserData(String uid) async {
    if (!isAvailable) return UserDataBundle.empty;
    try {
      final results = await Future.wait([
        _fetch(uid, 'teams'),
        _fetch(uid, 'projects'),
        _fetch(uid, 'kpis'),
        _fetch(uid, 'campaigns'),
        _fetch(uid, 'regions'),
        _fetch(uid, 'clients'),
        _fetch(uid, 'members'),
      ]);
      return UserDataBundle(
        teams:     _parse(results[0], Team.fromJson),
        projects:  _parse(results[1], Project.fromJson),
        kpis:      _parse(results[2], KpiModel.fromJson),
        campaigns: _parse(results[3], CampaignModel.fromJson),
        regions:   _parse(results[4], MarketingRegion.fromJson),
        clients:   _parse(results[5], ClientAccount.fromJson),
        members:   _parse(results[6], AppUser.fromJson),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] loadAllUserData error: $e');
      return UserDataBundle.empty;
    }
  }

  // ════════════════════════════════════════════════════════
  //  전체 데이터 저장 (신규 유저 초기화)
  // ════════════════════════════════════════════════════════
  Future<void> saveAllUserData(String uid, UserDataBundle bundle) async {
    if (!isAvailable) return;
    try {
      await saveUserMeta(uid, '', '');
      await Future.wait([
        ...bundle.teams.map((t) => saveTeam(uid, t)),
        ...bundle.projects.map((p) => saveProject(uid, p)),
        ...bundle.kpis.map((k) => saveKpi(uid, k)),
        ...bundle.campaigns.map((c) => saveCampaign(uid, c)),
        ...bundle.regions.map((r) => saveRegion(uid, r)),
        ...bundle.clients.map((c) => saveClient(uid, c)),
        ...bundle.members.map((m) => saveMember(uid, m)),
      ]);
      if (kDebugMode) debugPrint('[Supabase] saveAllUserData ✅ uid=$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] saveAllUserData error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  실시간 스트림 (Supabase Realtime)
  // ════════════════════════════════════════════════════════
  Stream<List<Team>> watchTeams(String uid) {
    if (!isAvailable) return const Stream.empty();
    final ctrl = StreamController<List<Team>>.broadcast();

    // 초기 로드
    _fetch(uid, 'teams').then((rows) {
      if (!ctrl.isClosed) ctrl.add(_parse(rows, Team.fromJson));
    });

    // Realtime 구독
    final channel = _db!.channel('teams_$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_data',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'uid',
        value: uid,
      ),
      callback: (_) async {
        final rows = await _fetch(uid, 'teams');
        if (!ctrl.isClosed) ctrl.add(_parse(rows, Team.fromJson));
      },
    ).subscribe();

    ctrl.onCancel = () {
      channel.unsubscribe();
      ctrl.close();
    };
    return ctrl.stream;
  }

  Stream<List<Project>> watchProjects(String uid) {
    if (!isAvailable) return const Stream.empty();
    final ctrl = StreamController<List<Project>>.broadcast();
    _fetch(uid, 'projects').then((rows) {
      if (!ctrl.isClosed) ctrl.add(_parse(rows, Project.fromJson));
    });

    final channel = _db!.channel('projects_$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_data',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'uid',
        value: uid,
      ),
      callback: (_) async {
        final rows = await _fetch(uid, 'projects');
        if (!ctrl.isClosed) ctrl.add(_parse(rows, Project.fromJson));
      },
    ).subscribe();

    ctrl.onCancel = () {
      channel.unsubscribe();
      ctrl.close();
    };
    return ctrl.stream;
  }

  Stream<List<KpiModel>> watchKpis(String uid) {
    if (!isAvailable) return const Stream.empty();
    final ctrl = StreamController<List<KpiModel>>.broadcast();
    _fetch(uid, 'kpis').then((rows) {
      if (!ctrl.isClosed) ctrl.add(_parse(rows, KpiModel.fromJson));
    });

    final channel = _db!.channel('kpis_$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_data',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'uid',
        value: uid,
      ),
      callback: (_) async {
        final rows = await _fetch(uid, 'kpis');
        if (!ctrl.isClosed) ctrl.add(_parse(rows, KpiModel.fromJson));
      },
    ).subscribe();

    ctrl.onCancel = () {
      channel.unsubscribe();
      ctrl.close();
    };
    return ctrl.stream;
  }

  // ════════════════════════════════════════════════════════
  //  Team CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveTeam(String uid, Team team) =>
      _upsert(uid, 'teams', team.id, team.toJson());

  Future<void> deleteTeam(String uid, String teamId) =>
      _delete(uid, 'teams', teamId);

  // ════════════════════════════════════════════════════════
  //  Project CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveProject(String uid, Project project) =>
      _upsert(uid, 'projects', project.id, project.toJson());

  Future<void> deleteProject(String uid, String projectId) =>
      _delete(uid, 'projects', projectId);

  // ════════════════════════════════════════════════════════
  //  KPI CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveKpi(String uid, KpiModel kpi) =>
      _upsert(uid, 'kpis', kpi.id, kpi.toJson());

  Future<void> deleteKpi(String uid, String kpiId) =>
      _delete(uid, 'kpis', kpiId);

  // ════════════════════════════════════════════════════════
  //  Campaign CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveCampaign(String uid, CampaignModel campaign) =>
      _upsert(uid, 'campaigns', campaign.id, campaign.toJson());

  Future<void> deleteCampaign(String uid, String campaignId) =>
      _delete(uid, 'campaigns', campaignId);

  // ════════════════════════════════════════════════════════
  //  Region CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveRegion(String uid, MarketingRegion region) =>
      _upsert(uid, 'regions', region.id, region.toJson());

  Future<void> deleteRegion(String uid, String regionId) =>
      _delete(uid, 'regions', regionId);

  // ════════════════════════════════════════════════════════
  //  Client CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveClient(String uid, ClientAccount client) =>
      _upsert(uid, 'clients', client.id, client.toJson());

  Future<void> deleteClient(String uid, String clientId) =>
      _delete(uid, 'clients', clientId);

  // ════════════════════════════════════════════════════════
  //  Member CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveMember(String uid, AppUser member) =>
      _upsert(uid, 'members', member.id, member.toJson());

  Future<void> deleteMember(String uid, String memberId) =>
      _delete(uid, 'members', memberId);

  // ════════════════════════════════════════════════════════
  //  User Meta (user_meta 테이블)
  // ════════════════════════════════════════════════════════
  Future<void> updateLastLogin(String uid) async {
    if (!isAvailable) return;
    try {
      await _db!.from('user_meta').upsert({
        'uid': uid,
        'last_login': DateTime.now().toIso8601String(),
      }, onConflict: 'uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] updateLastLogin error: $e');
    }
  }

  Future<void> saveUserMeta(
      String uid, String email, String displayName) async {
    if (!isAvailable) return;
    try {
      await _db!.from('user_meta').upsert({
        'uid': uid,
        'email': email,
        'display_name': displayName,
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] saveUserMeta error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  User Prefs
  // ════════════════════════════════════════════════════════
  Future<void> saveUserPrefs(String uid, Map<String, dynamic> prefs) async {
    if (!isAvailable) return;
    try {
      await _db!.from('user_meta').upsert({
        'uid': uid,
        'prefs': prefs,
      }, onConflict: 'uid');
      if (kDebugMode) debugPrint('[Supabase] saveUserPrefs ✅');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] saveUserPrefs error: $e');
    }
  }

  Future<Map<String, dynamic>?> loadUserPrefs(String uid) async {
    if (!isAvailable) return null;
    try {
      final rows = await _db!
          .from('user_meta')
          .select('prefs')
          .eq('uid', uid)
          .limit(1);
      if ((rows as List).isEmpty) return null;
      return rows.first['prefs'] as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] loadUserPrefs error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  //  전체 삭제 (계정 리셋)
  // ════════════════════════════════════════════════════════
  Future<void> deleteAllCollections(String uid) async {
    if (!isAvailable) return;
    try {
      await _db!.from('user_data').delete().eq('uid', uid);
      await _db!.from('user_meta').delete().eq('uid', uid);
      if (kDebugMode) debugPrint('[Supabase] deleteAllCollections ✅');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] deleteAllCollections error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  공유 프로젝트 (shared_projects 테이블)
  //  팀 멤버 전원 공유
  // ════════════════════════════════════════════════════════
  Future<void> saveSharedProject(String teamId, Project project) async {
    if (!isAvailable) return;
    try {
      await _db!.from('shared_projects').upsert({
        'team_id': teamId,
        'record_id': project.id,
        'data': project.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'team_id,record_id');
      if (kDebugMode) debugPrint('[Supabase] saveSharedProject ✅');
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] saveSharedProject error: $e');
    }
  }

  Future<void> deleteSharedProject(String teamId, String projectId) async {
    if (!isAvailable) return;
    try {
      await _db!
          .from('shared_projects')
          .delete()
          .eq('team_id', teamId)
          .eq('record_id', projectId);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] deleteSharedProject error: $e');
    }
  }

  Stream<List<Project>> watchSharedProjects(String teamId) {
    if (!isAvailable) return const Stream.empty();
    final ctrl = StreamController<List<Project>>.broadcast();

    _db!
        .from('shared_projects')
        .select('data')
        .eq('team_id', teamId)
        .then((rows) {
      final projects = (rows as List)
          .map((r) {
            try {
              return Project.fromJson(
                  Map<String, dynamic>.from(r['data'] as Map));
            } catch (_) {
              return null;
            }
          })
          .whereType<Project>()
          .toList();
      if (!ctrl.isClosed) ctrl.add(projects);
    });

    final channel = _db!.channel('shared_$teamId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'shared_projects',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'team_id',
        value: teamId,
      ),
      callback: (_) async {
        final rows = await _db!
            .from('shared_projects')
            .select('data')
            .eq('team_id', teamId);
        final projects = (rows as List)
            .map((r) {
              try {
                return Project.fromJson(
                    Map<String, dynamic>.from(r['data'] as Map));
              } catch (_) {
                return null;
              }
            })
            .whereType<Project>()
            .toList();
        if (!ctrl.isClosed) ctrl.add(projects);
      },
    ).subscribe();

    ctrl.onCancel = () {
      channel.unsubscribe();
      ctrl.close();
    };
    return ctrl.stream;
  }

  Future<List<Project>> loadSharedProjects(String teamId) async {
    if (!isAvailable) return [];
    try {
      final rows = await _db!
          .from('shared_projects')
          .select('data')
          .eq('team_id', teamId);
      return (rows as List)
          .map((r) {
            try {
              return Project.fromJson(
                  Map<String, dynamic>.from(r['data'] as Map));
            } catch (_) {
              return null;
            }
          })
          .whereType<Project>()
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] loadSharedProjects error: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════
  //  대시보드 설정 저장
  // ════════════════════════════════════════════════════════
  Future<void> saveDashboardConfig(
      String uid, DashboardConfig config) async {
    if (!isAvailable) return;
    try {
      final data = config.widgets
          .map((w) => {
                'type': w.type.name,
                'isVisible': w.isVisible,
                'order': w.order,
              })
          .toList();
      await saveUserPrefs(uid, {'dashboardConfig': data});
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] saveDashboardConfig error: $e');
    }
  }
}
