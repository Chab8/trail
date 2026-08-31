import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;

import '../widgets/now_playing_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapboxMap? mapboxMap;

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    await mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));

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
          // Se muestra sobre la barra de navegación cuando hay una canción activa.
          const Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: NowPlayingBar(),
          ),
        ],
      ),
    );
  }
}
