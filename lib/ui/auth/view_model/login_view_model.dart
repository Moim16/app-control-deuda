// El estado y las acciones de la pantalla de entrada.

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/me.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository auth}) : _auth = auth {
    // Si no se sabe a que servidor hablar, el campo se muestra de una: sin eso
    // no hay a donde entrar.
    _showServer = !_auth.hasServer;
    signIn = Command1<Me, LoginData>(_signIn);
  }

  final AuthRepository _auth;

  late final Command1<Me, LoginData> signIn;

  bool _showServer = false;
  bool get showServer => _showServer;

  String get serverUrl => _auth.baseUrl;

  void toggleServer() {
    _showServer = !_showServer;
    notifyListeners();
  }

  Future<Result<Me>> _signIn(LoginData d) => _auth.signIn(
        user: d.user,
        password: d.password,
        serverUrl: d.serverUrl,
      );

  @override
  void dispose() {
    signIn.dispose();
    super.dispose();
  }
}

/// Lo que hace falta para entrar. Va junto porque `Command1` lleva un solo
/// argumento, y porque asi la pantalla no puede olvidarse de uno.
class LoginData {
  const LoginData({required this.user, required this.password, this.serverUrl});
  final String user;
  final String password;
  final String? serverUrl;
}
