import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    double satisfaction = 0.5; // nivel de satisfacción (de 0.0 a 1.0)

    return Scaffold(
      backgroundColor: const Color(0xFFFDF5F3),
      appBar: AppBar(
        title: const Text('Nombre de tienda 1'),
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
            const Text('Dirección 1', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            const Text(
              'Última visita: 06/06/2025',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              'La tienda está haciendo bien las cosas,\npero hay áreas a reforzar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w500),
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
                  _buildSatisfactionBar(context, satisfaction),
                  const SizedBox(height: 16),
                  const Text(
                    'Los clientes reportan una satisfacción del 50%',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),

                  // Producto dañado
                  const Text(
                    '2%',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '% productos dañados',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Text(
                    '¡Cuidado! Este dato puede afectar la imagen del negocio.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // No disponibles
                  const Text(
                    '20%',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '% productos no disponibles solicitados',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Text(
                    '¡Atención! La demanda superó la disponibilidad.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Existencia
                  const Text(
                    '80%',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '% productos en existencia y provistos',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
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
                onPressed: () {},
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

  /// Widget personalizado para barra de satisfacción
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
                // Barra de colores segmentada
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: const [
                      Expanded(
                        child: SizedBox(
                          height: 10,
                          child: ColoredBox(color: Colors.red),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 10,
                          child: ColoredBox(color: Colors.orange),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 10,
                          child: ColoredBox(color: Colors.yellow),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 10,
                          child: ColoredBox(color: Colors.lightBlue),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 10,
                          child: ColoredBox(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicador circular blanco
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
