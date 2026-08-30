import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    // Sacamos el indicador de escala y el botón de la brújula del mapa.
    await mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El mapa queda excluido del fondo oscuro general de la app.
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Mapa')),
      body: MapWidget(
        key: const ValueKey('mapWidget'),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(-65.2226, -26.8241)),
          zoom: 12.0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}