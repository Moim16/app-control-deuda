// =============================================================================
//  La pantalla de entrada.
//
//  Los campos van dentro de un `AutofillGroup` y con sus `autofillHints`, y al
//  entrar bien se llama a `finishAutofillContext()`. Esas tres cosas son lo que
//  hace que Android ofrezca GUARDAR la contraseña y rellenarla la próxima vez;
//  sin ellas, el gestor del teléfono no se enteraba de que esto era un login.
//
//  Y no hay campo de servidor: antes se podía cambiar a mano, y eso es un pie
//  de foto de una app de desarrollo. Quien la usa no tiene por qué saber que
//  existe una URL, y equivocarse ahí deja la app sin poder entrar sin decir por
//  qué. Para apuntar a la máquina de desarrollo se compila con
//  `--dart-define=API_URL=...`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/marca.dart';
import '../view_model/login_view_model.dart';
import 'recover_sheet.dart';
import 'signup_sheet.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<LoginViewModel>();
    await vm.signIn.run(
      LoginData(user: _user.text.trim(), password: _password.text),
    );
    if (!mounted) return;
    if (vm.signIn.errorMessage == null) {
      // Aquí es donde Android pregunta "¿guardar la contraseña?": al cerrar el
      // contexto de autocompletado después de que la sesión SÍ sirvió. Hacerlo
      // antes ofrecería guardar una contraseña equivocada.
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<LoginViewModel>();
    final cargando = vm.signIn.running;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  children: [
                    const Marca(),
                    const SizedBox(height: 14),
                    Text(
                      'Deudas',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lo que debo, a quién y cómo va bajando',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.muted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 26),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _user,
                                decoration: const InputDecoration(labelText: 'Usuario'),
                                autofillHints: const [AutofillHints.username],
                                autocorrect: false,
                                enableSuggestions: false,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Escribe tu usuario'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                decoration: const InputDecoration(labelText: 'Contraseña'),
                                autofillHints: const [AutofillHints.password],
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _entrar(),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                              ),
                              if (vm.signIn.errorMessage != null) ...[
                                const SizedBox(height: 14),
                                Aviso(vm.signIn.errorMessage!, tono: Tono.malo),
                              ],
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: cargando ? null : _entrar,
                                child: cargando
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: t.onInk,
                                        ),
                                      )
                                    : const Text('Entrar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: cargando
                          ? null
                          : () => RecoverSheet.abrir(context, usuario: _user.text.trim()),
                      child: const Text('Olvidé mi contraseña'),
                    ),
                    TextButton(
                      onPressed: cargando ? null : () => SignupSheet.abrir(context),
                      child: Text(
                        'Crear una cuenta nueva',
                        style: TextStyle(color: t.muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
