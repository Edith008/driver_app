import 'package:location/location.dart';

class DriverLocationService {
  DriverLocationService({Location? location}) : _location = location ?? Location();

  final Location _location;

  Future<void> ensurePermissions() async {
    var serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw const LocationException('El GPS esta deshabilitado');
      }
    }

    var permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        throw const LocationException('Permiso de ubicacion denegado');
      }
    }

    if (permissionStatus == PermissionStatus.deniedForever) {
      throw const LocationException('Permiso de ubicacion denegado permanentemente');
    }
  }

  Future<LocationData> currentLocation() => _location.getLocation();

  Stream<LocationData> get locationStream => _location.onLocationChanged;
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
