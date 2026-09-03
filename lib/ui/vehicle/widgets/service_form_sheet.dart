// =============================================================================
//  El formulario de un registro del vehículo.
//
//  Lo importante: UN registro con UN monto puede cubrir VARIAS tareas. Es como
//  se hace de verdad — uno lleva la moto a la casa comercial, le hacen aceite,
//  filtro y cadena, y paga un solo monto. Marcarlas todas aquí pone al día las
//  tres, sin inventar tres gastos que no existieron.
//
//  Un accesorio (antivuelco, pescantes) no cubre tareas: no es algo que haya
//  que repetir, así que la lista desaparece al elegir ese tipo.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/spend_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/services/comprobante.dart';
import '../../../domain/models/spend.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/models/vehicle_drafts.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class ServiceFormSheet extends StatefulWidget {
  const ServiceFormSheet({
    super.key,
    required this.vehiculo,
    required this.hoy,
    required this.tareas,
    required this.inicial,
    this.servicio,
  });

  final Vehicle vehiculo;
  final String hoy;
  final List<VehicleTask> tareas;
  final ServiceDraft inicial;
  final Service? servicio;

  static Future<bool> abrir(
    BuildContext context, {
    required Vehicle vehiculo,
    required String hoy,
    required List<VehicleTask> tareas,
    Service? servicio,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      builder: (_) => ServiceFormSheet(
        vehiculo: vehiculo,
        hoy: hoy,
        tareas: tareas,
        servicio: servicio,
        inicial: servicio != null
            ? ServiceDraft.de(servicio)
            : ServiceDraft(vehicleId: vehiculo.id, day: hoy),
      ),
    );
    return r ?? false;
  }

  @override
  State<ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<ServiceFormSheet> {
  late ServiceDraft _d = widget.inicial;
  late final TextEditingController _titulo = TextEditingController(text: _d.title);
  late final TextEditingController _costo = TextEditingController(text: _d.cost);
  late final TextEditingController _km = TextEditingController(text: _d.odometer);
  late final TextEditingController _taller = TextEditingController(text: _d.place);
  late final TextEditingController _nota = TextEditingController(text: _d.note);

  String? _factura;
  bool _buscandoImagen = false;
  bool _guardando = false;
  bool _intentado = false;
  String? _error;

  bool get _esNuevo => widget.servicio == null;

  @override
  void initState() {
    super.initState();
    if (widget.servicio?.hasReceipt ?? false) _cargarFactura();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _costo.dispose();
    _km.dispose();
    _taller.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _cargarFactura() async {
    final r = await context.read<VehicleRepository>().receipt(widget.servicio!.id);
    if (!mounted) return;
    if (r case Ok<String>(:final value)) setState(() => _factura = value);
  }

  void _set(ServiceDraft d) => setState(() {
        _d = d;
        _error = null;
      });

  Future<void> _elegirImagen(Origen origen) async {
    setState(() {
      _buscandoImagen = true;
      _error = null;
    });
    try {
      final uri = await context.read<ComprobanteService>().elegir(origen);
      if (uri != null && mounted) {
        setState(() {
          _factura = uri;
          _d = _d.copyWith(receipt: FacturaNueva(uri));
        });
      }
    } on ComprobanteError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo preparar la imagen.');
    }
    if (mounted) setState(() => _buscandoImagen = false);
  }

  Future<void> _guardar() async {
    setState(() => _intentado = true);
    final mal = _d.problema(hoy: widget.hoy);
    if (mal != null) {
      setState(() => _error = mal);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });

    final repo = context.read<VehicleRepository>();
    final r = _esNuevo
        ? await repo.addService(_d.aJson(nuevo: true))
        : await repo.updateService(widget.servicio!.id, _d.aJson(nuevo: false));
    if (!mounted) return;

    switch (r) {
      case Ok<void>():
        // Si se anotó también como gasto del hogar, esa pantalla ya no vale.
        if (_esNuevo && _d.categoryId != null) {
          await context.read<SpendRepository>().load(force: true);
        }
        if (mounted) Navigator.of(context).pop(true);
      case Err<void>(:final message):
        setState(() {
          _guardando = false;
          _error = message;
        });
    }
  }

  Future<void> _borrar() async {
    final s = widget.servicio!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar el registro?'),
        content: Text(
          [
            'Se borra "${s.title}" del ${fecha(s.day, conAno: true)} y su factura.',
            // Si estaba enlazado con un gasto, se lleva el gasto: la plata no
            // puede quedarse contada por un lado y borrada por el otro.
            if (s.expenseId != null) 'También se borra el gasto del hogar que creó.',
          ].join('\n\n'),
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
    final r = await context.read<VehicleRepository>().deleteService(s.id);
    if (!mounted) return;
    switch (r) {
      case Ok<void>():
        if (s.expenseId != null) {
          await context.read<SpendRepository>().load(force: true);
        }
        if (mounted) Navigator.of(context).pop(true);
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
    final categorias = context.read<SpendRepository>().data?.activas ?? const <ExpenseCategory>[];
    final bytes = bytesDeDataUri(
      switch (_d.receipt) {
        FacturaQuitada() => null,
        _ => _factura,
      },
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _esNuevo ? 'Nuevo registro' : 'Corregir el registro',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 18),

              Segmentado<ServiceKind>(
                opciones: const [
                  (ServiceKind.service, 'Mantenimiento', Icons.build_outlined, null),
                  (ServiceKind.accessory, 'Accesorio', Icons.add_circle_outline, null),
                ],
                elegida: _d.kind,
                onElegir: (k) => _set(_d.copyWith(kind: k)),
              ),
              const SizedBox(height: 6),
              Text(
                _d.esAccesorio
                    ? 'Algo que se le puso: antivuelco, pescantes, llantas. No se repite.'
                    : 'Mantenimiento o reparación. Un solo monto puede cubrir varias tareas.',
                style: TextStyle(fontSize: 12.5, color: t.faint, height: 1.4),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titulo,
                autofocus: _esNuevo,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _d.esAccesorio ? 'Qué se le puso' : 'Qué se le hizo',
                  counterText: '',
                  hintText: _d.esAccesorio
                      ? 'Antivuelco, pescantes…'
                      : 'Mantenimiento de los 6,000',
                ),
                onChanged: (v) => _set(_d.copyWith(title: v)),
              ),
              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _costo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Costo (opcional)',
                        hintText: '0.00',
                      ),
                      onChanged: (v) => _set(_d.copyWith(cost: v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _d.currency,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: [
                        for (final c in Moneda.todas.keys)
                          DropdownMenuItem(
                            value: c,
                            child: Text('${Moneda.de(c).symbol} ${Moneda.de(c).name}'),
                          ),
                      ],
                      onChanged: (c) => c == null ? null : _set(_d.copyWith(currency: c)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Déjalo vacío si fue en garantía: no es lo mismo que costar cero.',
                style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _km,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Kilometraje',
                        hintText: widget.vehiculo.odometer?.toString() ?? '0',
                        suffixText: 'km',
                      ),
                      onChanged: (v) => _set(_d.copyWith(odometer: v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CampoFecha(
                      etiqueta: 'Fecha',
                      dia: _d.day,
                      hoy: widget.hoy,
                      onCambiar: (v) => _set(_d.copyWith(day: v)),
                      ayuda: 'Fecha del registro',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                // Sin km anotados no hay forma de decir "faltan 1,200 km".
                'Anotar el kilometraje es lo que permite avisarte cuándo toca lo '
                'siguiente.',
                style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _taller,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Dónde (opcional)',
                  counterText: '',
                  hintText: 'La casa comercial, el taller de la esquina…',
                ),
                onChanged: (v) => _set(_d.copyWith(place: v)),
              ),

              // Las tareas que cubre. Solo en un mantenimiento.
              if (!_d.esAccesorio && widget.tareas.isNotEmpty) ...[
                const Seccion('Qué tareas cubre'),
                Text(
                  'Marca todas las que se hicieron: con un solo monto se ponen '
                  'al día todas.',
                  style: TextStyle(fontSize: 12.5, color: t.muted, height: 1.4),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, x) in widget.tareas.indexed) ...[
                        if (i > 0) Divider(height: 1, color: t.line),
                        CheckboxListTile(
                          value: _d.taskIds.contains(x.id),
                          onChanged: (_) => _set(_d.alternarTarea(x.id)),
                          title: Text(x.name, style: TextStyle(fontSize: 14.5, color: t.ink)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Anotarlo también como gasto del hogar. Solo al crear: al editar,
              // el servidor mueve el gasto enlazado por su cuenta.
              if (_esNuevo && categorias.isNotEmpty) ...[
                const Seccion('¿Anotarlo también como gasto del hogar?'),
                DropdownButtonFormField<int?>(
                  initialValue: _d.categoryId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No anotarlo')),
                    for (final c in categorias)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (id) => _set(
                    id == null ? _d.copyWith(sinCategoria: true) : _d.copyWith(categoryId: id),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Así la plata figura una sola vez: el gasto queda enlazado a este '
                  'registro, y borrarlo se lleva el gasto.',
                  style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
                ),
              ],

              const Seccion('Factura'),
              if (_buscandoImagen)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 34),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (bytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: Colors.white,
                    constraints: const BoxConstraints(maxHeight: 240),
                    width: double.infinity,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _factura = null;
                    _d = _d.copyWith(receipt: const FacturaQuitada());
                  }),
                  style: OutlinedButton.styleFrom(foregroundColor: t.bad),
                  icon: const Icon(Icons.close, size: 17),
                  label: const Text('Quitar'),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirImagen(Origen.camara),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Cámara'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirImagen(Origen.galeria),
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),

              TextField(
                controller: _nota,
                maxLength: 500,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  counterText: '',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) => _set(_d.copyWith(note: v)),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Aviso(_error!, tono: Tono.malo, icono: Icons.error_outline),
              ] else if (_intentado && _d.problema(hoy: widget.hoy) != null) ...[
                const SizedBox(height: 14),
                Aviso(
                  _d.problema(hoy: widget.hoy)!,
                  tono: Tono.malo,
                  icono: Icons.error_outline,
                ),
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
                  label: const Text('Borrar el registro'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
