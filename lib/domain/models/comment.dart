// Un comentario. Es lo unico que puede escribir un usuario de solo lectura.

class Comment {
  const Comment({
    required this.id,
    required this.debtId,
    this.entryId,
    required this.userName,
    this.role,
    required this.mine,
    required this.text,
    required this.createdAt,
    this.debtName,
    this.entryKind,
    this.entryDay,
    this.entryAmount,
    this.entryCurrency,
  });

  final int id;
  final int debtId;

  /// null = es un comentario sobre la deuda en general; con id, sobre ese
  /// movimiento en particular.
  final int? entryId;

  final String userName;
  final String? role;

  /// Lo escribi yo: entonces lo puedo borrar.
  final bool mine;

  final String text;
  final String createdAt;

  /// De que deuda es. Viene en los comentarios recientes del resumen.
  final String? debtName;

  /// El movimiento al que se refiere, para poder decir "sobre el abono del 12
  /// de mayo" sin tener que ir a buscarlo.
  final String? entryKind;
  final String? entryDay;
  final double? entryAmount;
  final String? entryCurrency;

  bool get byOwner => role == 'admin';

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as int,
        debtId: j['debtId'] as int,
        entryId: j['entryId'] as int?,
        userName: (j['userName'] as String?) ?? '—',
        role: j['role'] as String?,
        mine: (j['mine'] as bool?) ?? false,
        text: j['text'] as String,
        createdAt: j['createdAt'] as String,
        debtName: j['debtName'] as String?,
        entryKind: j['entryKind'] as String?,
        entryDay: j['entryDay'] as String?,
        entryAmount: (j['entryAmount'] as num?)?.toDouble(),
        entryCurrency: j['entryCurrency'] as String?,
      );
}
