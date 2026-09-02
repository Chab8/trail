import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;
  LocationComponentSettings? locationComponentSettings;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de ubicación denegado')),
      );
      return;
    }
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    // Desactivar controles de UI
    await mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));

    // ACTIVAR EL LOCATION COMPONENT (punto azul nativo)
    await _enableLocationComponent();

    // Obtener ubicación inicial
    final position = await Geolocator.getCurrentPosition();

    mapboxMap?.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _enableLocationComponent() async {
    try {
      // Configurar el componente de ubicación
      locationComponentSettings = LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true, // Efecto de pulso azul
        showAccuracyRing: true, // Mostrar círculo de precisión
      );

      // Aplicar las configuraciones al mapa
      await mapboxMap?.location.updateSettings(locationComponentSettings!);
    } catch (error) {
      debugPrint('Error al habilitar location component: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Mapa')),
      body: MapWidget(
        key: const ValueKey('mapWidget'),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        onMapCreated: _onMapCreated,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Botón para centrar en tu ubicación actual
          final position = await Geolocator.getCurrentPosition();
          mapboxMap?.easeTo(
            CameraOptions(
              center: Point(
                coordinates: Position(position.longitude, position.latitude),
              ),
              zoom: 15.0,
            ),
            MapAnimationOptions(duration: 1000),
          );
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    // Desactivar ubicación al salir
    mapboxMap?.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );
    super.dispose();
  }
}
