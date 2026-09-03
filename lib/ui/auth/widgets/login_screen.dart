// La pantalla de entrada.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();

  @override
  void initState() {
    super.initState();
    _server.text = context.read<LoginViewModel>().serverUrl;
  }

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  void _entrar() {
    if (!_form.currentState!.validate()) return;
    context.read<LoginViewModel>().signIn.run(
          LoginData(
            user: _user.text.trim(),
            password: _password.text,
            serverUrl: _server.text.trim().isEmpty ? null : _server.text.trim(),
          ),
        );
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
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Escribe tu usuario' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              decoration: const InputDecoration(labelText: 'Contraseña'),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _entrar(),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                            ),
                            if (vm.showServer) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _server,
                                decoration: const InputDecoration(
                                  labelText: 'Servidor',
                                  hintText: 'https://mi-app.vercel.app',
                                ),
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'Dime dónde está el servidor';
                                  if (!s.startsWith('http')) return 'Tiene que empezar con http';
                                  return null;
                                },
                              ),
                            ],
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
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: vm.toggleServer,
                    child: Text(
                      vm.showServer ? 'Ocultar el servidor' : 'Cambiar el servidor',
                      style: TextStyle(color: t.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El cuadrito con las monedas: la misma marca del icono de la PWA.
class Marca extends StatelessWidget {
  const Marca({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.ink,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(Icons.savings_outlined, color: t.onInk, size: size * 0.55),
    );
  }
}
