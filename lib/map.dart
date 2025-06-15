import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // solo si usas .env


class StoreMap extends StatefulWidget {

  final String? userId; // Agregado para recibir el ID de la tienda
  const StoreMap({super.key, this.userId });

  @override
  State<StoreMap> createState() => _StoreMapState();
}

class _StoreMapState extends State<StoreMap> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {}; // Para el radio alrededor del usuario
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _filteredStores = [];
  Map<String, dynamic>? _selectedStore;
  bool _showSearchResults = false;
  bool _showStoreConfirmation = false;
  bool _showStoresList = true; // Mostrar lista por defecto
  LatLng _userLocation = const LatLng(25.651, -100.289);

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _loadStores();
    _addUserLocationCircle();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener la ubicación: $e');
      // Usar ubicación por defecto
    }
  }

  void _addUserLocationCircle() {
    setState(() {
      _circles.add(
        Circle(
          circleId: const CircleId('user_location_radius'),
          center: _userLocation,
          radius: 500, // Radio de 500 metros
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue.withOpacity(0.3),
          strokeWidth: 2,
        ),
      );
    });
  }

  Future<void> _loadStores() async {
    try {
      final response = await supabase.from('puntos_de_venta').select();
      
      if (response.isEmpty) {
        debugPrint('📍 No hay datos en Supabase, usando tiendas de ejemplo');
        _addSampleStores();
        return;
      }

      _stores = List<Map<String, dynamic>>.from(response);
      _filteredStores = _stores;

      _markers.clear();
      for (var store in _stores) {
        final binHex = store['coordenadas'] as String?;
        if (binHex == null) continue;

        final latLng = _parseWKBGeography(binHex);
        if (latLng != null) {
          final address = await getAddressFromGoogle(latLng); // Google API

          store['position'] = latLng;
          store['direccion'] = address;

          _markers.add(
            Marker(
              markerId: MarkerId(store['nombre'] ?? 'store_${_markers.length}'),
              position: latLng,
              infoWindow: InfoWindow(
                title: store['nombre'] ?? 'Tienda',
                snippet: '${store['nps'] ?? 'Sin calificación'}',
              ),
              onTap: () => _selectStore(store, latLng),
            ),
          );
        }

      }

      // Ordenar tiendas por distancia
      _sortStoresByDistance();
      setState(() {});
      debugPrint('✅ ${_markers.length} tiendas cargadas correctamente');
    } catch (e) {
      debugPrint('❌ Error al cargar puntos de venta: $e');
      _addSampleStores();
    }
  }

  void _addSampleStores() {
    final sampleStores = [
      {
        'nombre': 'Nombre de tienda 1',
        'direccion': 'Dirección 1',
        'position': LatLng(_userLocation.latitude + 0.005, _userLocation.longitude + 0.005),
        'nps': 85,
      },
      {
        'nombre': 'Nombre de tienda 2',
        'direccion': 'Dirección 2',
        'position': LatLng(_userLocation.latitude - 0.003, _userLocation.longitude - 0.003),
        'nps': 92,
      },
      {
        'nombre': 'Nombre de tienda 3',
        'direccion': 'Dirección 3',
        'position': LatLng(_userLocation.latitude + 0.008, _userLocation.longitude - 0.004),
        'nps': 78,
      },
      {
        'nombre': 'Nombre de tienda 4',
        'direccion': 'Dirección 4',
        'position': LatLng(_userLocation.latitude - 0.006, _userLocation.longitude + 0.007),
        'nps': 88,
      },
    ];

    for (var store in sampleStores) {
      _markers.add(
        Marker(
          markerId: MarkerId(store['nombre'] as String),
          position: store['position'] as LatLng,
          infoWindow: InfoWindow(
            title: store['nombre'] as String,
            snippet: '${store['nps']} NPS',
          ),
          onTap: () => _selectStore(store, store['position'] as LatLng),
        ),
      );
    }

    _stores = sampleStores;
    _sortStoresByDistance();
    setState(() {});
  }

  void _sortStoresByDistance() {
    _filteredStores.sort((a, b) {
      final distanceA = _calculateDistance(_userLocation, a['position'] ?? _userLocation);
      final distanceB = _calculateDistance(_userLocation, b['position'] ?? _userLocation);
      return distanceA.compareTo(distanceB);
    });
  }

  void _selectStore(Map<String, dynamic> store, LatLng position) {
  setState(() {
    _selectedStore = {
      ...store,
      'position': position,
    };
    // Asegurar que se muestre la confirmación y se oculten otros paneles
    _showStoreConfirmation = true;
    _showSearchResults = false;
    _showStoresList = false;
  });
  
  // Animar la cámara hacia la tienda seleccionada
  _mapController?.animateCamera(
    CameraUpdate.newLatLngZoom(position, 16),
  );
  
  // Debug para confirmar que se está llamando
  debugPrint('✅ Tienda seleccionada: ${store['nombre']}');
}

