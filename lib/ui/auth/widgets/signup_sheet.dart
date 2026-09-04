// =============================================================================
//  Crear una cuenta nueva, en dos pasos.
//
//  Primero los datos y el correo; el servidor manda un código de seis dígitos y
//  la cuenta NO se crea todavía. Después el código, y ahí sí se crea y se entra.
//  Un registro abandonado no deja nada a medio hacer.
//
//  Si el servidor no tiene el correo configurado, el primer paso ya crea la
//  cuenta y se salta directo al código de recuperación: así un despliegue sin la
//  clave de correo sigue teniendo forma de arrancar.
//
//  Los campos llevan sus `autofillHints` para que el gestor del teléfono ofrezca
//  guardar la contraseña nueva.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../utils/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class SignupSheet extends StatefulWidget {
  const SignupSheet({super.key});

  static Future<void> abrir(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
        builder: (_) => const SignupSheet(),
      );

  @override
  State<SignupSheet> createState() => _SignupSheetState();
}

/// En qué paso va la hoja.
enum _Paso { datos, codigo, listo }

class _SignupSheetState extends State<SignupSheet> {
  final _usuario = TextEditingController();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  final _codigo = TextEditingController();

  _Paso _paso = _Paso.datos;
  bool _trabajando = false;
  String? _error;
  String _recuperacion = '';

  @override
  void dispose() {
    _usuario.dispose();
    _nombre.dispose();
    _correo.dispose();
    _password.dispose();
    _codigo.dispose();
    super.dispose();
  }

  String? get _problemaDatos {
    final u = _usuario.text.trim();
    if (u.isEmpty) return 'Ponle un usuario.';
    if (u.contains(RegExp(r'\s'))) return 'El usuario no puede llevar espacios.';
    final c = _correo.text.trim();
    if (c.isEmpty) return 'Escribe tu correo.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(c)) {
      return 'Escribe un correo válido.';
    }
    if (_password.text.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  Future<void> _pedirCodigo() async {
    final mal = _problemaDatos;
    if (mal != null) {
      setState(() => _error = mal);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _trabajando = true;
      _error = null;
    });

    final auth = context.read<AuthRepository>();
    final r = await auth.pedirCodigo(
      usuario: _usuario.text,
      password: _password.text,
      nombre: _nombre.text,
      correo: _correo.text,
    );
    if (!mounted) return;

    switch (r) {
      case Ok<bool>(:final value):
        // La contraseña ya sirvió para algo: es el momento de que el teléfono
        // ofrezca guardarla.
        TextInput.finishAutofillContext();
        setState(() {
          _trabajando = false;
          if (value) {
            _paso = _Paso.codigo;
          } else {
            // Sin correo configurado: la cuenta ya está creada.
            _recuperacion = auth.codigoRecuperacion;
            _paso = _Paso.listo;
          }
        });
      case Err<bool>(:final message):
        setState(() {
          _trabajando = false;
          _error = message;
        });
    }
  }

  Future<void> _confirmar() async {
    if (_codigo.text.trim().length < 6) {
      setState(() => _error = 'El código son seis dígitos.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _trabajando = true;
      _error = null;
    });

    final r = await context.read<AuthRepository>().confirmarCodigo(
          correo: _correo.text,
          codigo: _codigo.text,
        );
    if (!mounted) return;

    switch (r) {
      case Ok<String>(:final value):
        setState(() {
          _trabajando = false;
          _recuperacion = value;
          _paso = _Paso.listo;
        });
      case Err<String>(:final message):
        setState(() {
          _trabajando = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: switch (_paso) {
            _Paso.datos => _Datos(
                usuario: _usuario,
                nombre: _nombre,
                correo: _correo,
                password: _password,
                trabajando: _trabajando,
                error: _error,
                onSeguir: _pedirCodigo,
                onCancelar: () => Navigator.of(context).pop(),
                onEscribir: () => setState(() => _error = null),
              ),
            _Paso.codigo => _Codigo(
                correo: _correo.text.trim(),
                codigo: _codigo,
                trabajando: _trabajando,
                error: _error,
                onConfirmar: _confirmar,
                onOtroCorreo: () => setState(() {
                  _paso = _Paso.datos;
                  _codigo.clear();
                  _error = null;
                }),
                onEscribir: () => setState(() => _error = null),
              ),
            _Paso.listo => _Guardalo(codigo: _recuperacion),
          },
        ),
      ),
    );
  }
}

/* ================================================================ paso 1 == */

class _Datos extends StatelessWidget {
  const _Datos({
    required this.usuario,
    required this.nombre,
    required this.correo,
    required this.password,
    required this.trabajando,
    required this.error,
    required this.onSeguir,
    required this.onCancelar,
    required this.onEscribir,
  });

  final TextEditingController usuario, nombre, correo, password;
  final bool trabajando;
  final String? error;
  final VoidCallback onSeguir, onCancelar, onEscribir;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AutofillGroup(
      child: Column(
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
            'Serás el dueño: ves y editas todo, y puedes dar acceso de solo '
            'lectura a quien quieras.',
            style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: usuario,
            autofocus: true,
            maxLength: 20,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            autofillHints: const [AutofillHints.newUsername],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Usuario (sin espacios)',
              counterText: '',
            ),
            onChanged: (_) => onEscribir(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: correo,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Correo',
              hintText: 'Ahí te llega el código',
            ),
            onChanged: (_) => onEscribir(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nombre,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tu nombre (opcional)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              hintText: 'Mínimo 6 caracteres',
            ),
            onSubmitted: (_) => onSeguir(),
            onChanged: (_) => onEscribir(),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Aviso(error!, tono: Tono.malo, icono: Icons.error_outline),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: trabajando ? null : onCancelar,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: trabajando ? null : onSeguir,
                  child: trabajando
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: t.onInk),
                        )
                      : const Text('Mandarme el código'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ================================================================ paso 2 == */

class _Codigo extends StatelessWidget {
  const _Codigo({
    required this.correo,
    required this.codigo,
    required this.trabajando,
    required this.error,
    required this.onConfirmar,
    required this.onOtroCorreo,
    required this.onEscribir,
  });

  final String correo;
  final TextEditingController codigo;
  final bool trabajando;
  final String? error;
  final VoidCallback onConfirmar, onOtroCorreo, onEscribir;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Revisa tu correo',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Mandamos un código de seis dígitos a $correo. Vence en 15 minutos.',
          style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: codigo,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          // El código del correo lo rellena Android solo si se le dice qué es.
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
          decoration: const InputDecoration(counterText: '', hintText: '000000'),
          onSubmitted: (_) => onConfirmar(),
          onChanged: (_) => onEscribir(),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          Aviso(error!, tono: Tono.malo, icono: Icons.error_outline),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: trabajando ? null : onConfirmar,
          child: trabajando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.onInk),
                )
              : const Text('Confirmar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: trabajando ? null : onOtroCorreo,
          child: Text(
            'Cambiar el correo o volver a intentar',
            style: TextStyle(color: t.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/* ================================================================ paso 3 == */

class _Guardalo extends StatelessWidget {
  const _Guardalo({required this.codigo});

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
