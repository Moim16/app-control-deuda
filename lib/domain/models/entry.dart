// Un movimiento: un prestamo (sube el saldo) o un abono (lo baja).

enum EntryKind {
  /// Prestamo: sube el saldo.
  loan,

  /// Abono o pago recibido: lo baja.
  payment;

  static EntryKind parse(String? v) => v == 'payment' ? EntryKind.payment : EntryKind.loan;

  String get wire => this == EntryKind.payment ? 'payment' : 'loan';
}

class Entry {
  const Entry({
    required this.id,
    required this.debtId,
    required this.kind,
    required this.currency,
    required this.day,
    required this.amount,
    this.reason,
    this.note,
    required this.hasReceipt,
    required this.commentCount,
    this.createdBy,
    this.createdAt,
  });

  final int id;
  final int debtId;
  final EntryKind kind;

  /// La moneda va en el movimiento, no en la deuda.
  final String currency;

  /// YYYY-MM-DD, la fecha local de Nicaragua.
  final String day;
  final double amount;
  final String? reason;
  final String? note;

  /// Si tiene comprobante. La imagen se pide aparte: la lista se consulta todo
  /// el tiempo y no tiene por que arrastrar fotos.
  final bool hasReceipt;

  final int commentCount;
  final String? createdBy;
  final String? createdAt;

  bool get isLoan => kind == EntryKind.loan;

  /// Cuanto mueve el saldo: un prestamo suma, un abono resta.
  double get signed => isLoan ? amount : -amount;

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as int,
        debtId: j['debtId'] as int,
        kind: EntryKind.parse(j['kind'] as String?),
        currency: (j['currency'] as String?) ?? 'NIO',
        day: j['day'] as String,
        amount: (j['amount'] as num).toDouble(),
        reason: j['reason'] as String?,
        note: j['note'] as String?,
        hasReceipt: (j['hasReceipt'] as bool?) ?? false,
        commentCount: (j['comments'] as int?) ?? 0,
        createdBy: j['createdBy'] as String?,
        createdAt: j['createdAt'] as String?,
      );
}
