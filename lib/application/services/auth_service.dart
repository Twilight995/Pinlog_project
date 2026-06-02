import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

class AuthService {
  final _client = Supabase.instance.client;

  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((e) => e.session?.user);

  User? get currentUser => _client.auth.currentUser;
  String? get uid => _client.auth.currentUser?.id;

  Future<void> signOut() => _client.auth.signOut();
}
