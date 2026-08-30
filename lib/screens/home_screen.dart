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

    // Sacamos el indicador de escala y el botón de la brújula del mapa.
    await mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));

    await _goToUserLocation();
  }

  Future<void> _goToUserLocation() async {
    // 1. ¿El teléfono tiene el GPS/ubicación prendido en general?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    // 2. ¿Tenemos permiso? Si no, lo pedimos acá.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // 3. Buscamos la posición actual.
    final position = await Geolocator.getCurrentPosition();

    // 4. Movemos la cámara del mapa a esa posición.
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
      // El mapa queda excluido del fondo oscuro general de la app.
      backgroundColor: Colors.white,
      body: MapWidget(
        key: const ValueKey('mapWidget'),
        styleUri: 'mapbox://styles/chab8/cmm6hxker009n01s8ftpbgmdc',
        cameraOptions: CameraOptions(
          // Arranca en Tucumán mientras se resuelve el permiso/ubicación;
          // apenas la tengamos, la cámara salta a la ubicación real.
          center: Point(coordinates: Position(-65.2226, -26.8241)),
          zoom: 12.0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}