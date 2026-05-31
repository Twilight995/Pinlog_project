import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../application/providers/friends_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';
import '../wizard_style.dart';

/// 위자드 Step 4 — 날씨 + 동행자 + 친구 태그.
class StepCompanions extends ConsumerStatefulWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onChange;

  const StepCompanions({
    super.key,
    required this.data,
    required this.totalSteps,
    required this.currentStep,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onChange,
  });

  @override
  ConsumerState<StepCompanions> createState() => _StepCompanionsState();
}

class _StepCompanionsState extends ConsumerState<StepCompanions> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  String _inputText = '';

  static const _avatarPalettes = <List<Color>>[
    [Color(0xFFFFE9A8), Color(0xFFF2A66B)],
    [Color(0xFFBFEFE4), Color(0xFF5BB89E)],
    [Color(0xFFF5C9E0), Color(0xFFD89BC4)],
    [Color(0xFFC7BFFF), Color(0xFF9D8BE0)],
    [Color(0xFFBFDBFE), Color(0xFF93C5FD)],
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();
    _ctrl.addListener(() => setState(() => _inputText = _ctrl.text.trim()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Color> _paletteFor(String key) {
    final i = key.hashCode.abs() % _avatarPalettes.length;
    return _avatarPalettes[i];
  }

  bool _isTagged(Friend friend) =>
      widget.data.taggedFriendCodes.contains(friend.code);

  void _toggleFriend(Friend friend) {
    HapticFeedback.selectionClick();
    if (_isTagged(friend)) {
      widget.data.taggedFriendCodes =
          widget.data.taggedFriendCodes.where((c) => c != friend.code).toList();
      widget.data.companions =
          widget.data.companions.where((c) => c != friend.name).toList();
    } else {
      if (!widget.data.companions.contains(friend.name)) {
        widget.data.companions = [...widget.data.companions, friend.name];
      }
      widget.data.taggedFriendCodes = [
        ...widget.data.taggedFriendCodes,
        friend.code,
      ];
    }
    widget.onChange();
    setState(() {});
  }

  void _addFromText() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final friends = ref.read(friendsProvider);
    final query = text.startsWith('@') ? text.substring(1) : text;
    final match = friends.where(
      (f) =>
          f.name.toLowerCase() == query.toLowerCase() ||
          f.code.toLowerCase() == query.toLowerCase(),
    );

    if (match.isNotEmpty) {
      _toggleFriend(match.first);
    } else {
      if (!widget.data.companions.contains(text)) {
        widget.data.companions = [...widget.data.companions, text];
        widget.onChange();
      }
    }
    _ctrl.clear();
    setState(() => _inputText = '');
    _focus.requestFocus();
  }

  void _removeCompanion(String name) {
    widget.data.companions =
        widget.data.companions.where((c) => c != name).toList();
    final friends = ref.read(friendsProvider);
    final match = friends.where((f) => f.name == name);
    if (match.isNotEmpty) {
      widget.data.taggedFriendCodes = widget.data.taggedFriendCodes
          .where((c) => c != match.first.code)
          .toList();
    }
    widget.onChange();
    setState(() {});
  }

  void _selectWeather(String w) {
    HapticFeedback.selectionClick();
    widget.data.weather = w;
    widget.onChange();
    setState(() {});
  }

  List<Friend> _getSuggestions(List<Friend> friends) {
    if (_inputText.isEmpty) return [];
    final query =
        _inputText.startsWith('@') ? _inputText.substring(1) : _inputText;
    if (query.isEmpty) return [];
    return friends
        .where(
          (f) =>
              f.name.toLowerCase().contains(query.toLowerCase()) ||
              f.code.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final suggestions = _getSuggestions(friends);
    final hasCompanions = widget.data.companions.isNotEmpty;

    return WizardScaffold(
      totalSteps: widget.totalSteps,
      currentStep: widget.currentStep,
      stepLabel: 'STEP 4 OF 5',
      questionTop: '누구와',
      questionBottom: '함께였나요?',
      subtitle: '오늘의 날씨와 함께 남겨두세요',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: widget.onNext,
        skipLabel: hasCompanions ? null : '혼자였어요',
        onSkip: hasCompanions ? null : widget.onSkip,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 날씨 ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '오늘의 날씨',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.ws.muted,
                    letterSpacing: 0.3,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
                Text(
                  _WeatherMeta.captionFor(widget.data.weather),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        _WeatherMeta.metaFor(widget.data.weather).gradient.last,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: Row(
                children: List.generate(AppConstants.weathers.length, (i) {
                  final w = AppConstants.weathers[i];
                  final selected = w == widget.data.weather;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == AppConstants.weathers.length - 1 ? 0 : 8,
                      ),
                      child: _WeatherTile(
                        label: w,
                        meta: _WeatherMeta.metaFor(w),
                        selected: selected,
                        onTap: () => _selectWeather(w),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 28),

            // ── 친구 태그 ──────────────────────────────────────────────
            if (friends.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    '친구 태그',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.ws.muted,
                      letterSpacing: 0.3,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.ws.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.data.taggedFriendCodes.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.ws.accent,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: friends.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final f = friends[i];
                    final tagged = _isTagged(f);
                    final palette = _paletteFor(f.code);
                    return _FriendAvatarTile(
                      name: f.name,
                      palette: palette,
                      tagged: tagged,
                      accent: context.ws.accent,
                      onTap: () => _toggleFriend(f),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── 동행자 입력 ────────────────────────────────────────────
            Text(
              '동행자',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.ws.muted,
                letterSpacing: 0.3,
                fontFamily: AppTokens.fontBody,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: context.ws.surface,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusButton),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onSubmitted: (_) => _addFromText(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.ws.onSurface,
                        fontFamily: AppTokens.fontBody,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: friends.isEmpty
                            ? '이름 입력 후 추가'
                            : '@친구 또는 이름 입력',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.ws.hint,
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addFromText,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: context.ws.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            // ── 친구 제안 드롭다운 ────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: suggestions.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: context.ws.surface,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusCard),
                        border: Border.all(color: context.ws.surfaceBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: suggestions.map((f) {
                          final tagged = _isTagged(f);
                          final palette = _paletteFor(f.code);
                          return InkWell(
                            onTap: () {
                              _toggleFriend(f);
                              _ctrl.clear();
                              setState(() => _inputText = '');
                            },
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusCard),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: palette,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      f.name.isNotEmpty
                                          ? f.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: context.ws.onSurface,
                                            fontFamily: AppTokens.fontBody,
                                          ),
                                        ),
                                        Text(
                                          '@${f.code}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: context.ws.muted,
                                            fontFamily: AppTokens.fontBody,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (tagged)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 20,
                                      color: context.ws.accent,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),

            // ── 태그된 동행자 칩 ───────────────────────────────────────
            if (hasCompanions) ...[
              const SizedBox(height: 24),
              Text(
                '함께한 사람',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.ws.muted,
                  letterSpacing: 0.3,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.data.companions.map((name) {
                  final friends_ = ref.read(friendsProvider);
                  final isTagged = friends_.any(
                    (f) =>
                        f.name == name &&
                        widget.data.taggedFriendCodes.contains(f.code),
                  );
                  final palette = _paletteFor(name);
                  return _CompanionChip(
                    name: name,
                    gradient: palette,
                    isTaggedFriend: isTagged,
                    accentColor: context.ws.accent,
                    onRemove: () => _removeCompanion(name),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── 친구 아바타 타일 ─────────────────────────────────────────────────────────

class _FriendAvatarTile extends StatelessWidget {
  final String name;
  final List<Color> palette;
  final bool tagged;
  final Color accent;
  final VoidCallback onTap;

  const _FriendAvatarTile({
    required this.name,
    required this.palette,
    required this.tagged,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // 선택 링
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tagged
                          ? accent
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                // 아바타
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: tagged
                          ? [accent.withValues(alpha: 0.85), accent]
                          : palette,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                // 태그 배지
                if (tagged)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              name.length > 5 ? '${name.substring(0, 4)}…' : name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: tagged ? FontWeight.w700 : FontWeight.w500,
                color: tagged
                    ? accent
                    : context.ws.muted,
                fontFamily: AppTokens.fontBody,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 동행자 칩 ─────────────────────────────────────────────────────────────────

class _CompanionChip extends StatelessWidget {
  final String name;
  final List<Color> gradient;
  final bool isTaggedFriend;
  final Color accentColor;
  final VoidCallback onRemove;

  const _CompanionChip({
    required this.name,
    required this.gradient,
    required this.isTaggedFriend,
    required this.accentColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: isTaggedFriend
            ? accentColor.withValues(alpha: 0.08)
            : ws.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
          color: isTaggedFriend
              ? accentColor.withValues(alpha: 0.35)
              : ws.surfaceBorder,
          width: isTaggedFriend ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 아바타 또는 태그 아이콘
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isTaggedFriend
                    ? [
                        accentColor.withValues(alpha: 0.7),
                        accentColor,
                      ]
                    : gradient,
              ),
            ),
            alignment: Alignment.center,
            child: isTaggedFriend
                ? const Icon(Icons.alternate_email_rounded,
                    size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isTaggedFriend ? FontWeight.w700 : FontWeight.w600,
              color: isTaggedFriend ? accentColor : ws.onSurface,
              fontFamily: AppTokens.fontBody,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: isTaggedFriend
                  ? accentColor.withValues(alpha: 0.6)
                  : ws.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 날씨 메타 ─────────────────────────────────────────────────────────────────

class _WeatherMeta {
  final String svgPath;
  final List<Color> gradient;
  final String caption;
  const _WeatherMeta({
    required this.svgPath,
    required this.gradient,
    required this.caption,
  });

  static _WeatherMeta metaFor(String label) {
    if (label.contains('맑음')) {
      return const _WeatherMeta(
        svgPath: 'lib/img/nature/sun.svg',
        gradient: [Color(0xFFFFD27A), Color(0xFFF59E5C)],
        caption: '따스한 햇살이 닿던 날',
      );
    }
    if (label.contains('비')) {
      return const _WeatherMeta(
        svgPath: 'lib/img/nature/cloud-rain.svg',
        gradient: [Color(0xFF8FA8D8), Color(0xFF4A6FB5)],
        caption: '빗방울이 마음을 두드리던 날',
      );
    }
    if (label.contains('흐림')) {
      return const _WeatherMeta(
        svgPath: 'lib/img/nature/cloud-sun-rain.svg',
        gradient: [Color(0xFFCABBE0), Color(0xFF8B7BAF)],
        caption: '잿빛 하늘이 포근하던 날',
      );
    }
    if (label.contains('눈')) {
      return const _WeatherMeta(
        svgPath: 'lib/img/nature/cloud-snow.svg',
        gradient: [Color(0xFFE7F0FA), Color(0xFFA8C9E8)],
        caption: '하얗게 내려앉던 고요',
      );
    }
    if (label.contains('바람')) {
      return const _WeatherMeta(
        svgPath: 'lib/img/wind-svgrepo-com.svg',
        gradient: [Color(0xFFB3E6D3), Color(0xFF55AE8E)],
        caption: '시원한 바람결이 스치던 날',
      );
    }
    return const _WeatherMeta(
      svgPath: 'lib/img/nature/cloud-sun-rain.svg',
      gradient: [Color(0xFFFFD27A), Color(0xFFF59E5C)],
      caption: '오늘의 공기',
    );
  }

  static String captionFor(String label) => metaFor(label).caption;
}

class _WeatherTile extends StatelessWidget {
  final String label;
  final _WeatherMeta meta;
  final bool selected;
  final VoidCallback onTap;

  const _WeatherTile({
    required this.label,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final words = label.trim().split(' ');
    final name = words.length > 1 ? words.sublist(1).join(' ') : label;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        transform: selected
            ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: meta.gradient,
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    meta.gradient.first.withValues(alpha: 0.10),
                    meta.gradient.last.withValues(alpha: 0.04),
                  ],
                ),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.35)
                : meta.gradient.last.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: meta.gradient.last.withValues(alpha: 0.50),
                    blurRadius: 22,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              meta.svgPath,
              width: 32,
              height: 32,
              colorFilter: ColorFilter.mode(
                selected ? Colors.white : meta.gradient.last,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : context.ws.onSurface.withValues(alpha: 0.85),
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
