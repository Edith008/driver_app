import 'package:driver_app/features/map/domain/delivery_stage.dart';
import 'package:driver_app/features/map/domain/delivery_stop.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryAssignment {
  DeliveryAssignment({
    required this.id,
    required this.stage,
    required this.pickupPosition,
    required this.dropoffPosition,
    required this.order,
  });

  final int id;
  final DeliveryStage stage;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
  final DeliveryOrderInfo order;

  DeliveryStop get pickupStop => DeliveryStop(
        name: 'Local de recojo',
        address: 'Pedido #${order.id}',
        reference: 'Sigue las instrucciones del local',
        position: pickupPosition,
      );

  DeliveryStop get dropoffStop => DeliveryStop(
        name: order.user.name ?? 'Cliente',
        address: 'Entrega del pedido',
        reference: 'Coordina al llegar al punto',
        position: dropoffPosition,
      );

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) {
    final orderJson = json['order'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final userJson = orderJson['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final pickupLat = (json['pickupLat'] as num?)?.toDouble() ?? 0;
    final pickupLng = (json['pickupLng'] as num?)?.toDouble() ?? 0;
    final dropoffLat = (json['dropoffLat'] as num?)?.toDouble() ??
        (userJson['locationLat'] as num?)?.toDouble() ??
        pickupLat;
    final dropoffLng = (json['dropoffLng'] as num?)?.toDouble() ??
        (userJson['locationLng'] as num?)?.toDouble() ??
        pickupLng;
    return DeliveryAssignment(
      id: json['id'] as int,
      stage: DeliveryStageMapper.fromBackend(json['estado'] as String?),
      pickupPosition: LatLng(pickupLat, pickupLng),
      dropoffPosition: LatLng(dropoffLat, dropoffLng),
      order: DeliveryOrderInfo.fromJson(orderJson),
    );
  }
}

class DeliveryOrderInfo {
  DeliveryOrderInfo({
    required this.id,
    required this.status,
    required this.total,
    required this.user,
  });

  final int id;
  final String status;
  final String total;
  final DeliveryUserInfo user;

  factory DeliveryOrderInfo.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderInfo(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'DESCONOCIDO',
      total: json['total']?.toString() ?? '0.00',
      user: DeliveryUserInfo.fromJson(
        json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class DeliveryUserInfo {
  DeliveryUserInfo({this.name, this.locationLat, this.locationLng});

  final String? name;
  final double? locationLat;
  final double? locationLng;

  LatLng? get position =>
      locationLat != null && locationLng != null ? LatLng(locationLat!, locationLng!) : null;

  factory DeliveryUserInfo.fromJson(Map<String, dynamic> json) {
    return DeliveryUserInfo(
      name: json['name'] as String?,
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
    );
  }
}

class DeliveryStageMapper {
  static DeliveryStage fromBackend(String? estado) {
    switch (estado) {
      case 'RUTA_RECOJO':
        return DeliveryStage.headingToRestaurant;
      case 'ESPERA_RESTAURANTE':
        return DeliveryStage.waitingOrder;
      case 'RUTA_ENTREGA':
        return DeliveryStage.headingToCustomer;
      case 'ESPERA_CLIENTE':
        return DeliveryStage.waitingClient;
      case 'ENTREGADO':
        return DeliveryStage.delivered;
      case 'CANCELADO':
        return DeliveryStage.delivered;
      default:
        return DeliveryStage.headingToRestaurant;
    }
  }

  static String toBackend(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.headingToRestaurant:
        return 'RUTA_RECOJO';
      case DeliveryStage.waitingOrder:
        return 'ESPERA_RESTAURANTE';
      case DeliveryStage.headingToCustomer:
        return 'RUTA_ENTREGA';
      case DeliveryStage.waitingClient:
        return 'ESPERA_CLIENTE';
      case DeliveryStage.delivered:
        return 'ENTREGADO';
    }
  }
}
