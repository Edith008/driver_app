import 'dart:convert';

import 'package:driver_app/core/app_config.dart';
import 'package:driver_app/core/driver_session.dart';
import 'package:driver_app/features/orders/models/delivery_assignment.dart';
import 'package:http/http.dart' as http;

class DriverApiService {
  DriverApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _buildUri(String path) {
    final base = AppConfig.backendBaseUrl.endsWith('/')
        ? AppConfig.backendBaseUrl.substring(0, AppConfig.backendBaseUrl.length - 1)
        : AppConfig.backendBaseUrl;
    return Uri.parse('$base$path');
  }

  Future<DriverProfile> login({required String username, required String password}) async {
    final uri = _buildUri('/drivers/login');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Servidor devolvio ${response.statusCode}: ${response.body.isNotEmpty ? response.body : 'sin detalle'}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ok = data['ok'] == true;
    if (!ok) {
      throw Exception('No se pudo iniciar sesion');
    }

    final driverId = data['driverId'] as int?;
    final driverName = data['name'] as String?;
    if (driverId == null || driverName == null) {
      throw Exception('Respuesta incompleta del servidor');
    }

    return DriverProfile(id: driverId, name: driverName, username: username);
  }

  Future<void> updateLocation({
    required int driverId,
    required double lat,
    required double lng,
  }) async {
    final uri = _buildUri('/drivers/$driverId/location');
    await _client.put(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
  }

  Future<DeliveryAssignment?> fetchActiveDelivery(int driverId) async {
    final uri = _buildUri('/drivers/$driverId/delivery');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Servidor devolvio ${response.statusCode}: ${response.body.isNotEmpty ? response.body : 'sin detalle'}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hasDelivery = data['hasDelivery'] == true;
    if (!hasDelivery) {
      return null;
    }

    final deliveryJson = data['delivery'] as Map<String, dynamic>?;
    if (deliveryJson == null) {
      return null;
    }

    return DeliveryAssignment.fromJson(deliveryJson);
  }

  Future<DeliveryAssignment> updateDeliveryStatus({
    required int driverId,
    required int deliveryId,
    required String status,
  }) async {
    final uri = _buildUri('/drivers/$driverId/delivery/$deliveryId/status');
    final response = await _client.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Servidor devolvio ${response.statusCode}: ${response.body.isNotEmpty ? response.body : 'sin detalle'}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return DeliveryAssignment.fromJson(data);
  }
}
