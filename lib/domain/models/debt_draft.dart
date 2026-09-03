// =============================================================================
//  La deuda que se está creando o editando.
//
//  Lo importante de este formulario: NO se pide el monto. Una deuda no nace con
//  una cifra; nace con un nombre ("mi hermano") y se va llenando de préstamos.
//  Esa fue una corrección expresa del dueño de la app, y por eso aquí no hay
//  ningún campo de saldo.
//
//  El acuerdo de pago se guarda COMPLETO o se borra completo: media frecuencia
//  sin monto no dice nada. Es la misma regla que aplica `parseDue` en la API, y
//  los mensajes son los mismos.
// =============================================================================

import '../dia.dart';
import 'debt.dart';

class DebtDraft {
  const DebtDraft({
    required this.direction,
    this.name = '',
    this.kind = DebtKind.person,
    this.currency = 'NIO',
    this.counterpart = '',
    this.note = '',
    this.interestRate = '',
    this.dueEvery,
    this.dueAmount = '',
    required this.dueFrom,
    this.active = true,
  });

  /// Yo debo (una deuda) o me deben (un cobro). Se puede cambiar después: los
  /// movimientos no se tocan, lo que era "me prestó" pasa a leerse "le presté".
  final DebtDirection direction;

  final String name;
  final DebtKind kind;

  /// La moneda que se PROPONE al registrar. Cada movimiento guarda la suya, así
  /// que cambiarla no toca nada de lo ya registrado.
  final String currency;

  final String counterpart;
  final String note;

  /// En texto, tal como se escribe. Vacío = sin interés.
  final String interestRate;

  /// El acuerdo de pago, o null si no hay ninguno.
  final DueEvery? dueEvery;
  final String dueAmount;
  final String dueFrom;

  final bool active;

  DebtDraft copyWith({
    DebtDirection? direction,
    String? name,
    DebtKind? kind,
    String? currency,
    String? counterpart,
    String? note,
    String? interestRate,
    DueEvery? dueEvery,
    bool borrarAcuerdo = false,
    String? dueAmount,
    String? dueFrom,
    bool? active,
  }) =>
      DebtDraft(
        direction: direction ?? this.direction,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        currency: currency ?? this.currency,
        counterpart: counterpart ?? this.counterpart,
        note: note ?? this.note,
        interestRate: interestRate ?? this.interestRate,
        // Quitar el acuerdo es pasar `dueEvery` a null, y un parámetro opcional
        // no distingue "null" de "no lo mandes": de ahí la bandera.
        dueEvery: borrarAcuerdo ? null : (dueEvery ?? this.dueEvery),
        dueAmount: dueAmount ?? this.dueAmount,
        dueFrom: dueFrom ?? this.dueFrom,
        active: active ?? this.active,
      );

  bool get tieneAcuerdo => dueEvery != null;

  /// El interés en número, o null si el campo está vacío. `double.nan` cuando
  /// lo escrito no sirve, para poder distinguir "vacío" de "mal escrito".
  double? get interes {
    final s = interestRate.trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s.replaceAll(',', ''));
    return (n == null || !n.isFinite || n < 0 || n > 200) ? double.nan : n;
  }

  double? get cuota {
    final n = double.tryParse(dueAmount.replaceAll(',', '').trim());
    return (n == null || !n.isFinite || n <= 0) ? null : (n * 100).round() / 100;
  }

  /// Qué está mal, para mostrarlo; null si se puede mandar. Los mensajes son
  /// los mismos que responde la API.
  String? get problema {
    if (name.trim().isEmpty) return 'Ponle un nombre a la deuda.';
    if (name.trim().length > 80) return 'El nombre es muy largo.';
    if (counterpart.trim().length > 80) return 'Ese nombre es muy largo.';
    if (note.trim().length > 300) return 'La nota es muy larga.';
    final i = interes;
    if (i != null && i.isNaN) {
      return 'El interés anual debe ser un porcentaje entre 0 y 200.';
    }
    if (tieneAcuerdo) {
      if (cuota == null) return 'Indica cuánto se paga en cada fecha.';
      if (!diaValido(dueFrom)) return 'Indica la fecha del primer pago acordado.';
    }
    return null;
  }

  bool get esValido => problema == null;

  /// Lo que se manda a la API.
  ///
  /// El acuerdo va SIEMPRE en los tres campos: con `dueEvery` vacío, el
  /// servidor entiende que hay que borrarlo. Si solo se omitieran, el acuerdo
  /// viejo se quedaría puesto y nadie podría quitarlo desde la app.
  Map<String, Object?> aJson({required bool nueva}) => {
        'name': name.trim(),
        'kind': kind.wire,
        'currency': currency,
        'direction': direction.wire,
        'counterpart': counterpart.trim(),
        'note': note.trim(),
        'interestRate': interestRate.trim(),
        'dueEvery': dueEvery?.wire ?? '',
        if (tieneAcuerdo) 'dueAmount': cuota,
        if (tieneAcuerdo) 'dueFrom': dueFrom,
        if (!nueva) 'active': active,
      };

  /// Para abrir el formulario sobre una deuda que ya existe.
  factory DebtDraft.de(Debt d, {required String hoy}) => DebtDraft(
        direction: d.direction,
        name: d.name,
        kind: d.kind,
        currency: d.currency,
        counterpart: d.counterpart ?? '',
        note: d.note ?? '',
        interestRate: d.interestRate == null ? '' : _sinCerosSobrantes(d.interestRate!),
        dueEvery: d.plan?.every,
        dueAmount: d.plan == null ? '' : _sinCerosSobrantes(d.plan!.amount),
        dueFrom: d.plan?.from ?? hoy,
        active: d.active,
      );

  /// "12" y no "12.0"; "12.5" se queda como está.
  static String _sinCerosSobrantes(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
