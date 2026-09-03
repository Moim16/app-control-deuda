// =============================================================================
//  El movimiento que se está escribiendo, todavía sin mandar.
//
//  Está en `domain` y no en la pantalla porque las reglas de qué es un
//  movimiento válido son del negocio, no del formulario: el monto tiene que ser
//  mayor que cero y la fecha no puede ser de pasado mañana. La API las
//  comprueba igual — nunca se confía en el cliente — pero decirlo en el
//  teléfono ahorra un viaje y da un mensaje al instante.
//
//  Los mensajes son LOS MISMOS que responde la API a propósito: si un día la
//  validación de aquí se queda corta, la persona lee la misma frase y no dos
//  versiones distintas del mismo problema.
// =============================================================================

import '../dia.dart';
import 'entry.dart';

/// Qué hacer con el comprobante al guardar. Son tres cosas distintas y no un
/// `String?`: al editar, "no lo toques" y "bórralo" no son lo mismo.
sealed class CambioComprobante {
  const CambioComprobante();
}

/// Se deja como está (solo tiene sentido al editar).
class ComprobanteIgual extends CambioComprobante {
  const ComprobanteIgual();
}

/// Se borra el que había.
class ComprobanteQuitado extends CambioComprobante {
  const ComprobanteQuitado();
}

/// Se sube este, en data URI JPEG.
class ComprobanteNuevo extends CambioComprobante {
  const ComprobanteNuevo(this.dataUri);
  final String dataUri;
}

class EntryDraft {
  const EntryDraft({
    required this.kind,
    required this.day,
    required this.amount,
    required this.currency,
    this.reason = '',
    this.note = '',
    this.receipt = const ComprobanteIgual(),
  });

  final EntryKind kind;

  /// YYYY-MM-DD.
  final String day;

  /// Tal como se escribió: "3,500.50", "3500", " 120 ". Se limpia al leerlo.
  final String amount;

  final String currency;
  final String reason;
  final String note;
  final CambioComprobante receipt;

  EntryDraft copyWith({
    EntryKind? kind,
    String? day,
    String? amount,
    String? currency,
    String? reason,
    String? note,
    CambioComprobante? receipt,
  }) =>
      EntryDraft(
        kind: kind ?? this.kind,
        day: day ?? this.day,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        reason: reason ?? this.reason,
        note: note ?? this.note,
        receipt: receipt ?? this.receipt,
      );

  /// El monto ya en número, o null si lo escrito no sirve. La coma de los miles
  /// se quita porque así se escribe aquí ("3,500.50") y así lo hace la API.
  double? get monto {
    final n = double.tryParse(amount.replaceAll(',', '').trim());
    if (n == null || !n.isFinite || n <= 0 || n > 1e9) return null;
    return (n * 100).round() / 100;
  }

  /// Qué está mal, para mostrarlo; null si se puede mandar.
  ///
  /// `hoy` viene del SERVIDOR (hora de Nicaragua): un teléfono con la zona mal
  /// puesta diría otro día. Se admite un día más porque quien registra de noche
  /// puede estar anotando el movimiento del día siguiente, y es lo que ya
  /// permite la web.
  String? problema({required String hoy}) {
    if (monto == null) return 'El monto debe ser mayor que cero.';
    if (!diaValido(day)) return 'La fecha no es válida.';
    if (day.compareTo(masDias(hoy, 1)) > 0) return 'Esa fecha todavía no llega.';
    if (!const ['NIO', 'USD'].contains(currency)) return 'Moneda inválida.';
    if (reason.trim().length > 120) return 'El motivo es muy largo.';
    if (note.trim().length > 500) return 'La nota es muy larga.';
    return null;
  }

  bool esValido({required String hoy}) => problema(hoy: hoy) == null;

  /// El movimiento que ya existe, para abrir el formulario en modo edición.
  factory EntryDraft.de(Entry e) => EntryDraft(
        kind: e.kind,
        day: e.day,
        amount: e.amount == e.amount.roundToDouble()
            ? e.amount.toStringAsFixed(0)
            : e.amount.toStringAsFixed(2),
        currency: e.currency,
        reason: e.reason ?? '',
        note: e.note ?? '',
      );
}
