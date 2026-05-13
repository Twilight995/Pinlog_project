import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/profile_repository.dart';

class UserProfile {
  final String nickname;
  final String subtitle;
  final String? photoPath;
  final String borderStyle;

  const UserProfile({
    required this.nickname,
    required this.subtitle,
    this.photoPath,
    this.borderStyle = 'white',
  });

  UserProfile copyWith({
    String? nickname,
    String? subtitle,
    Object? photoPath = _sentinel,
    String? borderStyle,
  }) =>
      UserProfile(
        nickname: nickname ?? this.nickname,
        subtitle: subtitle ?? this.subtitle,
        photoPath: photoPath == _sentinel ? this.photoPath : photoPath as String?,
        borderStyle: borderStyle ?? this.borderStyle,
      );
}

// sentinel so we can distinguish "not passed" from "explicitly null"
const _sentinel = Object();

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider));
});

class ProfileNotifier extends StateNotifier<UserProfile> {
  final ProfileRepository _repo;

  ProfileNotifier(this._repo)
      : super(UserProfile(
          nickname: _repo.getNickname(),
          subtitle: _repo.getSubtitle(),
          photoPath: _repo.getPhotoPath(),
          borderStyle: _repo.getBorderStyle(),
        ));

  Future<void> update({
    String? nickname,
    String? subtitle,
    Object? photoPath = _sentinel,
    String? borderStyle,
  }) async {
    if (nickname != null) await _repo.setNickname(nickname);
    if (subtitle != null) await _repo.setSubtitle(subtitle);
    if (photoPath != _sentinel) await _repo.setPhotoPath(photoPath as String?);
    if (borderStyle != null) await _repo.setBorderStyle(borderStyle);
    state = state.copyWith(
      nickname: nickname,
      subtitle: subtitle,
      photoPath: photoPath,
      borderStyle: borderStyle,
    );
  }
}
