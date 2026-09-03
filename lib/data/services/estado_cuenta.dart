// =============================================================================
//  El estado de cuenta en PDF: el resumen y todos los movimientos, con el saldo
//  después de cada uno.
//
//  Mismo contenido y mismo orden que el de la versión web, para que los dos
//  papeles se puedan poner uno al lado del otro. La diferencia es cómo se
//  construye: la web escribe el PDF byte a byte (no podía traer dependencias),
//  y aquí se usa el paquete `pdf`.
//
//  Una sección POR MONEDA. Los saldos no se mezclan aquí tampoco.
// =============================================================================

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/debt.dart';
import '../../domain/models/entry.dart';

/// Un comprobante para adjuntar al final.
class ComprobanteAdjunto {
  const ComprobanteAdjunto({required this.entry, required this.jpeg});

  final Entry entry;
  final Uint8List jpeg;
}

/// Las palabras que cambian según de qué lado se lee la deuda. Se pasan desde
/// fuera: el vocabulario vive en la interfaz, no aquí.
class PalabrasEstado {
  const PalabrasEstado({
    required this.prestado,
    required this.abonado,
    required this.prestamo,
    required this.abono,
    required this.cobro,
  });

  /// "Prestado" · "Presté"
  final String prestado;

  /// "Abonado" · "Me han pagado"
  final String abonado;

  /// "Préstamo" · "Préstamo que hice"
  final String prestamo;

  /// "Abono" · "Pago recibido"
  final String abono;

  /// Si se lee como un cobro (me deben) o como una deuda (yo debo).
  final bool cobro;
}

typedef Plata = String Function(num monto, String moneda);
typedef Fecha = String Function(String dia);

