// El formulario del vehículo. Al crearlo se crean también sus tareas típicas
// (aceite, llantas, seguro…): empezar con una lista en blanco no le sirve a
// nadie.

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

class VehicleFormSheet extends StatefulWidget {
  const VehicleFormSheet({super.key, this.vehiculo});

  final Vehicle? vehiculo;

  static Future<bool> abrir(BuildContext context, {Vehicle? vehiculo}) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      builder: (_) => VehicleFormSheet(vehiculo: vehiculo),
    );
    return r ?? false;
  }

  @override
  State<VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<VehicleFormSheet> {
  late VehicleDraft _d =
      widget.vehiculo == null ? const VehicleDraft() : VehicleDraft.de(widget.vehiculo!);
  late final TextEditingController _nombre = TextEditingController(text: _d.name);
  late final TextEditingController _placa = TextEditingController(text: _d.plate);
  late final TextEditingController _ano = TextEditingController(text: _d.year);
  late final TextEditingController _nota = TextEditingController(text: _d.note);

  bool _guardando = false;
  bool _intentado = false;
  String? _error;

  bool get _esNuevo => widget.vehiculo == null;

  @override
  void dispose() {
    _nombre.dispose();
    _placa.dispose();
    _ano.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _set(VehicleDraft d) => setState(() {
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
    final r = _esNuevo
        ? await repo.addVehicle(_d.aJson(nuevo: true))
        : await repo.updateVehicle(widget.vehiculo!.id, _d.aJson(nuevo: false));
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
    final v = widget.vehiculo!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar "${v.name}"?'),
        content: Text(
          'Se borran sus ${plural(v.services, 'registro', 'registros')}, sus tareas '
          'y sus facturas. No se puede deshacer.\n\n'
          'Si solo quieres dejar de verlo, archívalo con el interruptor.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.tk.bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    final r = await context.read<VehicleRepository>().deleteVehicle(v.id, conTodo: true);
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
                _esNuevo ? 'Registrar un vehículo' : widget.vehiculo!.name,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              if (_esNuevo) ...[
                const SizedBox(height: 3),
                Text(
                  'Se crean también las tareas típicas de ese tipo de vehículo. '
                  'Después las puedes cambiar.',
                  style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                ),
              ],
              const SizedBox(height: 18),

              Segmentado<VehicleKind>(
                opciones: const [
                  (VehicleKind.moto, 'Moto', Icons.two_wheeler, null),
                  (VehicleKind.car, 'Carro', Icons.directions_car_outlined, null),
                  (VehicleKind.other, 'Otro', Icons.build_outlined, null),
                ],
                elegida: _d.kind,
                onElegir: (k) => _set(_d.copyWith(kind: k)),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nombre,
                autofocus: _esNuevo,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  counterText: '',
                  hintText: 'Mi moto, la Hilux…',
                ),
                onChanged: (v) => _set(_d.copyWith(name: v)),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _placa,
                      maxLength: 20,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Placa (opcional)',
                        counterText: '',
                      ),
                      onChanged: (v) => _set(_d.copyWith(plate: v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ano,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Año (opcional)',
                        counterText: '',
                      ),
                      onChanged: (v) => _set(_d.copyWith(year: v)),
                    ),
                  ),
                ],
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
                  hintText: 'Color, cilindraje, lo que convenga recordar',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) => _set(_d.copyWith(note: v)),
              ),

              if (!_esNuevo) ...[
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _d.active,
                  onChanged: (v) => _set(_d.copyWith(active: v)),
                  title: Text('En uso', style: TextStyle(fontSize: 15, color: t.ink)),
                  subtitle: Text(
                    'Archivado deja de aparecer, y su historial se queda.',
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
                          : Text(_esNuevo ? 'Registrar' : 'Guardar'),
                    ),
                  ),
                ],
              ),

              if (!_esNuevo) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _guardando ? null : _borrar,
                  style: OutlinedButton.styleFrom(foregroundColor: t.bad),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Borrar el vehículo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
