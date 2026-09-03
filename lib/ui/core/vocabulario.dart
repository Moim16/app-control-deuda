// =============================================================================
//  El vocabulario: como se llaman las cosas de un lado y del otro.
//
//  La misma deuda se cuenta al reves segun quien mire. El dueño registra "le
//  debo a mi hermano C$3,500"; su hermano, cuando entra, es el acreedor y ve
//  "me deben C$3,500", "presté", "me han pagado". No son dos registros: es la
//  misma fila leida desde el otro lado.
//
//  Por eso las palabras no dependen solo de `direction`, sino de QUIEN esta
//  mirando. Y viven todas aqui — igual que la constante SIDE de la version web —
//  para que no haya un `if (esCobro)` suelto en media docena de pantallas.
//
//  Si hay que agregar una frase, se agrega a las DOS entradas.
// =============================================================================

import '../../domain/models/debt.dart';
import '../../domain/models/me.dart';

class Lado {
  const Lado({
    required this.tab,
    required this.cosa,
    required this.cosas,
    required this.totalTitulo,
    required this.saldoTitulo,
    required this.saldada,
    required this.prestamo,
    required this.prestamos,
    required this.abono,
    required this.abonos,
    required this.prestado,
    required this.abonado,
    required this.pendiente,
    required this.lista,
    required this.chip,
    required this.pagadoAdverbio,
    required this.loPrestado,
    required this.tocaTitulo,
    required this.nuevo,
    required this.vacio,
    required this.sinMovimientos,
    required this.primerMovimiento,
    required this.ayudaPrestamo,
    required this.ayudaAbono,
    required this.pistaMotivoPrestamo,
    required this.pistaMotivoAbono,
  });

  /// "Debo" · "Me deben"
  final String tab;

  /// "deuda" · "cobro"
  final String cosa;
  final String cosas;

  /// "Debo en total" · "Me deben en total"
  final String totalTitulo;

  /// "Debo actualmente" · "Me deben actualmente"
  final String saldoTitulo;

  /// "Deuda saldada" · "Cobro saldado"
  final String saldada;

  /// "Préstamo" · "Préstamo que hice"
  final String prestamo;
  final String prestamos;

  /// "Abono" · "Pago recibido"
  final String abono;
  final String abonos;

  /// "Prestado" · "Presté"
  final String prestado;

  /// "Abonado" · "Me han pagado"
  final String abonado;

  /// "Por pagar" · "Por cobrar"
  final String pendiente;

  /// "Mis deudas" · "Lo que me deben"
  final String lista;

  /// "debo" · "me deben" (debajo del monto de una tarjeta)
  final String chip;

  /// "pagado" · "cobrado"
  final String pagadoAdverbio;

  /// "prestado" · "que presté"
  final String loPrestado;

  /// "Lo que toca pagar" · "Lo que toca cobrar"
  final String tocaTitulo;

  /// "Nueva deuda" · "Nuevo cobro"
  final String nuevo;

  /// Lo que dice la pantalla cuando no hay nada.
  final String vacio;
  final String sinMovimientos;
  final String primerMovimiento;

  /// Debajo del titulo del formulario: que hace este movimiento con el saldo.
  final String ayudaPrestamo;
  final String ayudaAbono;

  /// Los ejemplos del campo "Motivo".
  final String pistaMotivoPrestamo;
  final String pistaMotivoAbono;

  static const debo = Lado(
    tab: 'Debo',
    cosa: 'deuda',
    cosas: 'deudas',
    totalTitulo: 'Debo en total',
    saldoTitulo: 'Debo actualmente',
    saldada: 'Deuda saldada',
    prestamo: 'Préstamo',
    prestamos: 'Préstamos',
    abono: 'Abono',
    abonos: 'Abonos',
    prestado: 'Prestado',
    abonado: 'Abonado',
    pendiente: 'Por pagar',
    lista: 'Mis deudas',
    chip: 'debo',
    pagadoAdverbio: 'pagado',
    loPrestado: 'prestado',
    tocaTitulo: 'Lo que toca pagar',
    nuevo: 'Nueva deuda',
    vacio: 'Todavía no tienes ninguna deuda registrada.',
    sinMovimientos:
        'Todavía no hay nada registrado.\nVe cargando los préstamos que te han hecho: el saldo se calcula solo.',
    primerMovimiento: 'Registrar el primer préstamo',
    ayudaPrestamo: 'Algo que te prestaron: sube lo que debes.',
    ayudaAbono: 'Un pago tuyo: baja lo que debes.',
    pistaMotivoPrestamo: 'Para la moto, universidad, emergencia…',
    pistaMotivoAbono: 'Abono de marzo, transferencia…',
  );

  static const meDeben = Lado(
    tab: 'Me deben',
    cosa: 'cobro',
    cosas: 'cobros',
    totalTitulo: 'Me deben en total',
    saldoTitulo: 'Me deben actualmente',
    saldada: 'Cobro saldado',
    prestamo: 'Préstamo que hice',
    prestamos: 'Lo que presté',
    abono: 'Pago recibido',
    abonos: 'Pagos recibidos',
    prestado: 'Presté',
    abonado: 'Me han pagado',
    pendiente: 'Por cobrar',
    lista: 'Lo que me deben',
    chip: 'me deben',
    pagadoAdverbio: 'cobrado',
    loPrestado: 'que presté',
    tocaTitulo: 'Lo que toca cobrar',
    nuevo: 'Nuevo cobro',
    vacio: 'Todavía no tienes ningún cobro registrado.',
    sinMovimientos:
        'Todavía no hay nada registrado.\nVe cargando lo que le prestaste: el saldo se calcula solo.',
    primerMovimiento: 'Registrar el primer préstamo',
    ayudaPrestamo: 'Algo que prestaste: sube lo que te deben.',
    ayudaAbono: 'Un pago que recibiste: baja lo que te deben.',
    pistaMotivoPrestamo: 'Para la moto, universidad, emergencia…',
    pistaMotivoAbono: 'Pago de marzo, me transfirió…',
  );
}

/// El lado con el que hay que CONTAR una deuda a quien la esta mirando: la
/// direccion tal cual para el dueño, invertida para quien entra de solo lectura
/// (que es, justamente, el acreedor de la deuda que le compartieron).
Lado ladoDe(Debt debt, Me me) => _lado(debt.direction, me);

/// Lo mismo, para la pestaña que se esta mirando en el resumen.
Lado ladoDeVista(DebtDirection direction, Me me) => _lado(direction, me);

Lado _lado(DebtDirection direction, Me me) {
  final visto = me.isOwner ? direction : direction.flipped;
  return visto == DebtDirection.owed ? Lado.meDeben : Lado.debo;
}
