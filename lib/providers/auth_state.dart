import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/auth_service.dart';

/// Possible states of the authentication flow.
enum AuthStatus { loading, authenticated, unauthenticated }

/// ChangeNotifier that manages authentication state throughout the app.
///
/// Uses a single [PocketBase] instance shared with [AuthService] so the
/// authStore token is automatically available for all subsequent PB calls.
class AuthState extends ChangeNotifier {
  final PocketBase pb = PocketBase('https://telemetria.minacon.com.br');
  late final AuthService _authService;

  AuthStatus _status = AuthStatus.loading;
  String? _userId;
  String? _userEmail;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthState() {
    _authService = AuthService(pb);
    _init();
  }

  // ─── Initialisation ───────────────────────────────────────────────────

  Future<void> _init() async {
    final restored = await _authService.tryRestoreSession();
    if (restored) {
      _userId = _authService.currentUserId;
      _userEmail = pb.authStore.model?.getStringValue('email');
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Public actions ────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    return _run(() async {
      final record = await _authService.login(email.trim(), password);
      _userId = record.id;
      _userEmail = record.getStringValue('email');
      _status = AuthStatus.authenticated;
    });
  }

  Future<bool> register(String name, String email, String password) async {
    return _run(() async {
      final record = await _authService.register(name, email.trim(), password);
      _userId = record.id;
      _userEmail = record.getStringValue('email');
      _status = AuthStatus.authenticated;
    });
  }

  Future<void> logout() async {
    await _authService.logout();
    _userId = null;
    _userEmail = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Error clearing ────────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Helper ────────────────────────────────────────────────────────────

  Future<bool> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _errorMessage = null;
      return true;
    } on ClientException catch (e) {
      _errorMessage = _parseClientError(e);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _parseClientError(ClientException e) {
    try {
      // PocketBase puts human-readable messages in the response data
      final data = e.response['data'] as Map<String, dynamic>? ?? {};
      if (data.isNotEmpty) {
        final msgs = data.values
            .map((v) => (v as Map<String, dynamic>?)?['message'] as String? ?? '')
            .where((m) => m.isNotEmpty)
            .toList();
        if (msgs.isNotEmpty) return msgs.join(', ');
      }
      final msg = e.response['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return 'Erro: ${e.statusCode}. Verifique suas credenciais.';
  }
}
