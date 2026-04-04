import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Resultado de la ubicación capturada
class LocationResult {
  final double latitude;
  final double longitude;
  final String? name;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.name,
  });
}

class LocationService {
  /// Solicita permiso y obtiene la ubicación actual con geocoding inverso
  Future<LocationResult?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String? placeName;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.name,
            p.locality,
            p.administrativeArea,
          ].where((s) => s != null && s.isNotEmpty).toList();
          placeName = parts.take(2).join(', ');
        }
      } catch (_) {
        placeName =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        name: placeName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Verifica si los permisos de ubicación están concedidos
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}

final locationServiceInstance = LocationService();
