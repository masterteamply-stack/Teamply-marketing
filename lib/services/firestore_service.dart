// ════════════════════════════════════════════════════════════
//  FirestoreService – 사용자별 데이터 영구 저장/로드
//  구조: users/{uid}/teams, projects, kpis, campaigns, regions, clients, members
//
//  ※ Firebase 미초기화 시 isAvailable=false → 모든 작업 no-op
//  ※ 실시간 스트림은 Firebase 사용 불가 시 빈 스트림 반환
// ════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/models.dart';

// ─── UserDataBundle: 유저 전체 데이터 묶음 ─────────────────
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

  static const UserDataBundle empty = UserDataBundle(
    teams: [], projects: [], kpis: [], campaigns: [],
    regions: [], clients: [], members: [],
  );

  bool get isEmpty =>
      teams.isEmpty &&
      projects.isEmpty &&
      kpis.isEmpty &&
      campaigns.isEmpty &&
      regions.isEmpty &&
      clients.isEmpty;
}

// ─── FirestoreService ───────────────────────────────────────
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ── Firebase 사용 가능 여부 (lazy check) ──────────────────
  bool get isAvailable {
    try {
      Firebase.app(); // throws StateError if not initialized
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Firestore 인스턴스 (null-safe) ────────────────────────
  FirebaseFirestore? get _db {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] not available: $e');
      return null;
    }
  }

  // ── 경로 헬퍼 ─────────────────────────────────────────────
  CollectionReference? _col(String uid, String name) =>
      _db?.collection('users').doc(uid).collection(name);

  DocumentReference? _userDoc(String uid) =>
      _db?.collection('users').doc(uid);

  // ════════════════════════════════════════════════════════
  //  신규 유저 판별
  // ════════════════════════════════════════════════════════
  Future<bool> isNewUser(String uid) async {
    if (!isAvailable) return true; // Firebase 없음 → 신규로 처리(샘플 데이터)
    try {
      final col = _col(uid, 'teams');
      if (col == null) return true;
      final snap = await col.limit(1).get();
      return snap.docs.isEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] isNewUser error: $e');
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
        _col(uid, 'teams')!.get(),
        _col(uid, 'projects')!.get(),
        _col(uid, 'kpis')!.get(),
        _col(uid, 'campaigns')!.get(),
        _col(uid, 'regions')!.get(),
        _col(uid, 'clients')!.get(),
        _col(uid, 'members')!.get(),
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
      if (kDebugMode) debugPrint('[Firestore] loadAllUserData error: $e');
      return UserDataBundle.empty;
    }
  }

  List<T> _parse<T>(QuerySnapshot snap,
      T Function(Map<String, dynamic>) fromJson) {
    return snap.docs.map((doc) {
      try {
        return fromJson(doc.data() as Map<String, dynamic>);
      } catch (e) {
        if (kDebugMode) debugPrint('[Firestore] parse error ${doc.id}: $e');
        return null;
      }
    }).whereType<T>().toList();
  }

  // ════════════════════════════════════════════════════════
  //  전체 데이터 저장 (신규 유저 초기화)
  // ════════════════════════════════════════════════════════
  Future<void> saveAllUserData(String uid, UserDataBundle bundle) async {
    if (!isAvailable) return;
    try {
      await _userDoc(uid)?.set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await Future.wait([
        ...bundle.teams.map((t) => saveTeam(uid, t)),
        ...bundle.projects.map((p) => saveProject(uid, p)),
        ...bundle.kpis.map((k) => saveKpi(uid, k)),
        ...bundle.campaigns.map((c) => saveCampaign(uid, c)),
        ...bundle.regions.map((r) => saveRegion(uid, r)),
        ...bundle.clients.map((c) => saveClient(uid, c)),
        ...bundle.members.map((m) => saveMember(uid, m)),
      ]);
      if (kDebugMode) debugPrint('[Firestore] saveAllUserData ✅ uid=$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveAllUserData error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  실시간 스트림 (onSnapshot)
  //  Firebase 미사용 시 빈 스트림 반환
  // ════════════════════════════════════════════════════════
  Stream<List<Team>> watchTeams(String uid) {
    if (!isAvailable) return const Stream.empty();
    try {
      return _col(uid, 'teams')!
          .snapshots()
          .map((snap) => _parse(snap, Team.fromJson));
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] watchTeams error: $e');
      return const Stream.empty();
    }
  }

  Stream<List<Project>> watchProjects(String uid) {
    if (!isAvailable) return const Stream.empty();
    try {
      return _col(uid, 'projects')!
          .snapshots()
          .map((snap) => _parse(snap, Project.fromJson));
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] watchProjects error: $e');
      return const Stream.empty();
    }
  }

  Stream<List<KpiModel>> watchKpis(String uid) {
    if (!isAvailable) return const Stream.empty();
    try {
      return _col(uid, 'kpis')!
          .snapshots()
          .map((snap) => _parse(snap, KpiModel.fromJson));
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] watchKpis error: $e');
      return const Stream.empty();
    }
  }

  // ════════════════════════════════════════════════════════
  //  Team CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveTeam(String uid, Team team) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'teams')?.doc(team.id).set(team.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveTeam error: $e');
    }
  }

  Future<void> deleteTeam(String uid, String teamId) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'teams')?.doc(teamId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] deleteTeam error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  Project CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveProject(String uid, Project project) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'projects')?.doc(project.id).set(project.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveProject error: $e');
    }
  }

  Future<void> deleteProject(String uid, String projectId) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'projects')?.doc(projectId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] deleteProject error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  KPI CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveKpi(String uid, KpiModel kpi) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'kpis')?.doc(kpi.id).set(kpi.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveKpi error: $e');
    }
  }

  Future<void> deleteKpi(String uid, String kpiId) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'kpis')?.doc(kpiId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] deleteKpi error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  Campaign CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveCampaign(String uid, CampaignModel campaign) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'campaigns')?.doc(campaign.id).set(campaign.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveCampaign error: $e');
    }
  }

  Future<void> deleteCampaign(String uid, String campaignId) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'campaigns')?.doc(campaignId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] deleteCampaign error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  Region CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveRegion(String uid, MarketingRegion region) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'regions')?.doc(region.id).set(region.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveRegion error: $e');
    }
  }

  Future<void> deleteRegion(String uid, String regionId) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'regions')?.doc(regionId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] deleteRegion error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  Client CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveClient(String uid, ClientAccount client) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'clients')?.doc(client.id).set(client.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveClient error: $e');
    }
  }

  Future<void> deleteClient(String uid, String clientId) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'clients')?.doc(clientId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] deleteClient error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  Member CRUD
  // ════════════════════════════════════════════════════════
  Future<void> saveMember(String uid, AppUser member) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'members')?.doc(member.id).set(member.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveMember error: $e');
    }
  }

  Future<void> deleteMember(String uid, String memberId) async {
    if (!isAvailable) return;
    try {
      await _col(uid, 'members')?.doc(memberId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] deleteMember error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  마지막 로그인 업데이트
  // ════════════════════════════════════════════════════════
  Future<void> updateLastLogin(String uid) async {
    if (!isAvailable) return;
    try {
      await _userDoc(uid)?.set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] updateLastLogin error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  사용자 메타 저장 (이메일, 표시이름)
  // ════════════════════════════════════════════════════════
  Future<void> saveUserMeta(
      String uid, String email, String displayName) async {
    if (!isAvailable) return;
    try {
      await _userDoc(uid)?.set({
        'email': email,
        'displayName': displayName,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveUserMeta error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  전체 데이터 삭제 (계정 리셋용)
  // ════════════════════════════════════════════════════════
  Future<void> deleteAllCollections(String uid) async {
    if (!isAvailable) return;
    const cols = [
      'teams', 'projects', 'kpis', 'campaigns',
      'regions', 'clients', 'members'
    ];
    for (final colName in cols) {
      try {
        final col = _col(uid, colName);
        if (col == null) continue;
        final snap = await col.get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Firestore] deleteAllCollections $colName error: $e');
      }
    }
  }

  // ════════════════════════════════════════════════════════
  //  대시보드 설정 저장/로드
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
      await _userDoc(uid)
          ?.set({'dashboardConfig': data}, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[Firestore] saveDashboardConfig error: $e');
    }
  }
}
