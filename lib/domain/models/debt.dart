// Una deuda o un cobro. Es la misma cosa vista desde un lado o del otro.

/// Los totales en UNA moneda. Nunca se suman entre monedas: no hay tipo de
/// cambio en esta app, y sumar córdobas con dólares seria inventarse uno.
class Totals {
  const Totals({required this.loaned, required this.paid, required this.balance});

  final double loaned;
  final double paid;
  final double balance;

  factory Totals.fromJson(Map<String, dynamic> j) => Totals(
        loaned: (j['loaned'] as num).toDouble(),
        paid: (j['paid'] as num).toDouble(),
        balance: (j['balance'] as num).toDouble(),
      );
}

/// Con quien es la deuda: una persona, una tarjeta, otra cosa.
enum DebtKind {
  person,
  card,
  other;

  static DebtKind parse(String? v) => switch (v) {
        'card' => DebtKind.card,
        'other' => DebtKind.other,
        _ => DebtKind.person,
      };

  String get label => switch (this) {
        DebtKind.person => 'Persona',
        DebtKind.card => 'Tarjeta',
        DebtKind.other => 'Otra',
      };

  String get wire => switch (this) {
        DebtKind.person => 'person',
        DebtKind.card => 'card',
        DebtKind.other => 'other',
      };
}

/// De que lado esta la plata.
enum DebtDirection {
  /// Yo debo: una deuda.
  owe,

  /// Me deben: un cobro.
  owed;

  static DebtDirection parse(String? v) => v == 'owed' ? DebtDirection.owed : DebtDirection.owe;

  String get wire => this == DebtDirection.owed ? 'owed' : 'owe';

  DebtDirection get flipped => this == DebtDirection.owed ? DebtDirection.owe : DebtDirection.owed;
}

/// Cada cuanto se acordo pagar.
enum DueEvery {
  weekly,
  biweekly,
  monthly;

  static DueEvery? parse(String? v) => switch (v) {
        'weekly' => DueEvery.weekly,
        'biweekly' => DueEvery.biweekly,
        'monthly' => DueEvery.monthly,
        _ => null,
      };

  String get label => switch (this) {
        DueEvery.weekly => 'Cada semana',
        DueEvery.biweekly => 'Cada quincena',
        DueEvery.monthly => 'Cada mes',
      };

  String get wire => switch (this) {
        DueEvery.weekly => 'weekly',
        DueEvery.biweekly => 'biweekly',
        DueEvery.monthly => 'monthly',
      };
}

/// El acuerdo de pago, cuando lo hay. Al usuario de solo lectura no le llega:
/// el servidor no se lo manda.
class PaymentPlan {
  const PaymentPlan({required this.every, required this.amount, required this.from});

  final DueEvery every;
  final double amount;

  /// El primer pago acordado, en YYYY-MM-DD.
  final String from;

  static PaymentPlan? fromJson(Map<String, dynamic> j) {
    final every = DueEvery.parse(j['dueEvery'] as String?);
    final amount = (j['dueAmount'] as num?)?.toDouble();
    final from = j['dueFrom'] as String?;
    if (every == null || amount == null || from == null) return null;
    return PaymentPlan(every: every, amount: amount, from: from);
  }
}

class Debt {
  const Debt({
    required this.id,
    required this.name,
    required this.kind,
    required this.currency,
    required this.direction,
    this.counterpart,
    this.note,
    this.interestRate,
    required this.active,
    required this.totals,
    required this.currencies,
    required this.entryCount,
    this.lastDay,
    this.plan,
    this.lastPaymentDay,
    this.viewers,
  });

  final int id;
  final String name;
  final DebtKind kind;

  /// La moneda que se propone al registrar. Cada movimiento lleva la suya, asi
  /// que una deuda puede tener una parte en córdobas y otra en dólares.
  final String currency;

  final DebtDirection direction;
  final String? counterpart;
  final String? note;

  /// Interes anual en %. Solo lo usa el simulador: el saldo registrado no
  /// cambia solo. Entre familia normalmente va vacio.
  final double? interestRate;

  final bool active;

  /// Los totales, uno por cada moneda en la que haya algo.
  final Map<String, Totals> totals;
  final List<String> currencies;

  final int entryCount;
  final String? lastDay;
  final PaymentPlan? plan;
  final String? lastPaymentDay;

  /// Cuantas personas tienen acceso. Solo le llega al dueño.
  final int? viewers;

  bool get isReceivable => direction == DebtDirection.owed;

  /// Ya hubo movimientos y no queda saldo en ninguna moneda.
  bool get settled =>
      entryCount > 0 && currencies.every((c) => (totals[c]?.balance ?? 0) <= 0);

  /// Lo que falta, sumado solo dentro de cada moneda y sin contar los saldos a
  /// favor (un abono de mas no "resta" de otra moneda).
  double pendingIn(String currency) {
    final b = totals[currency]?.balance ?? 0;
    return b > 0 ? b : 0;
  }

  /// La moneda que conviene mostrar: la pedida si la tiene, si no la habitual,
  /// si no la primera que haya.
  String currencyToShow(String? preferred) {
    if (preferred != null && currencies.contains(preferred)) return preferred;
    if (currencies.contains(currency)) return currency;
    return currencies.isEmpty ? currency : currencies.first;
  }

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: j['id'] as int,
        name: j['name'] as String,
        kind: DebtKind.parse(j['kind'] as String?),
        currency: j['currency'] as String,
        direction: DebtDirection.parse(j['direction'] as String?),
        counterpart: j['counterpart'] as String?,
        note: j['note'] as String?,
        interestRate: (j['interestRate'] as num?)?.toDouble(),
        active: (j['active'] as int) == 1,
        totals: (j['totals'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, Totals.fromJson(v as Map<String, dynamic>))),
        currencies: (j['currencies'] as List).cast<String>(),
        entryCount: j['entries'] as int,
        lastDay: j['lastDay'] as String?,
        plan: PaymentPlan.fromJson(j),
        lastPaymentDay: j['lastPaymentDay'] as String?,
        viewers: j['viewers'] as int?,
      );
}
