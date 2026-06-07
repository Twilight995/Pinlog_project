import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/services/map_controls_prefs.dart';
import '../../../core/theme/app_theme.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final identities = user?.identities ?? [];
    // 이메일/비밀번호로 가입한 유저만 비밀번호 변경 허용
    // 소셜 로그인(Google, Apple, Kakao 등)은 비밀번호 없음
    final isEmailUser =
        identities.any((i) => i.provider == 'email') ||
        (identities.isEmpty && email.isNotEmpty);
    final primary = context.primaryColor;
    final muted = context.labelColor.withValues(alpha: 0.38);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 헤더 ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: context.labelColor,
                    ),
                  ),
                  Text(
                    '계정 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.labelColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 내용 ──────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // 내 계정
                  _SectionTitle('내 계정'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _TapRow(
                        icon: Icons.email_outlined,
                        iconColor: muted,
                        label: '이메일',
                        subtitle: email.isEmpty ? '—' : email,
                        isLast: true,
                        onTap: email.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: email));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('이메일이 복사됐어요'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    margin: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      24,
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),

                  if (isEmailUser) ...[
                    const SizedBox(height: 28),
                    _SectionTitle('보안'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _TapRow(
                          icon: Icons.lock_outline_rounded,
                          iconColor: primary,
                          label: '비밀번호 변경',
                          subtitle: '현재 비밀번호 확인 후 변경',
                          isLast: true,
                          onTap: () => _showChangePasswordSheet(context, ref),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),
                  _SectionTitle('지도 컨트롤 구성'),
                  const SizedBox(height: 6),
                  Text(
                    '">" 버튼을 눌렀을 때 표시할 메뉴를 설정해요',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.subLabelColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MapControlsCard(ref: ref),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ChangePasswordSheet(notifier: ref.read(pinlogAuthProvider.notifier)),
    );
  }
}

// ─── 비밀번호 변경 바텀 시트 ──────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final PinlogAuthNotifier notifier;
  const _ChangePasswordSheet({required this.notifier});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final next = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty) {
      setState(() => _errorMsg = '현재 비밀번호를 입력해주세요.');
      return;
    }
    if (next.length < 8) {
      setState(() => _errorMsg = '새 비밀번호는 8자 이상이어야 합니다.');
      return;
    }
    if (next != confirm) {
      setState(() => _errorMsg = '새 비밀번호가 일치하지 않습니다.');
      return;
    }
    if (current == next) {
      setState(() => _errorMsg = '현재 비밀번호와 동일한 비밀번호는 사용할 수 없습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    final err = await widget.notifier.verifyAndChangePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('비밀번호가 변경되었습니다.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          backgroundColor: const Color(0xFF34D399),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primary = context.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: context.handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '비밀번호 변경',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.labelColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '보안을 위해 현재 비밀번호를 먼저 확인합니다.',
              style: TextStyle(fontSize: 13, color: context.subLabelColor),
            ),
            const SizedBox(height: 20),

            _PwField(
              controller: _currentCtrl,
              focusNode: _currentFocus,
              label: '현재 비밀번호',
              show: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              textInputAction: TextInputAction.next,
              onSubmitted: () => _newFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            _PwField(
              controller: _newCtrl,
              focusNode: _newFocus,
              label: '새 비밀번호 (8자 이상)',
              show: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              textInputAction: TextInputAction.next,
              onSubmitted: () => _confirmFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            _PwField(
              controller: _confirmCtrl,
              focusNode: _confirmFocus,
              label: '새 비밀번호 확인',
              show: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              textInputAction: TextInputAction.done,
              onSubmitted: () => _confirmFocus.unfocus(),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: Color(0xFFFF3B30),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedOpacity(
                opacity: _isLoading ? 0.7 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: context.onPrimaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.onPrimaryColor,
                          ),
                        )
                      : const Text(
                          '변경하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 비밀번호 입력 필드 ───────────────────────────────────────────────────────

class _PwField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  const _PwField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: !show,
      textInputAction: textInputAction,
      onSubmitted: (_) => onSubmitted?.call(),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: context.labelColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14, color: context.subLabelColor),
        filled: true,
        fillColor: context.fieldBg,
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: context.subLabelColor,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// ─── 재사용 위젯 ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.subLabelColor,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ─── 지도 컨트롤 구성 카드 ────────────────────────────────────────────────────

class _MapControlsCard extends StatelessWidget {
  final WidgetRef ref;
  const _MapControlsCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(mapControlsProvider);
    final notifier = ref.read(mapControlsProvider.notifier);
    final ids = MapControlId.values;
    final primary = context.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < ids.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 62,
                color: context.separatorColor,
              ),
            _ToggleRow(
              id: ids[i],
              isEnabled: enabled.contains(ids[i]),
              primaryColor: primary,
              onToggle: () => notifier.toggle(ids[i]),
              isLast: i == ids.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final MapControlId id;
  final bool isEnabled;
  final Color primaryColor;
  final VoidCallback onToggle;
  final bool isLast;

  const _ToggleRow({
    required this.id,
    required this.isEnabled,
    required this.primaryColor,
    required this.onToggle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, desc) = mapControlMeta[id]!;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 12, isLast ? 12 : 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isEnabled
                    ? primaryColor.withValues(alpha: 0.12)
                    : context.subLabelColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isEnabled ? primaryColor : context.subLabelColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.labelColor,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.subLabelColor,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isEnabled,
              onChanged: (_) => onToggle(),
              activeThumbColor: primaryColor,
              activeTrackColor: primaryColor.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TapRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLast;

  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 0),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.labelColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.subLabelColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: context.subLabelColor)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
