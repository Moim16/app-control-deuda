// =============================================================================
//  La cáscara de la app: la barra de abajo y las pantallas que cuelgan de ella.
//
//  Solo la ve el DUEÑO. Quien entra de solo lectura no tiene más que su deuda:
//  los gastos del hogar y el vehículo no son suyos, y la API le responde 404 —
//  así que aquí ni se le ofrecen.
//
//  Las pantallas van en un `IndexedStack` y no se recrean al cambiar de
//  pestaña: volver a Gastos después de mirar el Resumen no tiene por qué
//  perder el mes que se estaba viendo ni pedir todo otra vez.
// =============================================================================

import 'package:flutter/material.dart';

import '../../spend/widgets/spend_screen.dart';
import '../../summary/widgets/summary_screen.dart';

class Cascara extends StatefulWidget {
  const Cascara({super.key});

  @override
  State<Cascara> createState() => _CascaraState();
}

class _CascaraState extends State<Cascara> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: const [
          SummaryScreen(),
          SpendScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Deudas',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Gastos',
          ),
        ],
      ),
    );
  }
}
