// =============================================================================
//  Los días, en el formato en el que viajan: "YYYY-MM-DD".
//
//  La app trabaja con la fecha como TEXTO y no como `DateTime` a propósito: es
//  lo que manda y devuelve la API, es un día del calendario de Nicaragua y no
//  un instante, y así no hay husos ni horas de por medio. Comparar dos días es
//  comparar dos cadenas, que además ordena bien.
//
//  Está en `domain` porque lo usan los modelos, no solo las pantallas.
// =============================================================================

/// El día de un `DateTime`, en el formato que espera la API.
String diaDe(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

final _formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Si es un día que existe de verdad.
///
/// La ida y vuelta no es paranoia: Dart no falla con un día que no existe, lo
/// CORRE — `DateTime.parse('2026-02-30')` devuelve el 2 de marzo. Sin comparar
/// la fecha reconstruida con la que entró, el 30 de febrero pasaría y se
/// guardaría otro día. Es la misma vuelta que da `parseDay` en la API.
bool diaValido(String? dia) {
  if (dia == null || !_formato.hasMatch(dia)) return false;
  final d = DateTime.tryParse(dia);
  return d != null && diaDe(d) == dia;
}

/// El día `n` días después (o antes, con n negativo).
String masDias(String dia, int n) {
  final d = DateTime.tryParse(dia);
  return d == null ? dia : diaDe(d.add(Duration(days: n)));
}

/// El día `n` meses después, pegado al último día del mes cuando hace falta:
/// un acuerdo del día 31 cae el 28 en febrero, no se salta al 3 de marzo.
String masMeses(String dia, int n) {
  final d = DateTime.tryParse(dia);
  if (d == null) return dia;
  // Se cuenta en meses absolutos desde el año cero. Hacerlo con `d.month + n`
  // se descuadra al retroceder de enero: `~/` trunca hacia cero y `%` en Dart
  // nunca es negativo, así que enero menos un mes daba diciembre del MISMO año.
  final absoluto = d.year * 12 + (d.month - 1) + n;
  final ano = absoluto ~/ 12;
  final m = absoluto % 12 + 1;
  // El día 0 del mes siguiente es el último del mes que interesa.
  final ultimo = DateTime(ano, m + 1, 0).day;
  return diaDe(DateTime(ano, m, d.day < ultimo ? d.day : ultimo));
}

/// El mes de un día: "2026-09-03" -> "2026-09".
String mesDe(String dia) => dia.length >= 7 ? dia.substring(0, 7) : dia;

/// Los últimos `n` meses hasta el de `hoy`, del más viejo al más nuevo.
///
/// Se cuenta desde el mes de `hoy` hacia atrás y no desde el primer movimiento:
/// un gráfico de los últimos doce meses tiene que acabar en este mes aunque
/// haga medio año que no se registra nada.
List<String> ultimosMeses(int n, {required String hoy}) {
  final base = '${mesDe(hoy)}-01';
  return [
    for (var i = n - 1; i >= 0; i--) mesDe(masMeses(base, -i)),
  ];
}
