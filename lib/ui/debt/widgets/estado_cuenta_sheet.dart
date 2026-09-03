// =============================================================================
//  Compartir: el estado de cuenta en PDF, o el resumen en texto.
//
//  Son dos cosas distintas para dos momentos distintos. El PDF es el papel
//  formal, con todos los movimientos y el saldo después de cada uno. El texto
//  es el mensaje de WhatsApp: en un cobro, arranca con el recordatorio del pago
//  pendiente, que es justo el mensaje que uno no sabe cómo empezar.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/services/comprobante.dart';
import '../../../data/services/estado_cuenta.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/entry.dart';
import '../../../domain/resumen_texto.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/debt_view_model.dart';

class EstadoCuentaSheet extends StatefulWidget {
  const EstadoCuentaSheet({
    super.key,
    required this.vm,
    required this.debt,
    required this.lado,
    required this.cuenta,
  });

  final DebtViewModel vm;
  final Debt debt;
  final Lado lado;

  /// El nombre de la cuenta, para la cabecera del papel.
  final String cuenta;

  static Future<void> abrir(
    BuildContext context, {
    required DebtViewModel vm,
    required Debt debt,
    required Lado lado,
  }) {
    final cuenta = context.read<AuthRepository>().me?.accountName ?? 'Deudas';
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EstadoCuentaSheet(vm: vm, debt: debt, lado: lado, cuenta: cuenta),
    );
  }

  @override
  State<EstadoCuentaSheet> createState() => _EstadoCuentaSheetState();
}

class _EstadoCuentaSheetState extends State<EstadoCuentaSheet> {
  bool _adjuntar = false;
  bool _trabajando = false;
  String? _paso;
  String? _error;

  List<Entry> get _movimientos => widget.vm.allEntries;
  int get _conComprobante => _movimientos.where((e) => e.hasReceipt).length;

  /// Arma el PDF. Los comprobantes se piden uno por uno: son cientos de KB cada
  /// uno y no vienen con la lista.
  Future<Uint8List?> _armar() async {
    setState(() {
      _trabajando = true;
      _error = null;
      _paso = _adjuntar ? 'Cargando comprobantes…' : 'Armando el PDF…';
    });

    final adjuntos = <ComprobanteAdjunto>[];
    if (_adjuntar) {
      for (final e in _movimientos.where((x) => x.hasReceipt)) {
        final r = await widget.vm.receipt(e.id);
        if (!mounted) return null;
        // Un comprobante que no se pudo traer no tumba el estado de cuenta: se
        // queda fuera y el resto se genera igual.
        if (r case Ok<String>(:final value)) {
          final bytes = bytesDeDataUri(value);
          if (bytes != null) adjuntos.add(ComprobanteAdjunto(entry: e, jpeg: bytes));
        }
      }
      if (mounted) setState(() => _paso = 'Armando el PDF…');
    }

    try {
      final bytes = await estadoDeCuentaPdf(
        debt: widget.debt,
        movimientos: _movimientos,
        hoy: widget.vm.hoy ?? hoyLocal(),
        cuenta: widget.cuenta,
        palabras: PalabrasEstado(
          prestado: widget.lado.prestado,
          abonado: widget.lado.abonado,
          prestamo: widget.lado.prestamo,
          abono: widget.lado.abono,
          cobro: widget.lado == Lado.meDeben,
        ),
        plata: plata,
        fecha: (d) => fecha(d, conAno: true),
        comprobantes: adjuntos,
      );
      if (mounted) setState(() => _trabajando = false);
      return bytes;
    } catch (_) {
      if (mounted) {
        setState(() {
          _trabajando = false;
          _error = 'No se pudo armar el PDF.';
        });
      }
      return null;
    }
  }

  String get _nombreArchivo {
    // Sin caracteres que a Android no le gusten en un nombre de archivo.
    final limpio = widget.debt.name.replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '');
    return 'Estado de cuenta - $limpio - ${widget.vm.hoy ?? hoyLocal()}.pdf';
  }

  Future<void> _compartirPdf() async {
    final bytes = await _armar();
    if (bytes == null || !mounted) return;
    await Printing.sharePdf(bytes: bytes, filename: _nombreArchivo);
    if (mounted) Navigator.of(context).pop();
  }

  /// Guardar o imprimir: es la misma hoja del sistema, y desde ahí se elige
  /// "Guardar como PDF".
  Future<void> _guardarPdf() async {
    final bytes = await _armar();
    if (bytes == null || !mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: _nombreArchivo);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _compartirTexto() async {
    final texto = resumenTexto(
      debt: widget.debt,
      cobro: widget.lado == Lado.meDeben,
      hoy: widget.vm.hoy ?? hoyLocal(),
      pago: widget.vm.pago,
      etiquetaPrestado: widget.lado.prestado,
      etiquetaAbonado: widget.lado.abonado,
      palabra: (esPrestamo) => esPrestamo ? widget.lado.prestamo : widget.lado.abono,
      plata: plata,
      fecha: (d) => fecha(d, conAno: true),
      movimientos: [
        for (final e in _movimientos)
          (
            day: e.day,
            reason: e.reason,
            amount: e.amount,
            currency: e.currency,
            isLoan: e.isLoan,
          ),
      ],
    );
    await Share.share(texto, subject: widget.debt.name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Compartir',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'El estado de cuenta de ${widget.debt.name}: el resumen y sus '
              '${plural(_movimientos.length, 'movimiento', 'movimientos')}, '
              'con el saldo después de cada uno.',
              style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
            ),
            const SizedBox(height: 16),

            if (_conComprobante > 0)
              Card(
                child: SwitchListTile(
                  value: _adjuntar,
                  onChanged: _trabajando ? null : (v) => setState(() => _adjuntar = v),
                  title: Text(
                    'Adjuntar ${plural(_conComprobante, 'comprobante', 'comprobantes')}',
                    style: TextStyle(fontSize: 14.5, color: t.ink),
                  ),
                  subtitle: Text(
                    'Uno por página, al final del PDF.',
                    style: TextStyle(fontSize: 12.5, color: t.faint),
                  ),
                ),
              ),

            if (_trabajando) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(_paso ?? '', style: TextStyle(fontSize: 13, color: t.muted)),
                ],
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Aviso(_error!, tono: Tono.malo, icono: Icons.error_outline),
            ],

            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _trabajando ? null : _compartirPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Compartir el PDF'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _trabajando ? null : _guardarPdf,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Guardar o imprimir'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _trabajando ? null : _compartirTexto,
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Mandar el resumen por mensaje'),
            ),
            const SizedBox(height: 6),
            Text(
              widget.lado == Lado.meDeben
                  ? 'El mensaje arranca con el recordatorio del pago, listo para enviar.'
                  : 'Un resumen corto en texto, para pegar donde haga falta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
