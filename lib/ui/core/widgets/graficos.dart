// =============================================================================
//  Los gráficos: línea y barras, dibujados a mano.
//
//  Sin librería de charts a propósito. Lo que hace falta son dos formas, y una
//  librería trae su propio criterio visual (rejillas gruesas, leyendas de otro
//  tamaño, colores que no son los de la app) que después hay que pelear. Con un
//  `CustomPainter` la anatomía es exactamente la de la versión web.
//
//  Las reglas, heredadas del proyecto web:
//
//    - UN solo eje. Nunca dos escalas en el mismo gráfico: dos medidas de
//      escalas distintas son dos gráficos.
//    - Los colores de serie salen de la paleta de tokens, que está validada
//      para daltonismo, y se asignan en ORDEN FIJO: el color va con la serie,
//      no con su posición en el ranking.
//    - Rejilla finísima, un solo eje visible, sin marcos.
//    - Tabla gemela siempre: quien no distingue los colores, o quien quiere el
//      número exacto, lo lee ahí. El color nunca es la única vía.
//    - Al tocar, la línea vertical y el globo con los valores de esa X.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../formato.dart';
import '../theme/app_theme.dart';

/// Una serie del gráfico. `valores` puede traer null: un hueco en la línea es
/// "aquí no hay dato", que no es lo mismo que un cero.
class Serie {
  const Serie({required this.nombre, required this.color, required this.valores});

  final String nombre;
  final Color color;
  final List<double?> valores;
}

/// Los cortes "redondos" del eje: 0, 250, 500… y no 0, 237, 474.
List<double> cortes(double max, {int n = 4}) {
  if (max <= 0) return const [0, 0.25, 0.5, 0.75, 1];
  final crudo = max / n;
  final mag = math.pow(10, (math.log(crudo) / math.ln10).floor()).toDouble();
  final paso = [1, 2, 2.5, 5, 10]
          .map((k) => k * mag)
          .cast<double?>()
          .firstWhere((s) => s! >= crudo, orElse: () => null) ??
      crudo;
  final out = <double>[];
  for (var v = 0.0; v <= max + paso * 0.001; v += paso) {
    out.add(v);
  }
  if (out.last < max) out.add(out.last + paso);
  return out;
}

/// Qué etiquetas del eje X caben: como mucho `max`, y siempre la primera y la
/// última.
List<int> etiquetasQueCaben(int n, {int max = 6}) {
  if (n <= max) return [for (var i = 0; i < n; i++) i];
  final paso = ((n - 1) / (max - 1)).ceil();
  final out = <int>[];
  for (var i = 0; i < n; i += paso) {
    out.add(i);
  }
  if (out.last != n - 1) {
    // Si la penúltima queda encima de la última, se quita.
    if (n - 1 - out.last < paso / 2) out.removeLast();
    out.add(n - 1);
  }
  return out;
}

/* ============================================================== el gráfico == */

enum FormaGrafico { linea, barras }

class Grafico extends StatefulWidget {
  const Grafico({
    super.key,
    required this.series,
    required this.etiquetas,
    this.forma = FormaGrafico.linea,
    this.alto = 200,
    this.moneda,
  });

  final List<Serie> series;

  /// El texto de cada X. Tiene que tener el mismo largo que los valores.
  final List<String> etiquetas;

  final FormaGrafico forma;
  final double alto;

  /// Para escribir los montos del globo y de la tabla con su símbolo.
  final String? moneda;

  @override
  State<Grafico> createState() => _GraficoState();
}

class _GraficoState extends State<Grafico> {
  /// La X que se está tocando, o null.
  int? _tocada;

