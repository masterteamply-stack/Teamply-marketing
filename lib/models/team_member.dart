/// lib/models/team_member.dart
/// 마케팅 대시보드 담당자 모델

class TeamMember {
  final String id;
  final String name;
  final String role;        // 직책/역할
  final String department;  // 부서
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isActive;

  TeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    this.avatarUrl,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'department': department,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    department: json['department'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isActive: json['isActive'] as bool? ?? true,
  );

  TeamMember copyWith({
    String? id,
    String? name,
    String? role,
    String? department,
    String? avatarUrl,
    DateTime? createdAt,
    bool? isActive,
  }) =>
      TeamMember(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        department: department ?? this.department,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
        isActive: isActive ?? this.isActive,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamMember &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TeamMember(id: $id, name: $name, role: $role, department: $department)';
}
