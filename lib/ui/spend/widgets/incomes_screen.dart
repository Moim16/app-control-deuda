// Los ingresos: el sueldo y lo que entra una sola vez.
//
// La diferencia entre los dos no es de etiqueta: el SUELDO rige desde su fecha
// y hacia adelante, así que un aumento se anota con su fecha y los meses viejos
// siguen contando lo que se ganaba entonces. Lo de una sola vez cuenta solo en
// el mes en que cayó.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/spend_repository.dart';
import '../../../domain/gastos.dart';
import '../../../domain/models/spend.dart';
import '../../../domain/models/spend_drafts.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class IncomesScreen extends StatelessWidget {
  const IncomesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final repo = context.watch<SpendRepository>();
    final data = repo.data;
    final hoy = data?.today ?? hoyLocal();

    final sueldos = data?.incomes.where((i) => i.esSueldo).toList() ?? const <Income>[];
    final extras = data?.incomes.where((i) => !i.esSueldo).toList() ?? const <Income>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Ingresos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-ingresos',
        onPressed: () => _abrirForm(context, hoy: hoy),
        icon: const Icon(Icons.add),
        label: const Text('Ingreso'),
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                Text(
                  'Con esto la app puede decirte cuánto te queda de verdad al mes '
                  'y cuánto puedes abonar sin quedarte corto.',
                  style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                ),

                // El sueldo vigente por moneda, que es lo que rige hoy.
                for (final cur in _monedasCon(data.incomes)) ...[
                  const SizedBox(height: 14),
                  _Vigente(data: data, moneda: cur, hoy: hoy),
                ],

                const Seccion('El sueldo'),
                if (sueldos.isEmpty)
                  Card(
                    child: Vacio(
                      'Todavía no has anotado tu ingreso mensual.',
                      icono: Icons.payments_outlined,
                      accion: FilledButton.icon(
                        onPressed: () => _abrirForm(context, hoy: hoy),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Anotar mi sueldo'),
                      ),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, x) in _ordenados(sueldos).indexed) ...[
                          if (i > 0) Divider(height: 1, color: t.line),
                          _Fila(
                            i: x,
                            subtitulo: 'Desde ${fecha(x.day, conAno: true)}',
                            onTap: () => _abrirForm(context, hoy: hoy, ingreso: x),
                          ),
                        ],
                      ],
                    ),
                  ),

                if (extras.isNotEmpty) ...[
                  const Seccion('Lo que entró una sola vez'),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, x) in _ordenados(extras).indexed) ...[
                          if (i > 0) Divider(height: 1, color: t.line),
                          _Fila(
                            i: x,
                            subtitulo: fecha(x.day, conAno: true),
                            onTap: () => _abrirForm(context, hoy: hoy, ingreso: x),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                Text(
                  'Un aumento se anota como un sueldo nuevo con su fecha: los meses '
                  'de antes siguen contando lo que ganabas entonces.',
                  style: TextStyle(fontSize: 12.5, color: t.faint, height: 1.45),
                ),
              ],
            ),
    );
  }

  static List<String> _monedasCon(List<Income> ingresos) {
    final set = <String>{};
    for (final i in ingresos.where((x) => x.esSueldo)) {
      set.add(i.currency);
    }
    return set.toList()..sort((a, b) => a == 'NIO' ? -1 : 1);
  }

  /// Del más nuevo al más viejo.
  static List<Income> _ordenados(List<Income> l) => [...l]..sort((a, b) => b.day.compareTo(a.day));

  Future<void> _abrirForm(BuildContext context, {required String hoy, Income? ingreso}) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _Form(hoy: hoy, ingreso: ingreso),
    );
    if (guardado == true && context.mounted) aviso(context, 'Guardado');
  }
}

/// Lo que rige este mes en una moneda: el dato que de verdad se usa.
class _Vigente extends StatelessWidget {
  const _Vigente({required this.data, required this.moneda, required this.hoy});

  final SpendData data;
  final String moneda;
  final String hoy;

