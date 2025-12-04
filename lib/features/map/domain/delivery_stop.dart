import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryStop {
  const DeliveryStop({
    required this.name,
    required this.address,
    required this.reference,
    required this.position,
    this.phone,
  });

  final String name;
  final String address;
  final String reference;
  final LatLng position;
  final String? phone;
}

class DemoDeliveryData {
  const DemoDeliveryData._();

  static const DeliveryStop restaurant = DeliveryStop(
    name: 'SuperSuperBurguer',
    address: 'Av. Cristo Redentor 456, 4to anillo',
    reference: 'Punto oficial de recojo',
    position: LatLng(-17.794705, -63.174468),
  );

  static const DeliveryStop client = DeliveryStop(
    name: 'Carlos Mendez',
    address: 'C. Guapay 233 - Cond. Las Palmas',
    reference: 'Casa 7B, porton negro',
    phone: '+591 700-55221',
    position: LatLng(-17.788102, -63.168512),
  );
}
