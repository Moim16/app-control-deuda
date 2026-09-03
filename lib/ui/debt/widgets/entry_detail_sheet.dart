// El detalle de un movimiento: sus datos, su comprobante y su hilo de
// comentarios.
//
// La hoja no corrige ni borra: devuelve lo que se pidió y se cierra. Así el
// formulario y el diálogo de borrado no se abren encima de un modal que se
// está yendo.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/services/comprobante.dart';
import '../../../domain/models/comment.dart';
import '../../../domain/models/entry.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/debt_view_model.dart';
import 'hilo_comentarios.dart';

/// Lo que se pidió desde el detalle.
enum AccionMovimiento { corregir, borrar }

class EntryDetailSheet extends StatefulWidget {
  const EntryDetailSheet({
    super.key,
    required this.entry,
    required this.lado,
    required this.vm,
    this.puedeEditar = false,
  });

  final Entry entry;
  final Lado lado;
  final DebtViewModel vm;

  /// Solo el dueño corrige o borra. Quien mira de solo lectura ve el detalle
  /// completo, comprobante incluido, y puede comentar; pero no toca nada.
  final bool puedeEditar;

  @override
  State<EntryDetailSheet> createState() => _EntryDetailSheetState();
}

class _EntryDetailSheetState extends State<EntryDetailSheet> {
  Uint8List? _imagen;
  String? _errorImagen;
  bool _cargandoImagen = false;

  List<Comment> _comentarios = const [];
  bool _cargandoComentarios = true;

  @override
  void initState() {
    super.initState();
    if (widget.entry.hasReceipt) _cargarImagen();
    _cargarComentarios();
  }

  Future<void> _cargarImagen() async {
    setState(() => _cargandoImagen = true);
    final r = await widget.vm.receipt(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _cargandoImagen = false;
      switch (r) {
        case Ok<String>(:final value):
          _imagen = bytesDeDataUri(value);
          if (_imagen == null) _errorImagen = 'No se pudo leer la imagen.';
        case Err<String>(:final message):
          _errorImagen = message;
      }
    });
  }

  Future<void> _cargarComentarios() async {
    final r = await widget.vm.commentsOf(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _cargandoComentarios = false;
      if (r case Ok<List<Comment>>(:final value)) _comentarios = value;
    });
  }

  Future<Result<Comment>> _enviar(String texto) async {
    final r = await widget.vm.commentOn(widget.entry.id, texto);
    if (r case Ok<Comment>(:final value)) {
      if (mounted) setState(() => _comentarios = [..._comentarios, value]);
    }
    return r;
  }

  Future<Result<void>> _borrarComentario(int id) async {
    final r = await widget.vm.borrarComentario(id);
    if (r.isOk && mounted) {
      setState(() => _comentarios = _comentarios.where((c) => c.id != id).toList());
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final e = widget.entry;
    final color = e.isLoan ? t.bad : t.ok;

    return SafeArea(
      child: Padding(
        // El teclado del comentario no puede tapar la cajita donde se escribe.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                          '${e.isLoan ? widget.lado.prestamo : widget.lado.abono} · '
                          '${fechaLarga(e.day)}',
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
              else if (_cargandoImagen)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorImagen != null)
                Aviso(_errorImagen!, tono: Tono.malo)
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

              // El hilo de ESTE movimiento. Es lo que hace que un comentario se
              // pueda pegar a "los 500 del sábado" en vez de a la deuda entera.
              const Seccion('Comentarios'),
              HiloComentarios(
                comentarios: _comentarios,
                cargando: _cargandoComentarios,
                onEnviar: _enviar,
                onBorrar: _borrarComentario,
                vacio: 'Sin comentarios sobre este movimiento.',
              ),

              if (widget.puedeEditar) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(AccionMovimiento.corregir),
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