  @override
  Widget build(BuildContext context) {
    final ing = ingresoDe(data.incomes, hoy.substring(0, 7), moneda);
    if (!ing.hay) return const SizedBox.shrink();

    return MontoGrande(
      titulo: 'Este mes entra (${Moneda.de(moneda).name})',
      monto: ing.total,
      moneda: moneda,
      detalle: [
        'Sueldo ${plata(ing.sueldo, moneda)}',
        if (ing.sueldoDesde != null) 'desde ${fecha(ing.sueldoDesde, conAno: true)}',
        if (ing.extra > 0) '+ ${plata(ing.extra, moneda)} de extras',
      ].join(' · '),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.i, required this.subtitulo, required this.onTap});

  final Income i;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ListTile(
      title: Text(
        (i.source?.trim().isNotEmpty ?? false)
            ? i.source!.trim()
            : (i.esSueldo ? 'Sueldo' : 'Ingreso'),
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
      ),
      subtitle: Text(subtitulo, style: TextStyle(fontSize: 12.5, color: t.muted)),
      trailing: Text(
        plata(i.amount, i.currency),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: t.ok,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.hoy, this.ingreso});

  final String hoy;
  final Income? ingreso;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late IncomeDraft _d = widget.ingreso == null
      ? IncomeDraft(day: widget.hoy)
      : IncomeDraft.de(widget.ingreso!);
  late final TextEditingController _monto = TextEditingController(text: _d.amount);
  late final TextEditingController _fuente = TextEditingController(text: _d.source);
  late final TextEditingController _nota = TextEditingController(text: _d.note);

  bool _guardando = false;
  bool _intentado = false;
  String? _error;

  bool get _esNuevo => widget.ingreso == null;

  @override
  void dispose() {
    _monto.dispose();
    _fuente.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _set(IncomeDraft d) => setState(() {
    _d = d;
    _error = null;
  });

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
        ? await repo.addIncome(_d.aJson())
        : await repo.updateIncome(widget.ingreso!.id, _d.aJson());
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
        title: const Text('¿Borrar el ingreso?'),
        content: Text(
          widget.ingreso!.esSueldo
              // Borrar un sueldo viejo cambia lo que la app cree que se ganaba
              // en esos meses, y eso mueve la capacidad de pago.
              ? 'Los meses que regía este sueldo volverán a contar el anterior.'
              : 'Se quita de los ingresos de ese mes.',
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
    final r = await context.read<SpendRepository>().deleteIncome(widget.ingreso!.id);
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
                _esNuevo ? 'Anotar un ingreso' : 'Corregir el ingreso',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 18),

              Segmentado<IncomeKind>(
                opciones: const [
                  (IncomeKind.monthly, 'Cada mes', Icons.event_repeat_outlined, null),
                  (IncomeKind.once, 'Una sola vez', Icons.bolt_outlined, null),
                ],
                elegida: _d.kind,
                onElegir: (k) => _set(_d.copyWith(kind: k)),
              ),
              const SizedBox(height: 6),
              Text(
                _d.esSueldo
                    ? 'El sueldo: rige desde la fecha que pongas y hacia adelante.'
                    : 'Aguinaldo, un trabajito: cuenta solo en el mes en que entró.',
                style: TextStyle(fontSize: 12.5, color: t.faint, height: 1.4),
              ),
              const SizedBox(height: 16),

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

              CampoFecha(
                etiqueta: _d.esSueldo ? 'Desde cuándo ganas eso' : 'Cuándo entró',
                dia: _d.day,
                hoy: widget.hoy,
                // Un aumento ya acordado puede empezar el mes que viene.
                hastaDias: _d.esSueldo ? 366 : 1,
                onCambiar: (v) => _set(_d.copyWith(day: v)),
                ayuda: _d.esSueldo ? 'Desde cuándo rige' : 'Fecha del ingreso',
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _fuente,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'De dónde (opcional)',
                  counterText: '',
                  hintText: _d.esSueldo ? 'Mi trabajo, la empresa…' : 'Aguinaldo, un trabajito…',
                ),
                onChanged: (v) => _set(_d.copyWith(source: v)),
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
                  label: const Text('Borrar el ingreso'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
