// =============================================================================
//  Entrar con el código de recuperación.
//
//  Sin correo configurado, este código es la ÚNICA forma de volver a entrar si
//  se olvida la contraseña. Al usarlo se pone una contraseña nueva y el
//  servidor devuelve un código nuevo: el usado ya no vale, y hay que guardar el
//  nuevo ahí mismo.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../utils/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class RecoverSheet extends StatefulWidget {
  const RecoverSheet({super.key, required this.usuario, required this.servidor});

  /// Lo que ya se hubiera escrito en la pantalla de entrada.
  final String usuario;
  final String servidor;

  static Future<void> abrir(
    BuildContext context, {
    String usuario = '',
    String servidor = '',
  }) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
        builder: (_) => RecoverSheet(usuario: usuario, servidor: servidor),
      );

  @override
  State<RecoverSheet> createState() => _RecoverSheetState();
}

class _RecoverSheetState extends State<RecoverSheet> {
  late final TextEditingController _usuario = TextEditingController(text: widget.usuario);
  final _codigo = TextEditingController();
  final _password = TextEditingController();

  bool _entrando = false;
  String? _error;

  /// El código NUEVO que devuelve el servidor. Mientras esté puesto, la hoja
  /// solo enseña eso: es la última oportunidad de guardarlo.
  String? _nuevo;

  @override
  void dispose() {
    _usuario.dispose();
    _codigo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_usuario.text.trim().isEmpty || _codigo.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu usuario y el código.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'La contraseña nueva debe tener al menos 6 caracteres.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _entrando = true;
      _error = null;
    });

    final r = await context.read<AuthRepository>().recuperar(
          usuario: _usuario.text,
          codigo: _codigo.text,
          password: _password.text,
          serverUrl: widget.servidor.trim().isEmpty ? null : widget.servidor,
        );
    if (!mounted) return;

    switch (r) {
      case Ok<String>(:final value):
        setState(() {
          _entrando = false;
          _nuevo = value;
        });
      case Err<String>(:final message):
        setState(() {
          _entrando = false;
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
          child: _nuevo != null
              ? _CodigoNuevo(codigo: _nuevo!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Entrar con el código',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Si olvidaste tu contraseña, el código de recuperación es la '
                      'forma de entrar. Al usarlo pones una contraseña nueva.',
                      style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _usuario,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codigo,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Código de recuperación',
                        hintText: 'El que guardaste',
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña nueva',
                        hintText: 'Mínimo 6 caracteres',
                      ),
                      onSubmitted: (_) => _entrar(),
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
                            onPressed: _entrando ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _entrando ? null : _entrar,
                            child: _entrando
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

/// El código nuevo. Ya se está dentro, así que lo único que queda es guardarlo.
class _CodigoNuevo extends StatelessWidget {
  const _CodigoNuevo({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Listo, y guarda este código',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Ya estás dentro con tu contraseña nueva. El código que usaste ya no '
          'vale: este es el de repuesto, y no se puede volver a ver.',
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
          child: const Text('Ya lo guardé'),
        ),
      ],
    );
  }
}
