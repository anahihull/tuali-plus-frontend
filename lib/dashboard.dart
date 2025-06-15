import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Dashboard extends StatefulWidget {
  final String storeId; // el ID del punto de venta
  final String direccion;
  final String userId; // el ID del usuario autenticado
  const Dashboard({super.key, required this.storeId, required this.direccion, required this.userId});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? storeData;
  DateTime? lastVisitDate;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    // 1. Obtener datos de la tienda
    final response = await supabase
        .from('puntos_de_venta')
        .select()
        .eq('id', widget.storeId)
        .single();

    // 2. Obtener la última visita desde la tabla de reportes
    final reportResponse = await supabase
        .from('reportes') // Asegúrate que esta es la tabla correcta
        .select('fecha')
        .eq('punto_de_venta_id', widget.storeId)
        .order('fecha', ascending: false)
        .limit(1);

    // 3. Extraer la fecha si hay resultados
    if (reportResponse.isNotEmpty) {
      lastVisitDate = DateTime.parse(reportResponse.first['fecha']);
    }

    setState(() {
      storeData = response;
    });
  }

  String _getSatisfactionMessage(double nps) {
    if (nps < 0.2) {
      return 'Hay muchos problemas que atender urgentemente.';
    } else if (nps < 0.4) {
      return 'Se identifican áreas críticas por mejorar.';
    } else if (nps < 0.6) {
      return 'La tienda está haciendo bien las cosas,\npero hay áreas a reforzar.';
    } else if (nps < 0.8) {
      return 'Buen desempeño general, pero aún se puede mejorar.';
    } else {
      return '¡Excelente! La tienda está superando expectativas.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (storeData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nps = (storeData!['nps'] ?? 0) / 100;
    final damageRate = storeData!['damage_rate'] ?? 0;
    final outOfStock = storeData!['out_of_stock'] ?? 0;
    final fillRate = storeData!['fillfoundrate'] ?? 0;
    final nombre = storeData!['nombre'] ?? 'Tienda';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF5F3),
      appBar: AppBar(
        title: Text(nombre),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(widget.direccion, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
           Text(
              'Última visita: ${lastVisitDate != null ? "${lastVisitDate!.day.toString().padLeft(2, '0')}/${lastVisitDate!.month.toString().padLeft(2, '0')}/${lastVisitDate!.year}" : "Sin visitas registradas"}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              _getSatisfactionMessage(nps),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildSatisfactionBar(context, nps),
                  const SizedBox(height: 16),
                  Text(
                    'Los clientes reportan una satisfacción del ${(nps * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${damageRate.toStringAsFixed(2)}%',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('% productos dañados',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const Text(
                    '¡Cuidado! Este dato puede afectar la imagen del negocio.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${outOfStock.toStringAsFixed(2)}%',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('% productos no disponibles solicitados',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const Text(
                    '¡Atención! La demanda superó la disponibilidad.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${fillRate.toStringAsFixed(2)}%',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('% productos en existencia y provistos',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const Text(
                    'Inventario alineado con lo que el cliente necesita.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/record',
                    arguments: {
                      'id': widget.storeId,
                      'userId': widget.userId,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Visitar', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatisfactionBar(BuildContext context, double satisfaction) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('😡', style: TextStyle(fontSize: 24)),
            Text('😟', style: TextStyle(fontSize: 24)),
            Text('😐', style: TextStyle(fontSize: 24)),
            Text('😊', style: TextStyle(fontSize: 24)),
            Text('😁', style: TextStyle(fontSize: 24)),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final circleSize = 16.0;
            final leftOffset =
                (satisfaction.clamp(0.0, 1.0) * width) - (circleSize / 2);

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: const [
                      Expanded(
                        child:
                            SizedBox(height: 10, child: ColoredBox(color: Colors.red)),
                      ),
                      Expanded(
                        child: SizedBox(
                            height: 10, child: ColoredBox(color: Colors.orange)),
                      ),
                      Expanded(
                        child: SizedBox(
                            height: 10, child: ColoredBox(color: Colors.yellow)),
                      ),
                      Expanded(
                        child: SizedBox(
                            height: 10, child: ColoredBox(color: Colors.lightBlue)),
                      ),
                      Expanded(
                        child:
                            SizedBox(height: 10, child: ColoredBox(color: Colors.green)),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -3,
                  left: leftOffset,
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.black, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
