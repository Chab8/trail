import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;

  void _onMapCreated(MapboxMap controller) {
    mapboxMap = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: MapWidget(
        key: const ValueKey('mapWidget'),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        cameraOptions: CameraOptions(
          // Centrado en San Miguel de Tucumán, para que veas algo
          // reconocible apenas abra el mapa.
          center: Point(coordinates: Position(-65.2226, -26.8241)),
          zoom: 12.0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}