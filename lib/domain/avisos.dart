// =============================================================================
//  Qué recordatorios hay que programar.
//
//  La razón de tener una app nativa. Y la razón de que esto sea LOCAL y no
//  push: las fechas ya se saben. Un acuerdo de "C$1,000 cada mes desde el 15"
//  dice cuándo toca el siguiente pago sin preguntarle nada a nadie, así que
//  programar la notificación en el teléfono funciona sin internet, sin servidor
//  y sin batería de más.
//
//  Lo que NO se puede avisar así es lo que pasa por acción de otra persona
//  ("tu hermano comentó"): eso sí necesita push de verdad.
//
//  Está en `domain` porque decidir QUÉ se avisa y CUÁNDO son reglas, y aquí se
//  prueban sin tocar el sistema de notificaciones.
// =============================================================================

import 'dia.dart';
import 'models/debt.dart';
import 'pago_esperado.dart';

/// Un recordatorio listo para programar.
class Aviso {
  const Aviso({
    required this.id,
    required this.dia,
    required this.titulo,
    required this.cuerpo,
  });

  /// Un id ESTABLE: el mismo aviso tiene el mismo id entre una reprogramación y
  /// la siguiente, así que reprogramar reemplaza en vez de duplicar.
  final int id;

  /// El día en que se muestra, YYYY-MM-DD.
  final String dia;

  final String titulo;
  final String cuerpo;
}

/// Cuántos días antes se avisa de un pago. Tres: da tiempo a mover plata, y no
/// tan pronto como para olvidarlo otra vez.
const _diasAntes = 3;

/// Los avisos de las deudas: el pago que viene y el que ya se pasó.
///
/// `plata` y `fecha` los pone quien llama: el dominio no sabe de `intl`.
List<Aviso> avisosDeDeudas({
  required List<Debt> deudas,
  required String hoy,
  required bool Function(Debt) esCobro,
  required String Function(num monto, String moneda) plata,
  required String Function(String dia) fecha,
}) {
  final out = <Aviso>[];

  for (final d in deudas) {
    if (!d.active) continue;
    final pago = proximoPago(d, hoy);
    if (pago == null) continue;

    final cobro = esCobro(d);
    final monto = plata(pago.amount, pago.currency);

    // Lo atrasado se recuerda HOY: no tiene sentido programarlo para una fecha
    // que ya pasó, y es justo lo que uno necesita que le repitan.
    if (pago.overdue) {
      out.add(Aviso(
        id: _id(_kDeudaAtraso, d.id),
        dia: hoy,
        titulo: cobro ? '${d.name} te debe un pago' : 'Pago atrasado: ${d.name}',
        cuerpo: cobro
            ? '$monto que quedó para el ${fecha(pago.day)}. '
                'Lleva ${_plural(pago.daysLate, 'día', 'días')} de atraso.'
            : '$monto del ${fecha(pago.day)}, '
                '${_plural(pago.daysLate, 'día', 'días')} atrás.',
      ));
      continue;
    }

    // El que viene: unos días antes, y también el mismo día.
    final antes = masDias(pago.day, -_diasAntes);
    if (antes.compareTo(hoy) >= 0) {
      out.add(Aviso(
        id: _id(_kDeudaAntes, d.id),
        dia: antes,
        titulo: cobro ? '${d.name} te paga pronto' : 'Se acerca el pago de ${d.name}',
        cuerpo: '$monto el ${fecha(pago.day)}, '
            'en ${_plural(_diasAntes, 'día', 'días')}.',
      ));
    }
    if (pago.day.compareTo(hoy) >= 0) {
      out.add(Aviso(
        id: _id(_kDeudaHoy, d.id),
        dia: pago.day,
        titulo: cobro ? 'Hoy te toca cobrar: ${d.name}' : 'Hoy toca el pago de ${d.name}',
        cuerpo: cobro ? 'Son $monto.' : '$monto. Al abonarlo, anótalo en la app.',
      ));
    }
  }

  return out;
}

/* -------------------------------------------------------------------------- */

// Cada clase de aviso lleva su prefijo para que dos avisos de la misma deuda no
// se pisen el id (el "3 días antes" y el "hoy" son dos notificaciones).
const _kDeudaAntes = 1;
const _kDeudaHoy = 2;
const _kDeudaAtraso = 3;

/// Un id estable y único a partir de la clase y el id de la fila.
///
/// Android usa un `int` de 32 bits para el id de la notificación, así que se
/// mantiene pequeño: mil filas por clase es de sobra para una cuenta personal.
int _id(int clase, int fila) => clase * 100000 + (fila % 100000);

String _plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';
