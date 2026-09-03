// =============================================================================
//  Ajustes: quién soy, cómo se ve la app, quién más entra y mi contraseña.
//
//  Lo que un usuario de solo lectura ve aquí es una parte pequeña: su cuenta y
//  el tema. Los usuarios, el nombre de la cuenta y todo lo demás son del dueño.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/avisos_repository.dart';
import '../../../data/repositories/tema_repository.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/cerrar_sesion.dart';
import '../../core/widgets/comunes.dart';
import 'users_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final auth = context.watch<AuthRepository>();
    final tema = context.watch<TemaRepository>();
    final me = auth.me;
    if (me == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AJUSTES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: t.faint,
              ),
            ),
            Text(
              me.accountName ?? 'Mi cuenta',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  me.initials,
                  style: TextStyle(color: t.onInk, fontWeight: FontWeight.w700),
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      me.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Etiqueta(me.isOwner ? 'dueño' : 'solo lectura', fuerte: me.isOwner),
                ],
              ),
              subtitle: Text(me.fullName ?? me.accountName ?? ''),
            ),
          ),

          const Seccion('Recordatorios'),
          _Avisos(),

          const Seccion('Apariencia'),
          Segmentado<ThemeMode>(
            opciones: const [
              (ThemeMode.system, 'Sistema', Icons.brightness_auto_outlined, null),
              (ThemeMode.light, 'Claro', Icons.light_mode_outlined, null),
              (ThemeMode.dark, 'Oscuro', Icons.dark_mode_outlined, null),
            ],
            elegida: tema.modo,
            onElegir: tema.cambiar,
          ),

          if (me.isOwner) ...[
            const Seccion('La cuenta'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.badge_outlined, color: t.muted),
                    title: const Text('Nombre de la cuenta'),
                    subtitle: Text(
                      me.accountName ?? '—',
                      style: TextStyle(fontSize: 12.5, color: t.faint),
                    ),
                    trailing: Icon(Icons.chevron_right, color: t.faint),
                    onTap: () => _renombrar(context, auth),
                  ),
                  Divider(height: 1, color: t.line),
                  ListTile(
                    leading: Icon(Icons.people_outline, color: t.muted),
                    title: const Text('Usuarios con acceso'),
                    subtitle: Text(
                      'Quién más entra a ver tus deudas',
                      style: TextStyle(fontSize: 12.5, color: t.faint),
                    ),
                    trailing: Icon(Icons.chevron_right, color: t.faint),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsersScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Seccion('Seguridad'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.key_outlined, color: t.muted),
                  title: const Text('Cambiar mi contraseña'),
                  trailing: Icon(Icons.chevron_right, color: t.faint),
                  onTap: () => _cambiarPassword(context, auth),
                ),
                Divider(height: 1, color: t.line),
                ListTile(
                  leading: Icon(Icons.shield_outlined, color: t.muted),
                  title: const Text('Código de recuperación'),
                  subtitle: Text(
                    auth.recuperacion.tiene
                        ? 'Ya tienes uno${auth.recuperacion.desde != null ? ' · ${cuando(auth.recuperacion.desde)}' : ''}'
                        : 'Todavía no tienes: sin él no hay forma de volver a entrar',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: auth.recuperacion.tiene ? t.faint : t.half,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: t.faint),
                  onTap: () => _codigo(context, auth),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => _salir(context, auth),
            style: OutlinedButton.styleFrom(foregroundColor: t.bad),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 18),
          Text(
            'Deudas · la misma cuenta que la versión web',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.faint),
          ),
        ],
      ),
    );
  }

  Future<void> _renombrar(BuildContext context, AuthRepository auth) async {
    final nombre = await _pedirTexto(
      context,
      titulo: 'Nombre de la cuenta',
      etiqueta: 'Nombre',
      inicial: auth.me?.accountName ?? '',
      maxLargo: 80,
    );
    if (nombre == null || !context.mounted) return;

    final r = await auth.renombrarCuenta(nombre);
    if (!context.mounted) return;
    switch (r) {
      case Ok<void>():
        aviso(context, 'Guardado');
      case Err<void>(:final message):
        aviso(context, message, malo: true);
    }
  }

  Future<void> _cambiarPassword(BuildContext context, AuthRepository auth) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _PasswordSheet(auth: auth),
      );

  Future<void> _codigo(BuildContext context, AuthRepository auth) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _CodigoSheet(auth: auth),
      );

  Future<void> _salir(BuildContext context, AuthRepository auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a escribir tu usuario y contraseña.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.tk.bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await cerrarSesion(context);
  }
}

