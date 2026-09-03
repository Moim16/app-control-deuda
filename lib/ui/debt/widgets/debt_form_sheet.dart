// =============================================================================
//  El formulario de una deuda: crearla, editarla, cerrarla o borrarla.
//
//  Aquí NO se pide el monto, y eso es lo más importante del formulario. Una
//  deuda no nace con una cifra: nace con un nombre ("mi hermano") y se va
//  llenando de préstamos, que es como uno se entera de cuánto debe. El texto de
//  arriba lo dice con esas palabras porque la primera versión pedía el monto y
//  no había forma de crear nada sin saberlo.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/debt_draft.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/debt_form_view_model.dart';

/// Lo que pasó en el formulario, para que quien lo abrió sepa qué hacer.
sealed class ResultadoDeuda {
  const ResultadoDeuda();
}

/// Se creó: se devuelve para poder abrirla enseguida y registrar el primer
/// préstamo, que es lo único que tiene sentido hacer a continuación.
class DeudaCreada extends ResultadoDeuda {
  const DeudaCreada(this.debt);
  final Debt debt;
}

class DeudaGuardada extends ResultadoDeuda {
  const DeudaGuardada();
}

class DeudaBorrada extends ResultadoDeuda {
  const DeudaBorrada();
}

class DebtFormSheet extends StatefulWidget {
  const DebtFormSheet({super.key});

