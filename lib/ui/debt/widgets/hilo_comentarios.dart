// =============================================================================
//  Un hilo de comentarios con su cajita para escribir.
//
//  Es la misma pieza para los dos hilos que hay: el de la deuda en general y el
//  de un movimiento en particular. Lo único que cambia es de dónde sale la
//  lista, así que eso lo pone quien lo usa.
//
//  Aquí no se esconde nada por rol: escribir comentarios es justo lo único que
//  puede hacer un usuario de solo lectura, y es la razón de que exista.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../domain/models/comment.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';

class HiloComentarios extends StatefulWidget {
  const HiloComentarios({
    super.key,
    required this.comentarios,
    required this.onEnviar,
    required this.onBorrar,
    this.cargando = false,
    this.vacio = 'Sin comentarios todavía.',
  });

  final List<Comment> comentarios;

  /// Devuelve el error, o null si salió bien.
  final Future<Result<Comment>> Function(String texto) onEnviar;
  final Future<Result<void>> Function(int id) onBorrar;

  final bool cargando;
  final String vacio;

  @override
  State<HiloComentarios> createState() => _HiloComentariosState();
}

class _HiloComentariosState extends State<HiloComentarios> {
  final _texto = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    final r = await widget.onEnviar(t);
    if (!mounted) return;
    setState(() => _enviando = false);
    switch (r) {
      case Ok<Comment>():
        _texto.clear();
        FocusScope.of(context).unfocus();
      case Err<Comment>(:final message):
        aviso(context, message, malo: true);
    }
  }

  Future<void> _borrar(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar el comentario?'),
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
    final r = await widget.onBorrar(id);
    if (!mounted) return;
    if (r case Err<void>(:final message)) aviso(context, message, malo: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lista = widget.comentarios;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (widget.cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (lista.isEmpty)
            Vacio(widget.vacio, icono: Icons.chat_bubble_outline)
          else
            for (final (i, c) in lista.indexed) ...[
              if (i > 0) Divider(height: 1, color: t.line),
              _Comentario(c: c, onBorrar: () => _borrar(c.id)),
            ],
          Divider(height: 1, color: t.line),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _texto,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario…',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _enviando ? null : _enviar,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 46),
                      padding: EdgeInsets.zero,
                    ),
                    child: _enviando
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: t.onInk),
                          )
                        : const Icon(Icons.send, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Comentario extends StatelessWidget {
  const _Comentario({required this.c, required this.onBorrar});

  final Comment c;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  c.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink),
                ),
              ),
              if (c.byOwner) ...[
                const SizedBox(width: 6),
                const Etiqueta('dueño', fuerte: true),
              ],
              const SizedBox(width: 8),
              Text(cuando(c.createdAt), style: TextStyle(fontSize: 12, color: t.faint)),
              const Spacer(),
              if (c.mine)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 17, color: t.faint),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Borrar',
                  onPressed: onBorrar,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(c.text, style: TextStyle(fontSize: 14.5, color: t.ink, height: 1.4)),
        ],
      ),
    );
  }
}