Future<String> getAddressFromGoogle(LatLng position) async {
  final apiKey = dotenv.env['MAP_KEY']; // o reemplaza directamente con tu clave
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey',
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['results'] != null && data['results'].isNotEmpty) {
      return data['results'][0]['formatted_address'] ?? 'Dirección no encontrada';
    } else {
      return 'No se encontraron resultados';
    }
  } else {
    throw Exception('Error de geocodificación: ${response.statusCode}');
  }
}


  void _searchStores(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStores = List.from(_stores);
        _sortStoresByDistance();
        _showSearchResults = false;
        _showStoresList = true;
      } else {
        _filteredStores = _stores.where((store) {
          return (store['nombre']?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (store['direccion']?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
        _showSearchResults = true;
        _showStoreConfirmation = false;
        _showStoresList = false;
      }
    });
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    
    double lat1Rad = point1.latitude * pi / 180;
    double lat2Rad = point2.latitude * pi / 180;
    double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLng = (point2.longitude - point1.longitude) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  LatLng? _parseWKBGeography(String hex) {
    try {
      final bytes = _hexToBytes(hex);
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final lon = byteData.getFloat64(9, Endian.little);
      final lat = byteData.getFloat64(17, Endian.little);
      return LatLng(lat, lon);
    } catch (e) {
      debugPrint('❌ Error al decodificar WKB: $e');
      return null;
    }
  }

  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  Widget _buildStoreListItem(Map<String, dynamic> store, int index) {
  final storePosition = store['position'] as LatLng?;
  final distance = storePosition != null 
      ? _calculateDistance(_userLocation, storePosition)
      : 0.0;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          debugPrint('🔄 Tap en lista - Tienda: ${store['nombre']}');
          if (storePosition != null) {
            _selectStore(store, storePosition);
          } else {
            debugPrint('❌ No se encontró posición para la tienda');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.store,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store['nombre'] ?? 'Nombre de tienda ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store['direccion'] ?? 'Dirección ${index + 1}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Booking'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation,
              zoom: 15, // Zoom más cercano para mostrar el radio
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            circles: _circles, // Agregar círculos al mapa
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: (_) {
              setState(() {
                _showSearchResults = false;
                _showStoreConfirmation = false;
                _showStoresList = true; // Volver a mostrar la lista
              });
            },
          ),
          
          // Barra de búsqueda
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _searchStores,
                decoration: const InputDecoration(
                  hintText: 'Buscar tienda...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Botón de ubicación
          Positioned(
            top: 80,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_userLocation, 15),
                );
              },
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // Lista de tiendas por defecto
          if (_showStoresList)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle para arrastrar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Título
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Tiendas cercanas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_filteredStores.length} tiendas',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Lista de tiendas
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredStores.length,
                        itemBuilder: (context, index) {
                          final store = _filteredStores[index];
                          return _buildStoreListItem(store, index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Resultados de búsqueda
          if (_showSearchResults)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredStores.length,
                        itemBuilder: (context, index) {
                          final store = _filteredStores[index];
                          return _buildStoreListItem(store, index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Panel de confirmación de tienda
          if (_showStoreConfirmation && _selectedStore != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStore!['nombre'] ?? 'Nombre de tienda',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedStore!['direccion'] ?? 'Dirección',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedStore!['position'] != null 
                        ? '${_calculateDistance(_userLocation, _selectedStore!['position']).toStringAsFixed(1)} Km'
                        : '1 Km',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/dashboard',
                                arguments: {
                                  'id': _selectedStore!['id'],
                                  'direccion': _selectedStore!['direccion'],
                                  'userId': widget.userId,
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Confirmar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showStoreConfirmation = false;
                                _selectedStore = null;
                                _showStoresList = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'No, buscar otra tienda',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
