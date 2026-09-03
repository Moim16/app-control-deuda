// =============================================================================
//  Crear una cuenta nueva.
//
//  Sirve para arrancar en un servidor propio recién puesto. Al terminar se
//  entra ya, y lo primero que se ve es el código de recuperación: el dueño de
//  una cuenta es el único al que nadie más puede rescatar, así que si pierde la
//  contraseña sin código, se queda fuera para siempre.
//
//  El servidor puede tener el registro cerrado; entonces lo dice, y no es un
//  fallo de la app.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../utils/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class SignupSheet extends StatefulWidget {
  const SignupSheet({super.key, required this.servidor});

  final String servidor;

  static Future<void> abrir(BuildContext context, {String servidor = ''}) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
        builder: (_) => SignupSheet(servidor: servidor),
      );

  @override
  State<SignupSheet> createState() => _SignupSheetState();
}

class _SignupSheetState extends State<SignupSheet> {
  final _usuario = TextEditingController();
  final _nombre = TextEditingController();
  final _password = TextEditingController();

  bool _creando = false;
  String? _error;
  String? _codigo;

  @override
  void dispose() {
    _usuario.dispose();
    _nombre.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final u = _usuario.text.trim();
    if (u.isEmpty) {
      setState(() => _error = 'Ponle un usuario.');
      return;
    }
    if (u.contains(RegExp(r'\s'))) {
      setState(() => _error = 'El usuario no puede llevar espacios.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _creando = true;
      _error = null;
    });

    final r = await context.read<AuthRepository>().registrar(
          usuario: u,
          password: _password.text,
          nombre: _nombre.text,
          serverUrl: widget.servidor.trim().isEmpty ? null : widget.servidor,
        );
    if (!mounted) return;

    switch (r) {
      case Ok<String>(:final value):
        setState(() {
          _creando = false;
          _codigo = value;
        });
      case Err<String>(:final message):
        setState(() {
          _creando = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: _codigo != null
              ? _Bienvenida(codigo: _codigo!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Crear una cuenta',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Serás el dueño: ves y editas todo, y puedes dar acceso de '
                      'solo lectura a quien quieras.',
                      style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _usuario,
                      autofocus: true,
                      maxLength: 20,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Usuario (sin espacios)',
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nombre,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Tu nombre (opcional)',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        hintText: 'Mínimo 6 caracteres',
                      ),
                      onSubmitted: (_) => _crear(),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Aviso(_error!, tono: Tono.malo, icono: Icons.error_outline),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _creando ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _creando ? null : _crear,
                            child: _creando
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: t.onInk,
                                    ),
                                  )
                                : const Text('Crear la cuenta'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cuenta creada',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Guarda este código de recuperación. Eres el dueño de la cuenta: si '
          'pierdes la contraseña y no tienes el código, no hay forma de entrar. '
          'No se puede volver a ver.',
          style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: t.soft,
            border: Border.all(color: t.line2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            codigo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
              color: t.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: codigo));
            if (context.mounted) aviso(context, 'Copiado');
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ya lo guardé, entrar'),
        ),
      ],
    );
  }
}
