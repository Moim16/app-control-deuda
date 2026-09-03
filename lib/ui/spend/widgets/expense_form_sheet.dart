// El formulario de un gasto del hogar: anotarlo, corregirlo o borrarlo.
//
// La captura del recibo pasa por el mismo servicio que el comprobante de un
// movimiento: la API exige JPEG en los dos sitios y por la misma razón.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/spend_repository.dart';
import '../../../data/services/comprobante.dart';
import '../../../domain/models/spend.dart';
import '../../../domain/models/spend_drafts.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class ExpenseFormSheet extends StatefulWidget {
  const ExpenseFormSheet({
    super.key,
    required this.hoy,
    required this.categorias,
    required this.inicial,
    this.gasto,
  });

  final String hoy;
  final List<ExpenseCategory> categorias;
  final ExpenseDraft inicial;
  final Expense? gasto;

  /// Devuelve true si se guardó o se borró algo.
  static Future<bool> abrir(
    BuildContext context, {
    required String hoy,
    required List<ExpenseCategory> categorias,
    required String monedaPorDefecto,
    Expense? gasto,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      builder: (_) => ExpenseFormSheet(
        hoy: hoy,
        categorias: categorias,
        gasto: gasto,
        inicial: gasto != null
            ? ExpenseDraft.de(gasto)
            : ExpenseDraft(
                day: hoy,
                currency: monedaPorDefecto,
                // Con una sola categoría no hay nada que elegir.
                categoryId: categorias.length == 1 ? categorias.first.id : null,
              ),
      ),
    );
    return r ?? false;
  }

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  late ExpenseDraft _d = widget.inicial;
  late final TextEditingController _monto = TextEditingController(text: _d.amount);
  late final TextEditingController _motivo = TextEditingController(text: _d.reason);
  late final TextEditingController _nota = TextEditingController(text: _d.note);

  String? _captura;
  bool _buscandoImagen = false;
  bool _guardando = false;
  bool _intentado = false;
  String? _error;

  bool get _esNuevo => widget.gasto == null;

  @override
  void initState() {
    super.initState();
    if (widget.gasto?.hasReceipt ?? false) _cargarCaptura();
  }

  @override
  void dispose() {
    _monto.dispose();
    _motivo.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _cargarCaptura() async {
    final r = await context.read<SpendRepository>().receipt(widget.gasto!.id);
    if (!mounted) return;
    if (r case Ok<String>(:final value)) setState(() => _captura = value);
  }

  void _set(ExpenseDraft d) => setState(() {
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
          _captura = uri;
          _d = _d.copyWith(receipt: CapturaNueva(uri));
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

    final repo = context.read<SpendRepository>();
    final r = _esNuevo
        ? await repo.addExpense(_d.aJson(nuevo: true))
        : await repo.updateExpense(widget.gasto!.id, _d.aJson(nuevo: false));
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
        title: const Text('¿Borrar el gasto?'),
        content: Text(
          'Se borra ${plata(widget.gasto!.amount, widget.gasto!.currency)} del '
          '${fecha(widget.gasto!.day, conAno: true)} y su captura.',
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
    final r = await context.read<SpendRepository>().deleteExpense(widget.gasto!.id);
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
    final bytes = bytesDeDataUri(
      switch (_d.receipt) {
        CapturaQuitada() => null,
        _ => _captura,
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
                _esNuevo ? 'Anotar un gasto' : 'Corregir el gasto',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _monto,
                      autofocus: _esNuevo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Monto', hintText: '0.00'),
                      onChanged: (v) => _set(_d.copyWith(amount: v)),
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
              const SizedBox(height: 14),

              DropdownButtonFormField<int?>(
                initialValue: _d.categoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin categoría')),
                  for (final c in widget.categorias)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (id) => _set(
                  id == null
                      ? _d.copyWith(sinCategoria: true)
                      : _d.copyWith(categoryId: id),
                ),
              ),
              const SizedBox(height: 14),

              CampoFecha(
                etiqueta: 'Fecha',
                dia: _d.day,
                hoy: widget.hoy,
                onCambiar: (v) => _set(_d.copyWith(day: v)),
                ayuda: 'Fecha del gasto',
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _motivo,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'En qué',
                  counterText: '',
                  hintText: 'Súper, recarga, taxi…',
                ),
                onChanged: (v) => _set(_d.copyWith(reason: v)),
              ),
              const SizedBox(height: 14),

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

              const Seccion('Captura del recibo'),
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
                    _captura = null;
                    _d = _d.copyWith(receipt: const CapturaQuitada());
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
                          : Text(_esNuevo ? 'Anotar' : 'Guardar'),
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
                  label: const Text('Borrar el gasto'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
