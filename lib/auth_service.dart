class AuthResult {
  const AuthResult({required this.success, this.errorMessage, this.userId});

  final bool success;
  final String? errorMessage;
  final String? userId;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Credenciales simuladas (en produccion vendrían de un servidor)
  static const String _validUsername = 'admin';
  static const String _validPassword = '1234';

  String? _currentUser;
  DateTime? _sessionStart;

  String? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<AuthResult> login(String username, String password) async {
    // Simula latencia de red
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final String trimmed = username.trim();

    if (trimmed.isEmpty || password.isEmpty) {
      return const AuthResult(
        success: false,
        errorMessage: 'Usuario y contrasena son requeridos',
      );
    }

    if (trimmed == _validUsername && password == _validPassword) {
      _currentUser = trimmed;
      _sessionStart = DateTime.now();
      return AuthResult(success: true, userId: trimmed);
    }

    return const AuthResult(
      success: false,
      errorMessage: 'Usuario o contrasena incorrectos',
    );
  }

  void logout() {
    _currentUser = null;
    _sessionStart = null;
  }

  Duration? get sessionDuration {
    if (_sessionStart == null) return null;
    return DateTime.now().difference(_sessionStart!);
  }

  // Valida formato de token de sesion
  bool validateSessionToken(String token) {
    if (token.isEmpty) return false;
    return token.startsWith('sess_') && token.length > 10;
  }

  // Verifica permisos simulados por rol
  bool hasPermission(String resource) {
    if (_currentUser == null) return false;
    final Map<String, List<String>> rolePermissions = <String, List<String>>{
      'admin': <String>['read', 'write', 'delete', 'admin'],
      'user': <String>['read'],
    };
    return rolePermissions[_currentUser]?.contains(resource) ?? false;
  }
}
