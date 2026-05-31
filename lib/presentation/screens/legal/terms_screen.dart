import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ─── 공통 법률 화면 베이스 ─────────────────────────────────────────────────────

class _LegalBase extends StatefulWidget {
  final String title;
  final List<_LegalSection> sections;
  const _LegalBase({required this.title, required this.sections});

  @override
  State<_LegalBase> createState() => _LegalBaseState();
}

class _LegalBaseState extends State<_LegalBase> {
  late final ScrollController _sc;
  static const double _collapseRange = 50.0;

  double get _t =>
      (_sc.hasClients ? _sc.offset : 0.0).clamp(0.0, _collapseRange) /
      _collapseRange;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
    _sc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final topPad = MediaQuery.of(context).padding.top;
    final largeOp = 1.0 - Curves.easeInCubic.transform((t / 0.65).clamp(0.0, 1.0));
    final smallOp = Curves.easeOutCubic.transform(((t - 0.38) / 0.62).clamp(0.0, 1.0));

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPad),
          // 고정 44px 바: 중앙 타이틀(접힘) + 좌측 뒤로
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: smallOp,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: context.labelColor,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: context.labelColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 큰 타이틀 (접힘)
          ClipRect(
            child: Align(
              alignment: Alignment.bottomLeft,
              heightFactor: 1.0 - t,
              child: Opacity(
                opacity: largeOp,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: context.labelColor,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              controller: _sc,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
                    child: _LegalContent(sections: widget.sections),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalBase(
        title: '이용약관',
        sections: _kTermsSections,
      );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalBase(
        title: '개인정보처리방침',
        sections: _kPrivacySections,
      );
}

// ─── 공통 콘텐츠 위젯 ─────────────────────────────────────────────────────────

class _LegalSection {
  final String title;
  final String body;
  const _LegalSection(this.title, this.body);
}

class _LegalContent extends StatelessWidget {
  final List<_LegalSection> sections;
  const _LegalContent({required this.sections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시행일: 2026년 5월 26일',
          style: TextStyle(fontSize: 12, color: context.subLabelColor),
        ),
        const SizedBox(height: 20),
        ...sections.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.labelColor)),
              const SizedBox(height: 8),
              Text(s.body,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.subLabelColor,
                    height: 1.8,
                  )),
            ],
          ),
        )),
      ],
    );
  }
}

// ─── 이용약관 내용 ─────────────────────────────────────────────────────────────

const _kTermsSections = [
  _LegalSection(
    '제1조 (목적)',
    '이 약관은 Pinlog(이하 "서비스")가 제공하는 위치 기반 라이프 로그 서비스의 이용과 관련하여 회사와 이용자 간의 권리·의무 및 책임 사항, 기타 필요한 사항을 규정함을 목적으로 합니다.',
  ),
  _LegalSection(
    '제2조 (정의)',
    '"서비스"란 회사가 제공하는 위치 기반 라이프 로깅 앱 Pinlog 및 이와 관련된 제반 서비스를 의미합니다.\n"이용자"란 이 약관에 동의하고 서비스를 이용하는 자를 말합니다.\n"콘텐츠"란 이용자가 서비스 이용 중 생성·저장하는 핀, 사진, 텍스트 등 일체의 정보를 말합니다.',
  ),
  _LegalSection(
    '제3조 (약관의 효력 및 변경)',
    '이 약관은 서비스 화면에 게시함으로써 효력이 발생합니다. 회사는 필요한 경우 관련 법령에 위반되지 않는 범위 내에서 이 약관을 변경할 수 있으며, 변경 시 사전 공지합니다.',
  ),
  _LegalSection(
    '제4조 (서비스 제공 및 이용)',
    'Pinlog는 방문한 장소를 핀으로 기록하고, 경로·감정·날씨 등을 함께 저장하는 개인 라이프 로그 서비스를 제공합니다. 서비스는 연중무휴 24시간 제공을 원칙으로 하나, 시스템 점검·기술 장애 등의 경우 일시 중단될 수 있습니다.',
  ),
  _LegalSection(
    '제5조 (이용자의 의무)',
    '이용자는 다음 행위를 하여서는 안 됩니다.\n① 타인의 정보를 도용하거나 허위 정보를 등록하는 행위\n② 서비스를 이용하여 타인을 비방하거나 명예를 훼손하는 행위\n③ 음란·폭력적·불법적 콘텐츠를 등록하는 행위\n④ 서비스의 정상 운영을 방해하는 행위',
  ),
  _LegalSection(
    '제6조 (콘텐츠의 소유권)',
    '이용자가 서비스 내에 작성한 콘텐츠에 대한 저작권은 이용자에게 있습니다. 다만, 이용자는 서비스 개선 목적으로 콘텐츠를 회사가 익명화하여 활용하는 것에 동의합니다.',
  ),
  _LegalSection(
    '제7조 (서비스 이용 제한)',
    '회사는 이용자가 제5조의 의무를 위반하거나 서비스 정책에 위반되는 행위를 한 경우 서비스 이용을 제한하거나 계정을 종료할 수 있습니다.',
  ),
  _LegalSection(
    '제8조 (책임의 한계)',
    '회사는 이용자가 서비스를 통해 기대하는 수익을 얻지 못한 것에 대해 책임을 지지 않습니다. 천재지변·시스템 장애 등 불가항력으로 인한 서비스 중단에 대해서도 책임을 지지 않습니다.',
  ),
  _LegalSection(
    '제9조 (준거법 및 분쟁 해결)',
    '이 약관의 해석 및 분쟁에 관한 준거법은 대한민국 법률로 하며, 분쟁 발생 시 민사소송법에 따른 관할 법원을 제1심 법원으로 합니다.',
  ),
];

