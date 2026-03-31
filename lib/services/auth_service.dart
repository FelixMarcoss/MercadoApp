import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Low-level PocketBase authentication wrapper.
/// Manages login, register, logout, and session persistence.
class AuthService {
  final PocketBase pb;

  AuthService(this.pb);

  // ─── SharedPreferences keys ───────────────────────────────────────────

  static const _tokenKey = 'pb_auth_token';
  static const _modelKey = 'pb_auth_model';

  // ─── Public API ──────────────────────────────────────────────────────

  /// Authenticates an existing user with [email] and [password].
  Future<RecordModel> login(String email, String password) async {
    final auth =
        await pb.collection('compras_users').authWithPassword(email, password);
    await _persistSession();
    return auth.record!;
  }

  /// Creates a new user account and logs them in.
  Future<RecordModel> register(String name, String email, String password) async {
    final String projectId = 'g3bdrn2mshazsyq'; // ID fixo do projeto 'Aplicativo Compras'

    await pb.collection('compras_users').create(body: {
      'name': name,
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'project_id': projectId,
    });
    return login(email, password);
  }

  /// Clears any active session both in-memory and on disk.
  Future<void> logout() async {
    pb.authStore.clear();
    await _clearSession();
  }

  /// Attempts to restore a previously saved session.
  /// Returns [true] if the session is valid after restoration.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final modelJson = prefs.getString(_modelKey);

    if (token == null || modelJson == null) return false;

    try {
      final decoded = jsonDecode(modelJson) as Map<String, dynamic>;
      pb.authStore.save(token, RecordModel.fromJson(decoded));
      // Refresh validates the token against the server
      await pb.collection('compras_users').authRefresh();
      await _persistSession();
      return pb.authStore.isValid;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  String? get currentUserId => pb.authStore.model?.id;
  bool get isLoggedIn =>
      pb.authStore.isValid && pb.authStore.model != null;

  // ─── Private helpers ──────────────────────────────────────────────────

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    final model = pb.authStore.model;
    if (model == null) return;
    await prefs.setString(_tokenKey, pb.authStore.token);
    await prefs.setString(_modelKey, jsonEncode(model.toJson()));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_modelKey);
  }
}
