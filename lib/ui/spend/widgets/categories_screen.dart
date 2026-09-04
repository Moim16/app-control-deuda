// Las categorías del gasto y su presupuesto mensual.
//
// Archivar y borrar no son lo mismo, y la diferencia importa: al borrar, sus
// gastos NO se borran — quedan "sin categoría", porque la plata se gastó igual.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/spend_repository.dart';
import '../../../domain/models/spend.dart';
import '../../../domain/models/spend_drafts.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final repo = context.watch<SpendRepository>();
    final data = repo.data;
    final activas = data?.categories.where((c) => c.active).toList() ?? const [];
    final archivadas = data?.categories.where((c) => !c.active).toList() ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías'), bottom: const BarraCargando()),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-categorias',
        onPressed: () => _abrirForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Categoría'),
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                Text(
                  'El presupuesto es un tope que uno se propone, no una regla: '
                  'pasarse no bloquea nada, solo se pinta en rojo.',
                  style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                ),
                const SizedBox(height: 14),
                if (activas.isEmpty)
                  Card(child: Vacio('Todavía no hay categorías.', icono: Icons.label_outline))
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, c) in activas.indexed) ...[
                          if (i > 0) Divider(height: 1, color: t.line),
                          _Fila(c: c, onTap: () => _abrirForm(context, c)),
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
                        for (final (i, c) in archivadas.indexed) ...[
                          if (i > 0) Divider(height: 1, color: t.line),
                          _Fila(c: c, onTap: () => _abrirForm(context, c)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _abrirForm(BuildContext context, [ExpenseCategory? c]) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _Form(categoria: c),
    );
    if (guardado == true && context.mounted) aviso(context, 'Guardado');
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.c, required this.onTap});

  final ExpenseCategory c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ListTile(
      title: Text(
        c.name,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
      ),
      subtitle: Text(
        [
          c.budget != null ? 'Tope ${plata(c.budget, c.currency)} al mes' : 'Sin tope',
          plural(c.expenses, 'gasto', 'gastos'),
        ].join(' · '),
        style: TextStyle(fontSize: 12.5, color: t.muted),
      ),
      trailing: c.active ? Icon(Icons.chevron_right, color: t.faint) : const Etiqueta('archivada'),
      onTap: onTap,
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({this.categoria});

  final ExpenseCategory? categoria;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late CategoryDraft _d = widget.categoria == null
      ? const CategoryDraft()
      : CategoryDraft.de(widget.categoria!);
  late final TextEditingController _nombre = TextEditingController(text: _d.name);
  late final TextEditingController _tope = TextEditingController(text: _d.budget);

  bool _guardando = false;
  bool _intentado = false;
  String? _error;

  bool get _esNueva => widget.categoria == null;

  @override
  void dispose() {
    _nombre.dispose();
    _tope.dispose();
    super.dispose();
  }

  void _set(CategoryDraft d) => setState(() {
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

    final repo = context.read<SpendRepository>();
    final r = _esNueva
        ? await repo.addCategory(_d.aJson(nueva: true))
        : await repo.updateCategory(widget.categoria!.id, _d.aJson(nueva: false));
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
    final c = widget.categoria!;
    final conGastos = c.expenses > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar "${c.name}"?'),
        content: Text(
          conGastos
              // Esto es lo que hay que decir: la gente teme perder el historial.
              ? 'Sus ${plural(c.expenses, 'gasto', 'gastos')} NO se borran: quedan '
                    'como "sin categoría", porque la plata se gastó igual.\n\n'
                    'Si solo quieres dejar de usarla, archívala con el interruptor.'
              : 'No tiene gastos, así que no se pierde nada.',
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
    final r = await context.read<SpendRepository>().deleteCategory(c.id, conTodo: true);
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
                _esNueva ? 'Nueva categoría' : widget.categoria!.name,
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
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  counterText: '',
                  hintText: 'Comida, Casa, Transporte…',
                ),
                onChanged: (v) => _set(_d.copyWith(name: v)),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _tope,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Tope al mes (opcional)',
                        hintText: '0',
                      ),
                      onChanged: (v) => _set(_d.copyWith(budget: v)),
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
                'Un tope en córdobas no limita un gasto en dólares: son dos cuentas.',
                style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
              ),

              if (!_esNueva) ...[
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _d.active,
                  onChanged: (v) => _set(_d.copyWith(active: v)),
                  title: Text('En uso', style: TextStyle(fontSize: 15, color: t.ink)),
                  subtitle: Text(
                    'Archivada deja de aparecer al anotar, y su historial se queda.',
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
                  label: const Text('Borrar la categoría'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
