// El estado y las acciones de la pantalla de entrada.

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/me.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository auth}) : _auth = auth {
    // El comando avisa a SUS oyentes: sin reenviarlo, un login fallido no
    // repinta la pantalla y el error no se ve.
    signIn = Command1<Me, LoginData>(_signIn)..addListener(notifyListeners);
  }

  final AuthRepository _auth;

  late final Command1<Me, LoginData> signIn;

  Future<Result<Me>> _signIn(LoginData d) =>
      _auth.signIn(user: d.user, password: d.password);

  @override
  void dispose() {
    signIn.dispose();
    super.dispose();
  }
}

/// Lo que hace falta para entrar. Va junto porque `Command1` lleva un solo
/// argumento, y porque asi la pantalla no puede olvidarse de uno.
class LoginData {
  const LoginData({required this.user, required this.password});
  final String user;
  final String password;
}
