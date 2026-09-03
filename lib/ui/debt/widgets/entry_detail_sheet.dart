// El detalle de un movimiento, con su comprobante.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/services/comprobante.dart';
import '../../../domain/models/entry.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';

/// Lo que se pidio desde el detalle. La hoja no corrige ni borra: devuelve la
/// intencion y se cierra, y de eso se encarga la pantalla que la abrio.
enum AccionMovimiento { corregir, borrar }

class EntryDetailSheet extends StatefulWidget {
  const EntryDetailSheet({
    super.key,
    required this.entry,
    required this.lado,
    required this.cargarComprobante,
    this.puedeEditar = false,
  });

  final Entry entry;
  final Lado lado;

  /// Se pasa la función en vez del repositorio: esta hoja no necesita saber de
  /// dónde sale la imagen.
  final Future<Result<String>> Function(int entryId) cargarComprobante;

  /// Solo el dueño corrige o borra. Quien mira de solo lectura ve el detalle
  /// completo, incluido el comprobante, pero sin los botones.
  final bool puedeEditar;

  @override
  State<EntryDetailSheet> createState() => _EntryDetailSheetState();
}

class _EntryDetailSheetState extends State<EntryDetailSheet> {
  Uint8List? _imagen;
  String? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry.hasReceipt) _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final r = await widget.cargarComprobante(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      switch (r) {
        case Ok<String>(:final value):
          _imagen = bytesDeDataUri(value);
          if (_imagen == null) _error = 'No se pudo leer la imagen.';
        case Err<String>(:final message):
          _error = message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final e = widget.entry;
    final color = e.isLoan ? t.bad : t.ok;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: e.isLoan ? t.badBg : t.okBg,
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    e.isLoan ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.isLoan ? widget.lado.prestamo : widget.lado.abono} · ${fechaLarga(e.day)}',
                        style: TextStyle(fontSize: 13, color: t.muted),
                      ),
                      Text(
                        '${e.isLoan ? '+' : '−'}${plata(e.amount, e.currency)}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _Dato('Motivo', e.reason ?? '—'),
                  if (e.note?.trim().isNotEmpty == true) ...[
                    Divider(height: 1, color: t.line),
                    _Dato('Nota', e.note!),
                  ],
                  Divider(height: 1, color: t.line),
                  _Dato('Registró', '${e.createdBy ?? '—'} · ${cuando(e.createdAt)}'),
                ],
              ),
            ),
            const Seccion('Comprobante'),
            if (!e.hasReceipt)
              Card(child: Vacio('Sin comprobante.', icono: Icons.image_outlined))
            else if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Aviso(_error!, tono: Tono.malo)
            else if (_imagen != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.white,
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image.memory(_imagen!, fit: BoxFit.contain),
                  ),
                ),
              ),
            if (widget.puedeEditar) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(AccionMovimiento.corregir),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Corregir'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(AccionMovimiento.borrar),
                      style: OutlinedButton.styleFrom(foregroundColor: t.bad),
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('Borrar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.titulo, this.valor);

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(titulo, style: TextStyle(fontSize: 13, color: t.muted)),
          ),
          Expanded(
            child: Text(valor, style: TextStyle(fontSize: 14.5, color: t.ink, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
