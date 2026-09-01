import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapboxMap? mapboxMap;

  Future<void> _onMapCreated(MapboxMap controller) async {
  mapboxMap = controller;

  // Activa el "puck" (punto azul) que muestra tu ubicación en el mapa
  await mapboxMap?.location.updateSettings(
    LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      puckBearingEnabled: true,
    ),
  );

  await _goToUserLocation();
}

  Future<void> _goToUserLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();

    await mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 15.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('mapWidget'),
            styleUri: 'mapbox://styles/chab8/cmm6hxker009n01s8ftpbgmdc',
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(-65.2226, -26.8241)),
              zoom: 12.0,
            ),
            onMapCreated: _onMapCreated,
          ),
        ],
      ),
    );
  }
}
