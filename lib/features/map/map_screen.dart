import 'dart:async';
import 'dart:math' as math;

import 'package:driver_app/core/app_config.dart';
import 'package:driver_app/core/driver_session.dart';
import 'package:driver_app/features/map/domain/delivery_stage.dart';
import 'package:driver_app/features/map/domain/delivery_stop.dart';
import 'package:driver_app/features/orders/models/delivery_assignment.dart';
import 'package:driver_app/services/directions_service.dart';
import 'package:driver_app/services/driver_api_service.dart';
import 'package:driver_app/services/driver_location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.assignment});

  final DeliveryAssignment? assignment;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _proximityThresholdMeters = 80.0;
  static const double _routeRefreshThresholdMeters = 40.0;

  final DriverLocationService _locationService = DriverLocationService();
  final DirectionsService _directionsService = DirectionsService();
  final DriverApiService _driverApiService = DriverApiService();
  DeliveryAssignment? _currentAssignment;

  late DeliveryStop _restaurant;
  late DeliveryStop _client;

  GoogleMapController? _mapController;
  StreamSubscription<LocationData>? _locationSubscription;

  late DeliveryStage _stage;
  LocationData? _driverLocation;
  LatLng? _lastRouteOrigin;
  late LatLng _activeDestination;
  DateTime? _lastLocationSync;

  bool _isLoading = true;
  bool _isFetchingRoute = false;
  bool _nearClient = false;
  bool _mapCleared = false;

  String? _errorMessage;
  String? _distanceText;
  String? _durationText;

  Set<Polyline> _routePolylines = {};

  @override
  void initState() {
    super.initState();
    _currentAssignment = widget.assignment;
    _configureStops();
    _stage = _currentAssignment?.stage ?? DeliveryStage.headingToRestaurant;
    _activeDestination = _destinationForStage(_stage);
    _initializeMap();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _directionsService.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      await _locationService.ensurePermissions();
      final location = await _locationService.currentLocation();
      _handleLocationUpdate(location, initial: true);
      _locationSubscription = _locationService.locationStream.listen(_handleLocationUpdate);
    } on LocationException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('No se pudo iniciar el mapa: $e');
    }
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  void _handleLocationUpdate(LocationData location, {bool initial = false}) {
    if (location.latitude == null || location.longitude == null) {
      return;
    }

    final driverLatLng = LatLng(location.latitude!, location.longitude!);

    if (_mapCleared) {
      setState(() {
        _driverLocation = location;
        _isLoading = false;
      });
      _syncDriverLocation(driverLatLng);
      return;
    }

    final distanceToRestaurant = _distanceBetween(driverLatLng, _restaurant.position);
    final distanceToClient = _distanceBetween(driverLatLng, _client.position);

    var updatedStage = _stage;
    var stageChanged = false;

    if (_stage == DeliveryStage.headingToRestaurant && distanceToRestaurant <= _proximityThresholdMeters) {
      updatedStage = DeliveryStage.waitingOrder;
      stageChanged = true;
    } else if (_stage == DeliveryStage.headingToCustomer && distanceToClient <= _proximityThresholdMeters) {
      updatedStage = DeliveryStage.waitingClient;
      stageChanged = true;
    }

    if (stageChanged) {
      _activeDestination = _destinationForStage(updatedStage);
    }

    setState(() {
      _driverLocation = location;
      _nearClient = distanceToClient <= _proximityThresholdMeters;
      _stage = updatedStage;
      _isLoading = false;
    });

    if (initial) {
      _fitCameraToRoute();
    }

    if (stageChanged) {
      _fitCameraToRoute();
      _notifyStageUpdate(updatedStage);
    }

    final needsRouteRefresh =
        _stage != DeliveryStage.delivered && (_lastRouteOrigin == null || _distanceBetween(driverLatLng, _lastRouteOrigin!) > _routeRefreshThresholdMeters);
    if (needsRouteRefresh && !_isFetchingRoute) {
      _lastRouteOrigin = driverLatLng;
      _fetchRouteAndEta();
    }

    _syncDriverLocation(driverLatLng);
  }

  Future<void> _fetchRouteAndEta() async {
    if (_mapCleared) {
      return;
    }
    final origin = _driverLatLng;
    if (origin == null) return;

    setState(() {
      _isFetchingRoute = true;
    });

    try {
      final result = await _directionsService.fetchRoute(origin: origin, destination: _activeDestination);
      setState(() {
        _distanceText = result.distanceText;
        _durationText = result.durationText;
        _routePolylines = {
          Polyline(
            polylineId: PolylineId('driver_to_${_stage.name}'),
            color: const Color(0xFF126ABC),
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            points: result.points,
          ),
        };
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo calcular la ruta: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
        });
      }
    }
  }

  Future<DeliveryAssignment> _publishStage(DeliveryStage stage) async {
    final assignment = _currentAssignment;
    final driver = DriverSession.instance.driver;

    if (assignment == null || driver == null) {
      throw Exception('No existe un pedido activo para notificar al backend');
    }

    final status = DeliveryStageMapper.toBackend(stage);
    return _driverApiService.updateDeliveryStatus(
      driverId: driver.id,
      deliveryId: assignment.id,
      status: status,
    );
  }

  void _notifyStageUpdate(DeliveryStage stage) {
    if (_currentAssignment == null || _mapCleared) {
      return;
    }

    unawaited(
      _publishStage(stage).then((assignment) {
        if (!mounted) return;
        setState(() {
          _applyAssignment(assignment);
        });
      }).catchError((error) {
        if (!mounted) return;
        _showSnack('No se pudo enviar el estado al backend: $error');
      }),
    );
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearAssignmentView() {
    setState(() {
      _mapCleared = true;
      _currentAssignment = null;
      _routePolylines = {};
      _distanceText = null;
      _durationText = null;
      _isFetchingRoute = false;
    });

    final driver = _driverLatLng;
    if (driver != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(driver, 16),
      );
    }
  }

  void _syncDriverLocation(LatLng driverLatLng) {
    final driver = DriverSession.instance.driver;
    if (driver == null) {
      return;
    }

    final now = DateTime.now();
    if (_lastLocationSync != null && now.difference(_lastLocationSync!) < AppConfig.driverPollingInterval) {
      return;
    }

    _lastLocationSync = now;
    unawaited(
      _driverApiService
          .updateLocation(driverId: driver.id, lat: driverLatLng.latitude, lng: driverLatLng.longitude)
          .catchError((error) => debugPrint('No se pudo enviar ubicacion: $error')),
    );
  }

  LatLng? get _driverLatLng {
    final lat = _driverLocation?.latitude;
    final lng = _driverLocation?.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  double _distanceBetween(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final hav = math.sin(dLat / 2) * math.sin(dLat / 2) + math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180;

  void _fitCameraToRoute() {
    final driverLatLng = _driverLatLng;
    if (_mapController == null) return;

    if (driverLatLng == null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_activeDestination, 15),
      );
      return;
    }

    final bounds = _createBounds(driverLatLng, _activeDestination);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  LatLngBounds _createBounds(LatLng a, LatLng b) {
    final southwest = LatLng(
      math.min(a.latitude, b.latitude),
      math.min(a.longitude, b.longitude),
    );
    final northeast = LatLng(
      math.max(a.latitude, b.latitude),
      math.max(a.longitude, b.longitude),
    );
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  Future<void> _startDeliveryToClient() async {
    if (_currentAssignment == null) {
      _showSnack('No hay un pedido activo para actualizar.');
      return;
    }

    final previousAssignment = _currentAssignment!;

    setState(() {
      _stage = DeliveryStage.headingToCustomer;
      _activeDestination = _destinationForStage(_stage);
      _distanceText = null;
      _durationText = null;
      _routePolylines = {};
      _errorMessage = null;
    });

    try {
      final assignment = await _publishStage(DeliveryStage.headingToCustomer);
      if (!mounted) return;
      setState(() {
        _applyAssignment(assignment);
      });
      _fetchRouteAndEta();
      _fitCameraToRoute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applyAssignment(previousAssignment);
      });
      _showSnack('No se pudo actualizar el estado: $e');
    }
  }

  Future<void> _markDeliveryCompleted() async {
    if (_currentAssignment == null) {
      _showSnack('No hay un pedido activo para entregar.');
      return;
    }

    final previousAssignment = _currentAssignment!;

    setState(() {
      _stage = DeliveryStage.delivered;
      _distanceText = '0 km';
      _durationText = 'Pedido entregado';
      _routePolylines = {};
      _activeDestination = _destinationForStage(_stage);
    });

    try {
      final assignment = await _publishStage(DeliveryStage.delivered);
      if (!mounted) return;
      setState(() {
        _applyAssignment(assignment);
        _distanceText = '0 km';
        _durationText = 'Pedido entregado';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applyAssignment(previousAssignment);
      });
      _showSnack('No se pudo actualizar el estado: $e');
    }
  }

  Widget? _buildActionButton() {
    if (_stage == DeliveryStage.waitingOrder) {
      return ElevatedButton.icon(
        onPressed: () => _startDeliveryToClient(),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Pedido recogido'),
        style: _actionStyle(),
      );
    }

    if (_stage == DeliveryStage.waitingClient || (_stage == DeliveryStage.headingToCustomer && _nearClient)) {
      return ElevatedButton.icon(
        onPressed: () => _markDeliveryCompleted(),
        icon: const Icon(Icons.check),
        label: const Text('Pedido entregado'),
        style: _actionStyle(),
      );
    }

    if (_stage == DeliveryStage.delivered && !_mapCleared) {
      return ElevatedButton.icon(
        onPressed: _clearAssignmentView,
        icon: const Icon(Icons.done_all),
        label: const Text('Pedido finalizado'),
        style: _actionStyle(),
      );
    }

    return null;
  }

  ButtonStyle _actionStyle() {
    return ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: const Color(0xFF126ABC),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (!_mapCleared) {
      markers.addAll([
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _restaurant.position,
          infoWindow: InfoWindow(title: _restaurant.name, snippet: 'Local de recojo'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
        Marker(
          markerId: const MarkerId('client'),
          position: _client.position,
          infoWindow: InfoWindow(title: _client.name, snippet: 'Cliente'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      ]);
    }

    final driver = _driverLatLng;
    if (driver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          infoWindow: const InfoWindow(title: 'Mi posicion'),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF126ABC))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 72, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _isLoading = true;
                      });
                      _initializeMap();
                    },
                    style: _actionStyle(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildMap(),
            if (!_mapCleared)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _buildInfoCard(),
              ),
            if (!_mapCleared)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildBottomPanel(),
              ),
            if (!_mapCleared)
              Positioned(
                bottom: 150,
                right: 16,
                child: Column(
                  children: [
                    _MapCircleButton(
                      icon: Icons.navigation_outlined,
                      label: 'Ruta',
                      onTap: () {
                        _fetchRouteAndEta();
                        _fitCameraToRoute();
                      },
                    ),
                    const SizedBox(height: 12),
                    _MapCircleButton(
                      icon: Icons.my_location,
                      label: 'Yo',
                      onTap: () {
                        final driver = _driverLatLng;
                        if (driver != null && _mapController != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.newLatLngZoom(driver, 17),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            if (_isFetchingRoute && !_mapCleared)
              const Positioned(
                top: 24,
                right: 24,
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final mapPadding = _mapCleared ? EdgeInsets.zero : const EdgeInsets.only(top: 140, bottom: 200);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _restaurant.position, zoom: 15.5),
      markers: _buildMarkers(),
      polylines: _routePolylines,
      onMapCreated: (controller) {
        _mapController = controller;
        _fitCameraToRoute();
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      trafficEnabled: true,
      buildingsEnabled: true,
      padding: mapPadding,
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _stage.label,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _stage.hint,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _InfoChip(title: 'Distancia', value: _distanceText ?? 'Calculando...')),
              Container(width: 1, height: 32, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(child: _InfoChip(title: 'Tiempo', value: _durationText ?? 'Calculando...')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final isHeadingToClient =
      _stage == DeliveryStage.headingToCustomer || _stage == DeliveryStage.waitingClient || _stage == DeliveryStage.delivered;
    final stop = isHeadingToClient ? _client : _restaurant;
    final subtitle = isHeadingToClient && _client.phone != null
        ? 'Cliente - ${_client.phone}'
        : 'Restaurante - 3 min aprox';
    final order = _currentAssignment?.order;

    final actionButton = _buildActionButton();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stop.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place, color: Color(0xFF126ABC)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stop.address, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          stop.reference,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (order != null) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFF126ABC)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pedido #${order.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Estado: ${order.status} · Total Bs ${order.total}', style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (actionButton != null) ...[
          const SizedBox(height: 12),
          actionButton,
        ],
      ],
    );
  }
}

extension on _MapScreenState {
  void _configureStops() {
    if (_currentAssignment != null) {
      _restaurant = _currentAssignment!.pickupStop;
      _client = _currentAssignment!.dropoffStop;
    } else {
      _restaurant = DemoDeliveryData.restaurant;
      _client = DemoDeliveryData.client;
    }
  }

  void _applyAssignment(DeliveryAssignment assignment) {
    _currentAssignment = assignment;
    _restaurant = assignment.pickupStop;
    _client = assignment.dropoffStop;
    _stage = assignment.stage;
    _activeDestination = _destinationForStage(_stage);
  }

  LatLng _destinationForStage(DeliveryStage stage) {
    return stage == DeliveryStage.headingToCustomer || stage == DeliveryStage.waitingClient || stage == DeliveryStage.delivered
        ? _client.position
        : _restaurant.position;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Icon(icon, color: const Color(0xFF126ABC)),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