/// El interruptor de los recordatorios y a qué hora llegan.
///
/// Se dice CUÁNTOS quedaron puestos: prometer avisos y que la persona no sepa
/// si funcionan es peor que no ofrecerlos.
class _Avisos extends StatelessWidget {
  const _Avisos();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final avisos = context.watch<AvisosRepository>();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            value: avisos.activo,
            onChanged: (v) async {
              if (!v) {
                await avisos.desactivar();
                return;
              }
              final ok = await avisos.activar();
              if (!ok && context.mounted) {
                aviso(
                  context,
                  'Android no dio permiso para las notificaciones. '
                  'Se activa desde los ajustes del teléfono.',
                  malo: true,
                );
              }
            },
            title: Text(
              'Avisarme cuándo toca',
              style: TextStyle(fontSize: 15, color: t.ink),
            ),
            subtitle: Text(
              'Los pagos acordados y lo que le toca al vehículo. Funciona sin '
              'internet: el teléfono los guarda y los muestra a su hora.',
              style: TextStyle(fontSize: 12.5, color: t.faint, height: 1.4),
            ),
          ),
          if (avisos.activo) ...[
            Divider(height: 1, color: t.line),
            ListTile(
              leading: Icon(Icons.schedule, color: t.muted),
              title: const Text('A qué hora'),
              subtitle: Text(
                '${avisos.hora.toString().padLeft(2, '0')}:00',
                style: TextStyle(fontSize: 12.5, color: t.faint),
              ),
              trailing: Icon(Icons.chevron_right, color: t.faint),
              onTap: () async {
                final h = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: avisos.hora, minute: 0),
                  helpText: 'A qué hora avisar',
                  cancelText: 'Cancelar',
                  confirmText: 'Listo',
                  // Solo importa la hora: los minutos no cambian nada y pedirlos
                  // es una decisión de más.
                  initialEntryMode: TimePickerEntryMode.dialOnly,
                );
                if (h != null) await avisos.cambiarHora(h.hour);
              },
            ),
            Divider(height: 1, color: t.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Aviso(
                !avisos.permiso
                    ? 'Android tiene las notificaciones bloqueadas para esta app. '
                        'Se permiten desde los ajustes del teléfono.'
                    : avisos.puestos == 0
                        ? 'Nada que recordar todavía: los avisos salen de los '
                            'acuerdos de pago y de las tareas del vehículo.'
                        : '${plural(avisos.puestos, 'recordatorio puesto', 'recordatorios puestos')}.',
                tono: !avisos.permiso
                    ? Tono.malo
                    : avisos.puestos == 0
                        ? Tono.normal
                        : Tono.bueno,
                icono: !avisos.permiso
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un cuadro para escribir una sola cosa. Devuelve null si se canceló.
Future<String?> _pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String inicial = '',
  int maxLargo = 80,
}) async {
  final c = TextEditingController(text: inicial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: maxLargo,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: etiqueta, counterText: ''),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  c.dispose();
  return (r == null || r.isEmpty) ? null : r;
}

/* ============================================================ contraseña == */

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.auth});

  final AuthRepository auth;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nueva.text.length < 6) {
      setState(() => _error = 'La contraseña nueva debe tener al menos 6 caracteres.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final r = await widget.auth.cambiarPassword(actual: _actual.text, nueva: _nueva.text);
    if (!mounted) return;
    switch (r) {
      case Ok<void>():
        Navigator.of(context).pop();
        aviso(context, 'Contraseña cambiada');
      case Err<void>(:final message):
        setState(() {
          _guardando = false;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cambiar mi contraseña',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _actual,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Contraseña actual'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nueva,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  hintText: 'Mínimo 6 caracteres',
                ),
                onSubmitted: (_) => _guardar(),
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
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: t.onInk),
                            )
                          : const Text('Cambiar'),
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

/* =============================================================== código == */

class _CodigoSheet extends StatefulWidget {
  const _CodigoSheet({required this.auth});

  final AuthRepository auth;

  @override
  State<_CodigoSheet> createState() => _CodigoSheetState();
}

class _CodigoSheetState extends State<_CodigoSheet> {
  final _password = TextEditingController();
  bool _generando = false;
  String? _error;

  /// El código recién generado. Se enseña UNA sola vez.
  String? _codigo;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _generar() async {
    setState(() {
      _generando = true;
      _error = null;
    });
    final r = await widget.auth.generarCodigo(_password.text);
    if (!mounted) return;
    switch (r) {
      case Ok<String>(:final value):
        setState(() {
          _generando = false;
          _codigo = value;
        });
      case Err<String>(:final message):
        setState(() {
          _generando = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tiene = widget.auth.recuperacion.tiene;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: _codigo != null
              ? _Guardalo(codigo: _codigo!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Código de recuperación',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Es tu llave de repuesto si olvidas la contraseña. Se enseña '
                      'una sola vez: guárdalo en un lugar seguro. Generar uno nuevo '
                      'invalida el anterior.',
                      style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    Aviso(
                      tiene
                          ? 'Ya tienes un código. Si lo perdiste, genera otro.'
                          : 'Sin código, si olvidas la contraseña no hay forma de entrar: '
                              'no hay correo configurado.',
                      tono: tiene ? Tono.bueno : Tono.aviso,
                      icono: Icons.shield_outlined,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Tu contraseña actual'),
                      onSubmitted: (_) => _generar(),
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
                            onPressed: _generando ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _generando ? null : _generar,
                            child: _generando
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: t.onInk,
                                    ),
                                  )
                                : Text(tiene ? 'Generar uno nuevo' : 'Generar código'),
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

/// El código, una sola vez. Grande, copiable y con un botón que obliga a
/// reconocer que se guardó.
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
          'Guarda este código',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Es la única forma de volver a entrar si olvidas tu contraseña. '
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
          child: const Text('Ya lo guardé'),
        ),
      ],
    );
  }
}