  /// Abre el formulario. `debt` null = una deuda nueva.
  static Future<ResultadoDeuda?> abrir(
    BuildContext context, {
    required String hoy,
    required DebtDirection direccion,
    Debt? debt,
  }) {
    final debts = context.read<DebtRepository>();

    return showModalBottomSheet<ResultadoDeuda>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => DebtFormViewModel(
          debts: debts,
          debt: debt,
          inicial: debt != null
              ? DebtDraft.de(debt, hoy: hoy)
              : DebtDraft(direction: direccion, dueFrom: hoy),
        ),
        child: const DebtFormSheet(),
      ),
    );
  }

  @override
  State<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<DebtFormSheet> {
  late final TextEditingController _nombre;
  late final TextEditingController _quien;
  late final TextEditingController _nota;
  late final TextEditingController _interes;
  late final TextEditingController _cuota;

  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    final d = context.read<DebtFormViewModel>().draft;
    _nombre = TextEditingController(text: d.name);
    _quien = TextEditingController(text: d.counterpart);
    _nota = TextEditingController(text: d.note);
    _interes = TextEditingController(text: d.interestRate);
    _cuota = TextEditingController(text: d.dueAmount);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _quien.dispose();
    _nota.dispose();
    _interes.dispose();
    _cuota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final vm = context.read<DebtFormViewModel>();
    setState(() => _intentado = true);
    if (!vm.puedeGuardar) return;
    FocusScope.of(context).unfocus();
    await vm.guardar.run();
    if (!mounted || vm.guardar.errorMessage != null) return;

    final creada = vm.debtCreada;
    Navigator.of(context).pop(
      creada != null ? DeudaCreada(creada) : const DeudaGuardada(),
    );
  }

  Future<void> _borrar() async {
    final vm = context.read<DebtFormViewModel>();
    final lado = _lado(vm.draft.direction);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar "${vm.draft.name.trim()}"?'),
        content: Text(
          'Se borran sus ${plural(vm.movimientos, 'movimiento', 'movimientos')}, '
          'comprobantes y comentarios. No se puede deshacer.\n\n'
          'Si solo quieres dejar de ver ${lado == Lado.meDeben ? 'este cobro' : 'esta deuda'}, '
          'ciérrala en vez de borrarla.',
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

    await vm.borrar.run();
    if (!mounted) return;
    final error = vm.borrar.errorMessage;
    if (error != null) {
      aviso(context, error, malo: true);
      return;
    }
    Navigator.of(context).pop(const DeudaBorrada());
  }

  /// El formulario es del dueño, así que las palabras salen de la dirección tal
  /// cual: no hay que invertir nada.
  static Lado _lado(DebtDirection d) => d == DebtDirection.owed ? Lado.meDeben : Lado.debo;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<DebtFormViewModel>();
    final d = vm.draft;
    final lado = _lado(d.direction);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                vm.esNueva ? lado.nuevo : d.name.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                vm.esNueva
                    ? lado.ayudaNueva
                    : 'Los ${lado.prestamos.toLowerCase()} y ${lado.abonos.toLowerCase()} '
                        'se registran en la pantalla anterior, no aquí.',
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
              ),
              const SizedBox(height: 18),

              // Cambiar la dirección no toca los movimientos: lo que era "me
              // prestó" pasa a leerse "le presté". Sirve cuando se creó al revés.
              Segmentado<DebtDirection>(
                opciones: [
                  (DebtDirection.owe, 'Yo debo', Icons.arrow_upward, t.bad),
                  (DebtDirection.owed, 'Me deben', Icons.arrow_downward, t.ok),
                ],
                elegida: d.direction,
                onElegir: vm.cambiarDireccion,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nombre,
                autofocus: vm.esNueva,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: lado.quien,
                  counterText: '',
                  hintText: lado.pistaQuien,
                ),
                onChanged: vm.cambiarNombre,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DebtKind>(
                      initialValue: d.kind,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: [
                        for (final k in DebtKind.values)
                          DropdownMenuItem(value: k, child: Text(k.label)),
                      ],
                      onChanged: (k) => k == null ? null : vm.cambiarTipo(k),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: d.currency,
                      decoration: const InputDecoration(labelText: 'Moneda habitual'),
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
              const SizedBox(height: 4),
              Text(
                'Cada movimiento puede ir en otra moneda; esta es la que se propone.',
                style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _quien,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: lado.otro,
                  counterText: '',
                  hintText: lado.pistaOtro,
                ),
                onChanged: vm.cambiarContraparte,
              ),

              Seccion(lado.acuerdo),
              Text(
                lado.ayudaAcuerdo,
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DueEvery?>(
                initialValue: d.dueEvery,
                decoration: const InputDecoration(labelText: 'Cada cuánto'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin acuerdo fijo')),
                  for (final e in DueEvery.values)
                    DropdownMenuItem(value: e, child: Text(e.label)),
                ],
                onChanged: vm.cambiarFrecuencia,
              ),

              // Sin frecuencia no hay nada que preguntar: los dos campos que la
              // acompañan solo aparecen cuando hay acuerdo.
              if (d.tieneAcuerdo) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cuota,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: const InputDecoration(
                          labelText: 'Cuánto cada vez',
                          hintText: '500',
                        ),
                        onChanged: vm.cambiarCuota,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CampoFecha(
                        etiqueta: 'Primer pago',
                        dia: d.dueFrom,
                        onCambiar: vm.cambiarDesde,
                        // El primer pago acordado puede ser futuro: es una fecha
                        // del acuerdo, no la de algo que ya pasó.
                        hastaDias: 366 * 2,
                        ayuda: 'Fecha del primer pago',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),
              TextField(
                controller: _interes,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(
                  labelText: 'Interés anual (%)',
                  hintText: '0',
                ),
                onChanged: vm.cambiarInteres,
              ),
              const SizedBox(height: 4),
              Text(
                'Solo lo usa el simulador; el saldo registrado no cambia solo. '
                'Entre familia normalmente va vacío.',
                style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _nota,
                maxLength: 300,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nota',
                  counterText: '',
                  hintText: 'Acuerdos, fecha límite, lo que haga falta recordar',
                  alignLabelWithHint: true,
                ),
                onChanged: vm.cambiarNota,
              ),

              if (!vm.esNueva) ...[
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: d.active,
                  onChanged: vm.cambiarAbierta,
                  title: Text(lado.abierta, style: TextStyle(fontSize: 15, color: t.ink)),
                  subtitle: Text(
                    'Cerrada = saldada o archivada. No se borra nada.',
                    style: TextStyle(fontSize: 12.5, color: t.faint),
                  ),
                ),
              ],

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
                      onPressed: vm.guardar.running ? null : () => Navigator.of(context).pop(),
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
                          : Text(vm.esNueva ? lado.crear : 'Guardar'),
                    ),
                  ),
                ],
              ),

              // Borrar va abajo, separado y en rojo: no se toca por error.
              if (!vm.esNueva) ...[
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: vm.borrar.running ? null : _borrar,
                  style: OutlinedButton.styleFrom(foregroundColor: t.bad),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Borrar definitivamente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
