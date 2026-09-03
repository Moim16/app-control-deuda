// =============================================================================
//  Quién más entra a la cuenta.
//
//  Un usuario de solo lectura ve ÚNICAMENTE las deudas que se le asignen, y lo
//  único que puede escribir son comentarios. Sin ninguna marcada no ve nada:
//  eso no es un error, es lo que significa no haberle compartido todavía, y por
//  eso la pantalla lo dice en vez de dejarlo pasar en silencio.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/me.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Usuario>? _usuarios;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await context.read<AuthRepository>().usuarios();
    if (!mounted) return;
    setState(() {
      switch (r) {
        case Ok<List<Usuario>>(:final value):
          _usuarios = value;
          _error = null;
        case Err<List<Usuario>>(:final message):
          _error = message;
      }
    });
  }

  Future<void> _abrir([Usuario? u]) async {
    final deudas = context.read<DebtRepository>().summary?.debts ?? const <Debt>[];
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      builder: (_) => _Form(usuario: u, deudas: deudas),
    );
    if (guardado != true || !mounted) return;
    aviso(context, 'Guardado');
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final yo = context.read<AuthRepository>().me;
    final lista = _usuarios;

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios con acceso')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-usuarios',
        onPressed: () => _abrir(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Dar acceso'),
      ),
      body: _error != null && lista == null
          ? ErrorConReintento(mensaje: _error!, onReintentar: _cargar)
          : lista == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                Text(
                  'Quien entra a ver tus cuentas. Un usuario de solo lectura ve '
                  'únicamente lo que le asignes y puede comentar, nada más.',
                  style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                ),
                const SizedBox(height: 14),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, u) in lista.indexed) ...[
                        if (i > 0) Divider(height: 1, color: t.line),
                        _Fila(
                          u: u,
                          soyYo: u.id == yo?.id,
                          // A uno mismo no se edita desde aquí: la
                          // contraseña propia va en Ajustes, y quitarse los
                          // permisos a sí mismo deja la cuenta sin dueño.
                          onTap: u.id == yo?.id ? null : () => _abrir(u),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.u, required this.soyYo, this.onTap});

  final Usuario u;
  final bool soyYo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ListTile(
      title: Row(
        children: [
          Flexible(
            child: Text(
              u.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ),
          if (soyYo) ...[const SizedBox(width: 6), const Etiqueta('yo')],
          if (!u.active) ...[const SizedBox(width: 6), const Etiqueta('inactivo', tono: Tono.malo)],
        ],
      ),
      subtitle: Text(
        [
          if (u.fullName?.trim().isNotEmpty ?? false) u.fullName!.trim(),
          u.isOwner
              ? 've y edita todo'
              : u.debtIds.isEmpty
              // Es lo que hay que decir: un viewer sin asignaciones entra y
              // no ve nada, y desde fuera parece que la app falla.
              ? 'sin nada asignado: no ve nada'
              : plural(u.debtIds.length, 'deuda asignada', 'deudas asignadas'),
        ].join(' · '),
        style: TextStyle(
          fontSize: 12.5,
          color: (!u.isOwner && u.debtIds.isEmpty) ? t.half : t.muted,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Etiqueta(u.isOwner ? 'dueño' : 'lectura', fuerte: u.isOwner),
          if (onTap != null) Icon(Icons.chevron_right, color: t.faint),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({this.usuario, required this.deudas});

  final Usuario? usuario;
  final List<Debt> deudas;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController _usuario = TextEditingController();
  late final TextEditingController _nombre = TextEditingController(
    text: widget.usuario?.fullName ?? '',
  );
  late final TextEditingController _password = TextEditingController();

  late String _rol = widget.usuario?.role ?? 'viewer';
  late bool _activo = widget.usuario?.active ?? true;
  late final Set<int> _debtIds = {...?widget.usuario?.debtIds};

  bool _guardando = false;
  String? _error;

  bool get _esNuevo => widget.usuario == null;

  @override
  void dispose() {
    _usuario.dispose();
    _nombre.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _problema {
    if (_esNuevo) {
      final n = _usuario.text.trim();
      if (n.isEmpty) return 'Ponle un usuario.';
      if (n.contains(RegExp(r'\s'))) return 'El usuario no puede llevar espacios.';
      if (_password.text.length < 6) {
        return 'La contraseña debe tener al menos 6 caracteres.';
      }
    } else if (_password.text.isNotEmpty && _password.text.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final mal = _problema;
    if (mal != null) {
      setState(() => _error = mal);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });

    final auth = context.read<AuthRepository>();
    final r = _esNuevo
        ? await auth.crearUsuario({
            'name': _usuario.text.trim(),
            'password': _password.text,
            'fullName': _nombre.text.trim(),
            'role': _rol,
            'debtIds': _debtIds.toList(),
          })
        : await auth.editarUsuario(widget.usuario!.id, {
            'fullName': _nombre.text.trim(),
            'role': _rol,
            'active': _activo,
            'debtIds': _debtIds.toList(),
            if (_password.text.isNotEmpty) 'password': _password.text,
          });
    if (!mounted) return;

    switch (r) {
      case Ok<void>():
        Navigator.of(context).pop(true);
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
    final esViewer = _rol != 'admin';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _esNuevo ? 'Dar acceso a alguien' : widget.usuario!.name,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 18),

              if (_esNuevo) ...[
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
                    hintText: 'hermano',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 14),
              ],

              TextField(
                controller: _nombre,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre (opcional)', counterText: ''),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _rol,
                decoration: const InputDecoration(labelText: 'Permisos'),
                items: const [
                  DropdownMenuItem(value: 'viewer', child: Text('Solo lectura')),
                  DropdownMenuItem(value: 'admin', child: Text('Dueño')),
                ],
                onChanged: (v) => setState(() => _rol = v ?? 'viewer'),
              ),
              const SizedBox(height: 4),
              Text(
                esViewer
                    ? 'Ve lo que le asignes y puede comentar. Nada más.'
                    : 'Ve y edita todo, igual que tú: gastos, vehículo y todas las deudas.',
                style: TextStyle(fontSize: 12, color: esViewer ? t.faint : t.half, height: 1.4),
              ),

              // A un dueño no se le asignan deudas: las ve todas.
              if (esViewer) ...[
                const Seccion('Qué puede ver'),
                if (widget.deudas.isEmpty)
                  Card(
                    child: Vacio(
                      'Primero crea una deuda o un cobro.',
                      icono: Icons.account_balance_wallet_outlined,
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, d) in widget.deudas.indexed) ...[
                          if (i > 0) Divider(height: 1, color: t.line),
                          CheckboxListTile(
                            value: _debtIds.contains(d.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _debtIds.add(d.id);
                              } else {
                                _debtIds.remove(d.id);
                              }
                              _error = null;
                            }),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            title: Text(
                              d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.5, color: t.ink),
                            ),
                            subtitle: Text(
                              [
                                d.isReceivable ? 'me deben' : 'yo debo',
                                for (final c in d.currencies) plata(d.pendingIn(c), c),
                                if (!d.active) 'cerrada',
                              ].join(' · '),
                              style: TextStyle(fontSize: 12, color: t.faint),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  _debtIds.isEmpty
                      ? 'Sin ninguna marcada no verá nada al entrar.'
                      : 'Solo verá lo marcado, y desde el otro lado: su deuda se le '
                            'cuenta como "me deben".',
                  style: TextStyle(
                    fontSize: 12,
                    color: _debtIds.isEmpty ? t.half : t.faint,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _esNuevo ? 'Contraseña' : 'Nueva contraseña',
                  hintText: _esNuevo ? 'Mínimo 6 caracteres' : 'Vacío = no cambiarla',
                ),
                onChanged: (_) => setState(() => _error = null),
              ),

              if (!_esNuevo) ...[
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                  title: Text('Puede entrar', style: TextStyle(fontSize: 15, color: t.ink)),
                  subtitle: Text(
                    'Apagado no puede entrar, y sus comentarios se quedan.',
                    style: TextStyle(fontSize: 12.5, color: t.faint),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Aviso(_error!, tono: Tono.malo, icono: Icons.error_outline),
              ],

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
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
                          : Text(_esNuevo ? 'Crear' : 'Guardar'),
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
