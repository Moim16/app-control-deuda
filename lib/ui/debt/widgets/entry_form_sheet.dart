// =============================================================================
//  El formulario de un movimiento: registrar un préstamo o un abono, o corregir
//  uno que ya está.
//
//  Es una hoja y no una pantalla aparte a propósito: se abre desde la ficha de
//  la deuda, se llena en diez segundos y se cierra dejando ver lo que cambió.
//
//  Las palabras las pone el `Lado`, no este archivo: el dueño registra "un
//  abono", su hermano ve "un pago recibido", y es el mismo formulario.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../data/services/comprobante.dart';
import '../../../domain/models/entry.dart';
import '../../../domain/models/entry_draft.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/entry_form_view_model.dart';

class EntryFormSheet extends StatefulWidget {
  const EntryFormSheet({super.key, required this.lado});

  final Lado lado;

  /// Abre el formulario. Devuelve true si se guardó algo, para que quien lo
  /// abrió sepa si tiene que refrescar.
  ///
  /// Los repositorios se leen ANTES de abrir: dentro del `builder` del modal el
  /// contexto es otro, y así no hay que confiar en que lo herede.
  static Future<bool> abrir(
    BuildContext context, {
    required int debtId,
    required Lado lado,
    required String hoy,
    required EntryKind kind,
    required String currency,
    Entry? entry,
  }) async {
    final debts = context.read<DebtRepository>();
    final comprobantes = context.read<ComprobanteService>();

    final guardado = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // Que un toque fuera no tire lo que se estaba escribiendo.
      isDismissible: false,
      enableDrag: false,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => EntryFormViewModel(
          debts: debts,
          comprobantes: comprobantes,
          debtId: debtId,
          hoy: hoy,
          entry: entry,
          inicial: entry != null
              ? EntryDraft.de(entry)
              : EntryDraft(kind: kind, day: hoy, amount: '', currency: currency),
        )..cargarComprobanteActual(),
        child: EntryFormSheet(lado: lado),
      ),
    );
    return guardado ?? false;
  }

  @override
  State<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<EntryFormSheet> {
  late final TextEditingController _monto;
  late final TextEditingController _motivo;
  late final TextEditingController _nota;

  /// Se muestra el problema solo cuando ya se intentó guardar: señalar en rojo
  /// un formulario que la persona todavía no ha terminado de llenar es ruido.
  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    final d = context.read<EntryFormViewModel>().draft;
    _monto = TextEditingController(text: d.amount);
    _motivo = TextEditingController(text: d.reason);
    _nota = TextEditingController(text: d.note);
  }

  @override
  void dispose() {
    _monto.dispose();
    _motivo.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final vm = context.read<EntryFormViewModel>();
    setState(() => _intentado = true);
    if (!vm.puedeGuardar) return;
    FocusScope.of(context).unfocus();
    await vm.guardar.run();
    if (!mounted) return;
    if (vm.guardar.errorMessage == null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<EntryFormViewModel>();
    final lado = widget.lado;
    final esPrestamo = vm.draft.kind == EntryKind.loan;
    final palabra = esPrestamo ? lado.prestamo : lado.abono;

    return SafeArea(
      child: Padding(
        // Sin esto el teclado tapa el botón de guardar.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                vm.esNuevo ? palabra : 'Corregir el movimiento',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                vm.esNuevo
                    ? (esPrestamo ? lado.ayudaPrestamo : lado.ayudaAbono)
                    : 'Lo que cambies aquí recalcula el saldo.',
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.4),
              ),
              const SizedBox(height: 18),

              // Al registrar, el tipo ya lo decidió el botón que abrió esto. Al
              // corregir sí hay que poder cambiarlo: un abono mal cargado como
              // préstamo deja el saldo al revés.
              if (!vm.esNuevo) ...[
                Segmentado<EntryKind>(
                  opciones: [
                    (EntryKind.loan, lado.prestamo, Icons.arrow_upward, t.bad),
                    (EntryKind.payment, lado.abono, Icons.arrow_downward, t.ok),
                  ],
                  elegida: vm.draft.kind,
                  onElegir: vm.cambiarKind,
                ),
                const SizedBox(height: 16),
              ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _monto,
                      autofocus: vm.esNuevo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // Solo dígitos, coma de miles y punto decimal: así no se
                      // puede escribir un monto que la API vaya a rechazar.
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        hintText: '0.00',
                      ),
                      onChanged: vm.cambiarMonto,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: vm.draft.currency,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: [
                        for (final c in Moneda.todas.keys)
                          DropdownMenuItem(
                            value: c,
                            child: Text('${Moneda.de(c).symbol} ${Moneda.de(c).name}'),
                          ),
                      ],
                      onChanged: (c) => c == null ? null : vm.cambiarMoneda(c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              CampoFecha(
                etiqueta: 'Fecha',
                dia: vm.draft.day,
                hoy: vm.hoy,
                onCambiar: vm.cambiarDia,
                ayuda: 'Fecha del movimiento',
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _motivo,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Motivo',
                  counterText: '',
                  hintText: esPrestamo ? lado.pistaMotivoPrestamo : lado.pistaMotivoAbono,
                ),
                onChanged: vm.cambiarMotivo,
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
                  hintText: 'Cualquier detalle que convenga recordar',
                  alignLabelWithHint: true,
                ),
                onChanged: vm.cambiarNota,
              ),

              const Seccion('Comprobante'),
              _Comprobante(vm: vm),

              if (vm.errorImagen != null) ...[
                const SizedBox(height: 12),
                Aviso(vm.errorImagen!, tono: Tono.malo, icono: Icons.error_outline),
              ],

              // El error de guardar y el de validación no se pisan: si la API
              // dijo algo, es lo que hay que leer.
              if (vm.guardar.errorMessage != null) ...[
                const SizedBox(height: 14),
                Aviso(vm.guardar.errorMessage!, tono: Tono.malo, icono: Icons.error_outline),
              ] else if (_intentado && vm.problema != null) ...[
                const SizedBox(height: 14),
                Aviso(vm.problema!, tono: Tono.malo, icono: Icons.error_outline),
              ],

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: vm.guardar.running ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: vm.guardar.running ? null : _guardar,
                      child: vm.guardar.running
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: t.onInk),
                            )
                          : Text(vm.esNuevo ? 'Registrar' : 'Guardar cambios'),
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

/* ------------------------------------------------------------ comprobante -- */

class _Comprobante extends StatelessWidget {
  const _Comprobante({required this.vm});

  final EntryFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bytes = bytesDeDataUri(vm.comprobante);

    if (vm.buscandoImagen) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 34),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (bytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _menu(context),
                  icon: const Icon(Icons.swap_horiz, size: 17),
                  label: const Text('Reemplazar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vm.quitarComprobante,
                  style: OutlinedButton.styleFrom(foregroundColor: t.bad),
                  icon: const Icon(Icons.close, size: 17),
                  label: const Text('Quitar'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Sin imagen: los dos caminos a la vista, sin un menú de por medio.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => vm.elegirComprobante(Origen.camara),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Cámara'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => vm.elegirComprobante(Origen.galeria),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('Galería'),
          ),
        ),
      ],
    );
  }

  Future<void> _menu(BuildContext context) async {
    final origen = await showModalBottomSheet<Origen>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(ctx, Origen.camara),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, Origen.galeria),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origen != null) await vm.elegirComprobante(origen);
  }
}