Future<Uint8List> estadoDeCuentaPdf({
  required Debt debt,
  required List<Entry> movimientos,
  required PalabrasEstado palabras,
  required String hoy,
  required String cuenta,
  required Plata plata,
  required Fecha fecha,
  List<ComprobanteAdjunto> comprobantes = const [],
}) async {
  final doc = pw.Document(title: 'Estado de cuenta · ${debt.name}');

  final gris = PdfColors.grey700;
  final grisClaro = PdfColors.grey500;
  final hayComprobantes = movimientos.any((e) => e.hasReceipt);

  pw.Widget pie(pw.Context c) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado el ${fecha(hoy)} · $cuenta',
              style: pw.TextStyle(fontSize: 7.5, color: grisClaro),
            ),
            pw.Text(
              'Página ${c.pageNumber} de ${c.pagesCount}',
              style: pw.TextStyle(fontSize: 7.5, color: grisClaro),
            ),
          ],
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(45),
      footer: pie,
      header: (c) => c.pageNumber == 1 ? pw.SizedBox() : pw.SizedBox(height: 10),
      build: (context) => [
        // Cabecera.
        pw.Text(cuenta, style: pw.TextStyle(fontSize: 9, color: gris)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Estado de cuenta: ${debt.name}',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          [
            palabras.cobro ? 'Me deben' : 'Yo debo',
            if (debt.counterpart?.trim().isNotEmpty ?? false)
              '${palabras.cobro ? 'Deudor' : 'A'}: ${debt.counterpart!.trim()}',
            debt.kind.label,
            if (debt.interestRate != null && debt.interestRate! > 0)
              '${debt.interestRate}% anual',
          ].join('  ·  '),
          style: pw.TextStyle(fontSize: 9.5, color: gris),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(height: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 16),

        // Una sección por moneda.
        for (final cur in debt.currencies) ...[
          if (debt.currencies.length > 1)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'En ${cur == 'USD' ? 'dólares' : 'córdobas'}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ),
          _totales(debt, cur, palabras, plata),
          pw.SizedBox(height: 18),
          _tabla(
            movimientos: _cronologico(movimientos.where((e) => e.currency == cur).toList()),
            moneda: cur,
            palabras: palabras,
            plata: plata,
            fecha: fecha,
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Saldo: ${plata(_pendiente(debt, cur), cur)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 22),
        ],

        if (hayComprobantes)
          pw.Text(
            comprobantes.isNotEmpty
                ? '* con comprobante adjunto al final'
                : '* con comprobante (disponible en la app)',
            style: pw.TextStyle(fontSize: 8, color: grisClaro),
          ),
      ],
    ),
  );

  // Los comprobantes, uno por página: una captura de transferencia apretada en
  // media página no se lee.
  for (final c in comprobantes) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(45),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Comprobante · ${c.entry.isLoan ? palabras.prestamo : palabras.abono} '
              'de ${plata(c.entry.amount, c.entry.currency)} · ${fecha(c.entry.day)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            if (c.entry.reason?.trim().isNotEmpty ?? false) ...[
              pw.SizedBox(height: 4),
              pw.Text(c.entry.reason!.trim(), style: pw.TextStyle(fontSize: 9, color: gris)),
            ],
            pw.SizedBox(height: 14),
            pw.Expanded(
              child: pw.Center(
                child: pw.Image(pw.MemoryImage(c.jpeg), fit: pw.BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  return doc.save();
}

/// Las tres casillas de totales.
pw.Widget _totales(Debt debt, String cur, PalabrasEstado p, Plata plata) {
  final t = debt.totals[cur];
  final casillas = [
    (p.prestado, plata(t?.loaned ?? 0, cur), false),
    (p.abonado, plata(t?.paid ?? 0, cur), false),
    ('Saldo actual', plata(_pendiente(debt, cur), cur), true),
  ];
  return pw.Row(
    children: [
      for (final (i, (etiqueta, valor, fuerte)) in casillas.indexed) ...[
        if (i > 0) pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  etiqueta.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  valor,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: fuerte ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

/// La tabla de movimientos con el saldo corrido.
pw.Widget _tabla({
  required List<Entry> movimientos,
  required String moneda,
  required PalabrasEstado palabras,
  required Plata plata,
  required Fecha fecha,
}) {
  if (movimientos.isEmpty) {
    return pw.Text(
      'Sin movimientos.',
      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    );
  }

  final cabeza = pw.TextStyle(
    fontSize: 7.5,
    color: PdfColors.grey600,
    fontWeight: pw.FontWeight.bold,
  );
  var saldo = 0.0;

  return pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(1.5),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(1.4),
      3: pw.FlexColumnWidth(1.4),
      4: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
        ),
        children: [
          _celda(pw.Text('FECHA', style: cabeza)),
          _celda(pw.Text('DETALLE', style: cabeza)),
          _celda(pw.Text(palabras.cobro ? 'PRESTÉ' : 'PRÉSTAMO', style: cabeza), derecha: true),
          _celda(pw.Text(palabras.cobro ? 'ME PAGÓ' : 'ABONO', style: cabeza), derecha: true),
          _celda(pw.Text('SALDO', style: cabeza), derecha: true),
        ],
      ),
      for (final e in movimientos)
        () {
          saldo += e.signed;
          final detalle = (e.reason?.trim().isNotEmpty ?? false)
              ? e.reason!.trim()
              : (e.isLoan ? palabras.prestamo : palabras.abono);
          return pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.4)),
            ),
            children: [
              _celda(pw.Text(
                fecha(e.day),
                style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
              )),
              // El asterisco marca los que traen comprobante; el pie explica
              // qué significa.
              _celda(pw.Text(
                '$detalle${e.hasReceipt ? ' *' : ''}',
                style: const pw.TextStyle(fontSize: 9),
                maxLines: 2,
              )),
              _celda(
                pw.Text(
                  e.isLoan ? plata(e.amount, moneda) : '',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                derecha: true,
              ),
              _celda(
                pw.Text(
                  e.isLoan ? '' : plata(e.amount, moneda),
                  style: const pw.TextStyle(fontSize: 9),
                ),
                derecha: true,
              ),
              _celda(
                pw.Text(
                  plata(saldo, moneda),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                derecha: true,
              ),
            ],
          );
        }(),
    ],
  );
}

pw.Widget _celda(pw.Widget hijo, {bool derecha = false}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      alignment: derecha ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: hijo,
    );

/// Del más viejo al más nuevo: un estado de cuenta se lee hacia adelante, y el
/// saldo corrido solo tiene sentido en ese orden.
List<Entry> _cronologico(List<Entry> list) => [...list]..sort((a, b) {
      final porDia = a.day.compareTo(b.day);
      return porDia != 0 ? porDia : a.id.compareTo(b.id);
    });

double _pendiente(Debt debt, String cur) {
  final b = debt.totals[cur]?.balance ?? 0;
  return b > 0 ? b : 0;
}
