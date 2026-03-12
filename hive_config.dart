// lib/config/hive_config.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../models/team_member.dart';

/// Hive 로컬 저장소 설정
class HiveConfig {
  static const String teamMembersBox = 'team_members';

  /// Hive 초기화 (main.dart에서 호출)
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // 어댑터 등록
    if (!Hive.isAdapterRegistered(TeamMemberAdapter().typeId)) {
      Hive.registerAdapter(TeamMemberAdapter());
    }
    
    // 박스 열기
    await Hive.openBox<TeamMember>(teamMembersBox);
  }

  // ─────────────────────────────────────────────────────
  //  TeamMember 저장소 작업
  // ─────────────────────────────────────────────────────

  /// 모든 담당자를 로컬에 저장 (초기 로드 후 캐싱)
  static Future<void> saveTeamMembers(List<TeamMember> members) async {
    final box = Hive.box<TeamMember>(teamMembersBox);
    await box.clear();
    for (var member in members) {
      await box.put(member.id, member);
    }
  }

  /// 로컬에서 모든 담당자 조회
  static List<TeamMember> getTeamMembers() {
    final box = Hive.box<TeamMember>(teamMembersBox);
    return box.values.toList();
  }

  /// 로컬에 담당자 추가
  static Future<void> addTeamMember(TeamMember member) async {
    final box = Hive.box<TeamMember>(teamMembersBox);
    await box.put(member.id, member);
  }

  /// 로컬에서 담당자 ID로 조회
  static TeamMember? getTeamMemberById(String memberId) {
    final box = Hive.box<TeamMember>(teamMembersBox);
    return box.get(memberId);
  }

  /// 로컬에서 담당자 삭제
  static Future<void> deleteTeamMember(String memberId) async {
    final box = Hive.box<TeamMember>(teamMembersBox);
    await box.delete(memberId);
  }

  /// 로컬 캐시 비우기
  static Future<void> clearCache() async {
    final box = Hive.box<TeamMember>(teamMembersBox);
    await box.clear();
  }

  /// 담당자 검색 (로컬)
  static List<TeamMember> searchTeamMembers(String query) {
    final box = Hive.box<TeamMember>(teamMembersBox);
    return box.values
        .where((member) =>
            member.name.toLowerCase().contains(query.toLowerCase()) ||
            member.role.toLowerCase().contains(query.toLowerCase()) ||
            member.department.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// 캐시 상태 확인
  static bool isCacheEmpty() {
    final box = Hive.box<TeamMember>(teamMembersBox);
    return box.isEmpty;
  }

  /// 캐시 크기
  static int getCacheSize() {
    final box = Hive.box<TeamMember>(teamMembersBox);
    return box.length;
  }
}