  void _tocar(Offset local, Size size) {
    final n = widget.etiquetas.length;
    if (n == 0) return;
    final ancho = size.width - _Pintor.izq - _Pintor.der;
    final rel = ((local.dx - _Pintor.izq) / ancho).clamp(0.0, 1.0);
    final i = widget.forma == FormaGrafico.barras
        ? (rel * n).floor().clamp(0, n - 1)
        : (rel * (n - 1)).round().clamp(0, n - 1);
    if (i != _tocada) setState(() => _tocada = i);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final series = widget.series;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Con una sola serie el título ya dice qué es: una leyenda de un solo
        // elemento es ruido. Con dos o más va siempre.
        if (series.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final s in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: widget.forma == FormaGrafico.barras ? 10 : 3,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(s.nombre, style: TextStyle(fontSize: 12, color: t.muted)),
                    ],
                  ),
              ],
            ),
          ),
        SizedBox(
          height: widget.alto,
          child: LayoutBuilder(
            builder: (context, cajas) {
              final size = Size(cajas.maxWidth, widget.alto);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _tocar(d.localPosition, size),
                onHorizontalDragUpdate: (d) => _tocar(d.localPosition, size),
                onHorizontalDragEnd: (_) => setState(() => _tocada = null),
                onTapUp: (_) => setState(() => _tocada = null),
                onTapCancel: () => setState(() => _tocada = null),
                child: CustomPaint(
                  size: size,
                  painter: _Pintor(
                    series: series,
                    etiquetas: widget.etiquetas,
                    forma: widget.forma,
                    tocada: _tocada,
                    moneda: widget.moneda,
                    tinta: t.ink,
                    suave: t.faint,
                    linea: t.line,
                    fondoGlobo: t.ink,
                    textoGlobo: t.onInk,
                    fondo: t.card,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor({
    required this.series,
    required this.etiquetas,
    required this.forma,
    required this.tocada,
    required this.moneda,
    required this.tinta,
    required this.suave,
    required this.linea,
    required this.fondoGlobo,
    required this.textoGlobo,
    required this.fondo,
  });

  final List<Serie> series;
  final List<String> etiquetas;
  final FormaGrafico forma;
  final int? tocada;
  final String? moneda;
  final Color tinta, suave, linea, fondoGlobo, textoGlobo, fondo;

  /// Los márgenes: a la izquierda cabe "12.5k", abajo "sept 26".
  static const izq = 44.0;
  static const der = 12.0;
  static const arriba = 10.0;
  static const abajo = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = etiquetas.length;
    if (n == 0) return;

    var maximo = 0.0;
    for (final s in series) {
      for (final v in s.valores) {
        if (v != null && v > maximo) maximo = v;
      }
    }
    final ticks = cortes(maximo);
    final tope = ticks.last == 0 ? 1.0 : ticks.last;

    final anchoUtil = size.width - izq - der;
    final altoUtil = size.height - arriba - abajo;
    final banda = anchoUtil / n;

    double y(double v) => arriba + (1 - v / tope) * altoUtil;
    double x(int i) => forma == FormaGrafico.barras
        ? izq + banda * i + banda / 2
        : izq + (n > 1 ? (i / (n - 1)) * anchoUtil : anchoUtil / 2);

    // La rejilla, finísima: está para poder leer una altura, no para verse.
    final rejilla = Paint()
      ..color = linea
      ..strokeWidth = 1;
    for (final t in ticks) {
      final yy = y(t);
      canvas.drawLine(Offset(izq, yy), Offset(size.width - der, yy), rejilla);
    }

    // La banda que se está tocando, en las barras, antes de las barras.
    if (tocada != null && forma == FormaGrafico.barras) {
      canvas.drawRect(
        Rect.fromLTWH(izq + banda * tocada!, arriba, banda, altoUtil),
        Paint()..color = linea.withValues(alpha: 0.55),
      );
    }

    switch (forma) {
      case FormaGrafico.linea:
        _lineas(canvas, x, y, n);
      case FormaGrafico.barras:
        _barras(canvas, y, banda, n);
    }

    // El eje cero, el único visible.
    canvas.drawLine(
      Offset(izq, y(0)),
      Offset(size.width - der, y(0)),
      Paint()
        ..color = suave.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );

    for (final t in ticks) {
      _texto(canvas, compacto(t), Offset(izq - 6, y(t)), alinear: -1, medio: true);
    }
    for (final i in etiquetasQueCaben(n)) {
      final centro = x(i);
      final alinear = forma == FormaGrafico.barras || n == 1
          ? 0
          : i == 0
              ? 1
              : i == n - 1
                  ? -1
                  : 0;
      _texto(canvas, etiquetas[i], Offset(centro, size.height - abajo + 5), alinear: alinear);
    }

    if (tocada != null) _globo(canvas, size, x(tocada!), y);
  }

  void _lineas(Canvas canvas, double Function(int) x, double Function(double) y, int n) {
    for (final s in series) {
      final trazo = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final camino = Path();
      var pluma = false;
      for (var i = 0; i < n && i < s.valores.length; i++) {
        final v = s.valores[i];
        // Un null LEVANTA la pluma: unir los dos lados del hueco inventaría un
        // dato que no existe.
        if (v == null) {
          pluma = false;
          continue;
        }
        final p = Offset(x(i), y(v));
        pluma ? camino.lineTo(p.dx, p.dy) : camino.moveTo(p.dx, p.dy);
        pluma = true;
      }
      canvas.drawPath(camino, trazo);

      // El último punto marcado: es el que la gente busca ("¿y ahora?").
      for (var i = math.min(n, s.valores.length) - 1; i >= 0; i--) {
        final v = s.valores[i];
        if (v == null) continue;
        final c = Offset(x(i), y(v));
        canvas.drawCircle(c, 4.5, Paint()..color = fondo);
        canvas.drawCircle(c, 3.5, Paint()..color = s.color);
        break;
      }
    }
  }

  void _barras(Canvas canvas, double Function(double) y, double banda, int n) {
    final cuantas = series.length;
    final ancho = math.min(24.0, math.max(3.0, (banda * 0.7 - 2 * (cuantas - 1)) / cuantas));
    final grupo = ancho * cuantas + 2 * (cuantas - 1);

    for (var k = 0; k < cuantas; k++) {
      final s = series[k];
      final pincel = Paint()..color = s.color;
      for (var i = 0; i < n && i < s.valores.length; i++) {
        final v = s.valores[i];
        if (v == null || v <= 0) continue;
        final bx = izq + banda * i + (banda - grupo) / 2 + k * (ancho + 2);
        final alto = y(0) - y(v);
        if (alto <= 0) continue;
        // Punta redondeada y base cuadrada, pegada al cero: la barra sale de la
        // línea, no flota.
        final r = math.min(4.0, math.min(alto, ancho / 2));
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(bx, y(v), ancho, alto),
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
          ),
          pincel,
        );
      }
    }
  }

  /// El globo con los valores de la X que se toca.
  void _globo(Canvas canvas, Size size, double cx, double Function(double) y) {
    // La línea vertical, para saber exactamente qué X se está leyendo.
    if (forma == FormaGrafico.linea) {
      canvas.drawLine(
        Offset(cx, arriba),
        Offset(cx, size.height - abajo),
        Paint()
          ..color = suave.withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );
      for (final s in series) {
        final v = tocada! < s.valores.length ? s.valores[tocada!] : null;
        if (v == null) continue;
        final c = Offset(cx, y(v));
        canvas.drawCircle(c, 5, Paint()..color = fondo);
        canvas.drawCircle(c, 3.5, Paint()..color = s.color);
      }
    }

    final lineas = <String>[etiquetas[tocada!]];
    for (final s in series) {
      final v = tocada! < s.valores.length ? s.valores[tocada!] : null;
      if (v == null) continue;
      lineas.add(
        series.length > 1
            ? '${s.nombre}: ${_monto(v)}'
            : _monto(v),
      );
    }
    if (lineas.length == 1) return;

    final pintores = [
      for (final (i, l) in lineas.indexed)
        TextPainter(
          text: TextSpan(
            text: l,
            style: TextStyle(
              color: textoGlobo,
              fontSize: i == 0 ? 11 : 12,
              fontWeight: i == 0 ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];

    final ancho = pintores.fold<double>(0, (a, p) => math.max(a, p.width)) + 20;
    final alto = pintores.fold<double>(0, (a, p) => a + p.height) + 14;
    // El globo se mantiene dentro del dibujo: pegado al borde antes que cortado.
    final gx = (cx - ancho / 2).clamp(izq, size.width - der - ancho);
    const gy = arriba + 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(gx, gy, ancho, alto), const Radius.circular(8)),
      Paint()..color = fondoGlobo.withValues(alpha: 0.94),
    );
    var dy = gy + 7;
    for (final p in pintores) {
      p.paint(canvas, Offset(gx + 10, dy));
      dy += p.height;
    }
  }

  String _monto(double v) => moneda == null ? compacto(v) : plata(v, moneda!);

  /// `alinear`: -1 termina en el punto, 0 lo centra, 1 empieza ahí.
  void _texto(
    Canvas canvas,
    String texto,
    Offset donde, {
    int alinear = 0,
    bool medio = false,
  }) {
    final p = TextPainter(
      text: TextSpan(text: texto, style: TextStyle(color: suave, fontSize: 10.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (alinear) {
      -1 => donde.dx - p.width,
      1 => donde.dx,
      _ => donde.dx - p.width / 2,
    };
    p.paint(canvas, Offset(dx, medio ? donde.dy - p.height / 2 : donde.dy));
  }

  @override
  bool shouldRepaint(_Pintor old) =>
      old.tocada != tocada ||
      old.series != series ||
      old.etiquetas != etiquetas ||
      old.tinta != tinta;
}

/* ============================================================ tabla gemela == */

/// Los mismos datos en tabla, plegada. No es un extra: es lo que hace que el
/// gráfico no dependa de distinguir colores, y donde se lee el número exacto.
class TablaGrafico extends StatelessWidget {
  const TablaGrafico({
    super.key,
    required this.etiquetas,
    required this.series,
    this.moneda,
    this.titulo = 'Ver como tabla',
  });

  final List<String> etiquetas;
  final List<Serie> series;
  final String? moneda;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final estiloCabeza = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.muted);
    final estiloCelda = TextStyle(
      fontSize: 12.5,
      color: t.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Theme(
      // Sin la línea que Material pinta arriba y abajo del desplegable.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(titulo, style: TextStyle(fontSize: 13, color: t.muted)),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        children: [
          // Una tabla ancha se desplaza dentro de su caja: el cuerpo de la
          // pantalla nunca se mueve de lado.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                TableRow(
                  children: [
                    _celda(Text('', style: estiloCabeza)),
                    for (final s in series)
                      _celda(
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: s.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(s.nombre, style: estiloCabeza),
                          ],
                        ),
                      ),
                  ],
                ),
                for (final (i, e) in etiquetas.indexed)
                  TableRow(
                    children: [
                      _celda(Text(e, style: TextStyle(fontSize: 12.5, color: t.muted))),
                      for (final s in series)
                        _celda(
                          Text(
                            i < s.valores.length && s.valores[i] != null
                                ? (moneda == null
                                    ? compacto(s.valores[i])
                                    : plata(s.valores[i], moneda!))
                                : '—',
                            style: estiloCelda,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _celda(Widget hijo) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: hijo,
      );
}
