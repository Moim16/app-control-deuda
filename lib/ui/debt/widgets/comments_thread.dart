// El hilo de comentarios de una deuda.
//
// Es lo único que puede escribir un usuario de solo lectura, así que aquí no se
// esconde nada por rol: la cajita de escribir la ve todo el mundo.

import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/debt_view_model.dart';

class CommentsThread extends StatefulWidget {
  const CommentsThread({super.key, required this.vm, required this.soloLectura});

  final DebtViewModel vm;

  /// Cambia solo el texto de ayuda: quien es dueño escribe notas, quien mira
  /// pregunta.
  final bool soloLectura;

  @override
  State<CommentsThread> createState() => _CommentsThreadState();
}

class _CommentsThreadState extends State<CommentsThread> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    await widget.vm.comment.run(t);
    if (!mounted) return;
    final error = widget.vm.comment.errorMessage;
    if (error != null) {
      aviso(context, error, malo: true);
    } else {
      _texto.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = widget.vm;
    final lista = vm.comments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.soloLectura
              ? 'Puedes dejar comentarios sobre la deuda en general, o abrir un movimiento para comentar ese en particular.'
              : 'Aquí quedan las notas sobre la deuda en general.',
          style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (lista.isEmpty)
                Vacio('Sin comentarios todavía.', icono: Icons.chat_bubble_outline)
              else
                for (final (i, c) in lista.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              c.userName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                            if (c.byOwner) ...[
                              const SizedBox(width: 6),
                              const Etiqueta('dueño', fuerte: true),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              cuando(c.createdAt),
                              style: TextStyle(fontSize: 12, color: t.faint),
                            ),
                            const Spacer(),
                            if (c.mine)
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 17, color: t.faint),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Borrar',
                                onPressed: () => _confirmarBorrado(c.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.text,
                          style: TextStyle(fontSize: 14.5, color: t.ink, height: 1.4),
                        ),
                      ],
                    ),
                  ),
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
                        onPressed: vm.comment.running ? null : _enviar,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(52, 46),
                          padding: EdgeInsets.zero,
                        ),
                        child: vm.comment.running
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
        ),
      ],
    );
  }

  Future<void> _confirmarBorrado(int id) async {
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
    if (ok == true) await widget.vm.deleteComment(id);
  }
}