// ─── 개인정보처리방침 내용 ────────────────────────────────────────────────────

const _kPrivacySections = [
  _LegalSection(
    '1. 수집하는 개인정보 항목',
    '서비스는 아래와 같은 개인정보를 수집합니다.\n\n[필수] 기기 고유 식별자(UUID), 위치 정보(위도·경도)\n[선택] 프로필 사진, 닉네임, 한 줄 소개, 동행자 이름\n\n위치 정보는 핀 기록 시에만 수집되며, 기기에 로컬로 저장됩니다.',
  ),
  _LegalSection(
    '2. 개인정보의 수집 및 이용 목적',
    '수집된 개인정보는 다음의 목적으로만 사용됩니다.\n① 위치 기반 핀 기록 서비스 제공\n② 친구 코드 생성 및 소셜 기능 제공\n③ 서비스 개선 및 통계 분석 (비식별화 처리 후)',
  ),
  _LegalSection(
    '3. 개인정보의 보유 및 이용 기간',
    '사용자가 서비스를 이용하는 동안 보유합니다. 앱 삭제 또는 계정 탈퇴 시 기기 내 로컬 데이터는 즉시 삭제됩니다. 서버 저장 데이터는 탈퇴 요청일로부터 30일 이내 삭제됩니다.',
  ),
  _LegalSection(
    '4. 위치 정보의 수집 및 이용',
    '서비스는 핀 생성 시 현재 위치(위도·경도)를 수집합니다. 위치 정보는 iOS 시스템 권한(위치 서비스)을 통해 수집되며, 사용자가 언제든 설정에서 권한을 철회할 수 있습니다. 백그라운드 위치 수집은 진행하지 않습니다.',
  ),
  _LegalSection(
    '5. 개인정보의 제3자 제공',
    '서비스는 사용자의 동의 없이 개인정보를 제3자에게 제공하지 않습니다. 단, 법령에 의한 요청이 있는 경우는 예외로 합니다.',
  ),
  _LegalSection(
    '6. 사진 및 미디어 접근',
    '서비스는 핀에 사진을 첨부하기 위해 사진 라이브러리 접근 권한을 요청합니다. 수집된 사진은 기기에 로컬로 저장되며 사용자 동의 없이 외부로 전송되지 않습니다.',
  ),
  _LegalSection(
    '7. 이용자의 권리',
    '이용자는 언제든지 자신의 개인정보를 조회·수정·삭제할 수 있습니다. 앱 내 프로필 편집 기능을 통해 직접 수정하거나, 앱 삭제를 통해 모든 로컬 데이터를 삭제할 수 있습니다.',
  ),
  _LegalSection(
    '8. 개인정보 보호 책임자',
    '개인정보 처리에 관한 문의 사항은 아래 연락처로 문의하시기 바랍니다.\n\n이메일: support@pinlog.app\n처리 기간: 접수일로부터 10 영업일 이내',
  ),
];
