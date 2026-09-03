// Las tareas de mantenimiento de un vehículo: qué hay que hacerle y cada
// cuánto.
//
// Los dos intervalos (km y meses) son opcionales y se pueden poner los dos:
// entonces manda el que llegue primero, que es como funciona de verdad — el
// aceite toca a los 3,000 km o a los 6 meses, lo que pase antes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/models/vehicle_drafts.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.vehiculo});

  final Vehicle vehiculo;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final data = context.watch<VehicleRepository>().data;
    final todas = data?.tasks.where((x) => x.vehicleId == vehiculo.id).toList() ?? const [];
    final activas = todas.where((x) => x.active).toList();
    final archivadas = todas.where((x) => !x.active).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Tareas de ${vehiculo.name}')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-tareas',
        onPressed: () => _abrir(context),
        icon: const Icon(Icons.add),
        label: const Text('Tarea'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Text(
            'Cada tarea puede tocar por kilómetros, por tiempo, o por las dos '
            'cosas: entonces manda la que llegue primero.',
            style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          if (activas.isEmpty)
            Card(child: Vacio('No hay tareas todavía.', icono: Icons.checklist_outlined))
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, x) in activas.indexed) ...[
                    if (i > 0) Divider(height: 1, color: t.line),
                    _Fila(x: x, onTap: () => _abrir(context, x)),
                  ],
                ],
              ),
            ),
          if (archivadas.isNotEmpty) ...[
            const Seccion('Archivadas'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, x) in archivadas.indexed) ...[
                    if (i > 0) Divider(height: 1, color: t.line),
                    _Fila(x: x, onTap: () => _abrir(context, x)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrir(BuildContext context, [VehicleTask? tarea]) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _Form(vehicleId: vehiculo.id, tarea: tarea),
    );
    if (guardado == true && context.mounted) aviso(context, 'Guardado');
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.x, required this.onTap});

  final VehicleTask x;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final intervalos = [
      if (x.everyKm != null) 'cada ${soloNumero(x.everyKm)} km',
      if (x.everyMonths != null) 'cada ${plural(x.everyMonths!, 'mes', 'meses')}',
    ];

    return ListTile(
      title: Text(
        x.name,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
      ),
      subtitle: Text(
        intervalos.isEmpty ? 'Sin intervalo: no se puede avisar' : intervalos.join(' · '),
        style: TextStyle(fontSize: 12.5, color: intervalos.isEmpty ? t.half : t.muted),
      ),
      trailing: x.active ? Icon(Icons.chevron_right, color: t.faint) : const Etiqueta('archivada'),
      onTap: onTap,
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.vehicleId, this.tarea});

  final int vehicleId;
  final VehicleTask? tarea;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late TaskDraft _d = widget.tarea == null
      ? TaskDraft(vehicleId: widget.vehicleId)
      : TaskDraft.de(widget.tarea!);
  late final TextEditingController _nombre = TextEditingController(text: _d.name);
  late final TextEditingController _km = TextEditingController(text: _d.everyKm);
  late final TextEditingController _meses = TextEditingController(text: _d.everyMonths);
  late final TextEditingController _nota = TextEditingController(text: _d.note);

  bool _guardando = false;
  bool _intentado = false;
  String? _error;

  bool get _esNueva => widget.tarea == null;

  @override
  void dispose() {
    _nombre.dispose();
    _km.dispose();
    _meses.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _set(TaskDraft d) => setState(() {
    _d = d;
    _error = null;
  });

  Future<void> _guardar() async {
    setState(() => _intentado = true);
    if (!_d.esValido) {
      setState(() => _error = _d.problema);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });

    final repo = context.read<VehicleRepository>();
    final r = _esNueva
        ? await repo.addTask(_d.aJson(nueva: true))
        : await repo.updateTask(widget.tarea!.id, _d.aJson(nueva: false));
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

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar "${widget.tarea!.name}"?'),
        content: const Text(
          // Lo mismo que con las categorías: nadie quiere perder el historial.
          'Los registros que la cubrían NO se borran: quedan sin esa tarea, '
          'porque el trabajo se hizo igual.\n\n'
          'Si solo quieres dejar de usarla, archívala con el interruptor.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.tk.bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    final r = await context.read<VehicleRepository>().deleteTask(widget.tarea!.id, conTodo: true);
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _esNueva ? 'Nueva tarea' : widget.tarea!.name,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 18),

              TextField(
                controller: _nombre,
                autofocus: _esNueva,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Qué hay que hacerle',
                  counterText: '',
                  hintText: 'Cambio de aceite, llantas, seguro…',
                ),
                onChanged: (v) => _set(_d.copyWith(name: v)),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _km,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Cada cuántos km',
                        hintText: '3000',
                      ),
                      onChanged: (v) => _set(_d.copyWith(everyKm: v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _meses,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Cada cuántos meses',
                        hintText: '6',
                      ),
                      onChanged: (v) => _set(_d.copyWith(everyMonths: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _d.sinIntervalo
                    ? 'Sin ningún intervalo la tarea se guarda igual, pero la app '
                          'no puede avisarte cuándo toca.'
                    : 'Puedes poner los dos: manda el que llegue primero.',
                style: TextStyle(
                  fontSize: 12,
                  color: _d.sinIntervalo ? t.half : t.faint,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _nota,
                maxLength: 300,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  counterText: '',
                  hintText: 'Qué aceite, qué medida de llanta…',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) => _set(_d.copyWith(note: v)),
              ),

              if (!_esNueva) ...[
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _d.active,
                  onChanged: (v) => _set(_d.copyWith(active: v)),
                  title: Text('En uso', style: TextStyle(fontSize: 15, color: t.ink)),
                  subtitle: Text(
                    'Archivada deja de aparecer, y su historial se queda.',
                    style: TextStyle(fontSize: 12.5, color: t.faint),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Aviso(_error!, tono: Tono.malo, icono: Icons.error_outline),
              ] else if (_intentado && _d.problema != null) ...[
                const SizedBox(height: 14),
                Aviso(_d.problema!, tono: Tono.malo, icono: Icons.error_outline),
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
                          : Text(_esNueva ? 'Crear' : 'Guardar'),
                    ),
                  ),
                ],
              ),

              if (!_esNueva) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _guardando ? null : _borrar,
                  style: OutlinedButton.styleFrom(foregroundColor: t.bad),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Borrar la tarea'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
