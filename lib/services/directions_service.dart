import 'dart:convert';

import 'package:driver_app/core/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DirectionsResult {
  const DirectionsResult({
    required this.distanceText,
    required this.durationText,
    required this.points,
  });

  final String distanceText;
  final String durationText;
  final List<LatLng> points;
}

class DirectionsService {
  DirectionsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<DirectionsResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (AppConfig.googleMapsApiKey.isEmpty) {
      throw Exception('Falta GOOGLE_MAPS_API_KEY');
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&mode=driving&key=${AppConfig.googleMapsApiKey}',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('No se pudo conectar con Google Maps');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw Exception('Google Maps no devolvio rutas');
    }

    final firstRoute = routes.first as Map<String, dynamic>;
    final legs = firstRoute['legs'] as List<dynamic>;
    final leg = legs.first as Map<String, dynamic>;

    final distance = (leg['distance'] as Map<String, dynamic>)['text'] as String;
    final duration = (leg['duration'] as Map<String, dynamic>)['text'] as String;
    final overviewPolyline = firstRoute['overview_polyline'] as Map<String, dynamic>;
    final encodedPoints = overviewPolyline['points'] as String;

    return DirectionsResult(
      distanceText: distance,
      durationText: duration,
      points: _decodePolyline(encodedPoints),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  @mustCallSuper
  void dispose() {
    _client.close();
  }
}
