import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// 사용자 프로필 편집 다이얼로그
class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppProvider>(),
        child: const UserProfileDialog(),
      ),
    );
  }

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _deptCtrl;
  late JobTitle _selectedTitle;
  late String _selectedColor;

  static const _colorOptions = [
    '#00BFA5', '#29B6F6', '#AB47BC', '#FF7043',
    '#FFB300', '#66BB6A', '#EF5350', '#5C6BC0',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().currentUser;
    _nameCtrl = TextEditingController(text: user.name);
    _nicknameCtrl = TextEditingController(text: user.nickname ?? '');
    _emailCtrl = TextEditingController(text: user.email);
    _deptCtrl = TextEditingController(text: user.department ?? '');
    _selectedTitle = user.jobTitle;
    _selectedColor = user.avatarColor ?? '#00BFA5';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _emailCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_outline, color: AppTheme.mintPrimary, size: 22),
          SizedBox(width: 10),
          Text('프로필 편집', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar preview
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Color(int.parse('0xFF${_selectedColor.substring(1)}')).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(int.parse('0xFF${_selectedColor.substring(1)}')), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _nameCtrl.text.isNotEmpty ? _nameCtrl.text.substring(0, 2) : '?',
                        style: TextStyle(
                          color: Color(int.parse('0xFF${_selectedColor.substring(1)}')),
                          fontSize: 20, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Color picker
                    Wrap(
                      spacing: 8,
                      children: _colorOptions.map((c) {
                        final col = Color(int.parse('0xFF${c.substring(1)}'));
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == c ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('기본 정보'),
              const SizedBox(height: 8),
              _buildField('이름', _nameCtrl, '홍길동'),
              const SizedBox(height: 12),
              _buildField('닉네임', _nicknameCtrl, '닉네임 (선택)', helperText: '닉네임 설정 시 이름 대신 표시됩니다'),
              const SizedBox(height: 12),
              _buildField('이메일', _emailCtrl, 'example@company.com'),
              const SizedBox(height: 12),
              _buildField('부서', _deptCtrl, '마케팅팀'),
              const SizedBox(height: 16),
              _sectionLabel('직책 / 직위'),
              const SizedBox(height: 8),
              _buildJobTitleSelector(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mintPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8));
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {String? helperText}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        helperText: helperText,
        helperStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildJobTitleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3040)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<JobTitle>(
          value: _selectedTitle,
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMuted, size: 18),
          items: JobTitle.values.map((title) => DropdownMenuItem(
            value: title,
            child: Text(title.label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          )).toList(),
          onChanged: (v) { if (v != null) setState(() => _selectedTitle = v); },
        ),
      ),
    );
  }

  void _save() {
    final provider = context.read<AppProvider>();
    final nickname = _nicknameCtrl.text.trim();
    provider.updateCurrentUser(
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      nickname: nickname.isEmpty ? null : nickname,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      avatarColor: _selectedColor,
      jobTitle: _selectedTitle,
      department: _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
    );
    Navigator.pop(context);
  }
}
