import 'package:driver_app/core/driver_session.dart';
import 'package:driver_app/features/map/domain/delivery_stage.dart';
import 'package:driver_app/features/map/map_screen.dart';
import 'package:driver_app/features/orders/models/delivery_assignment.dart';
import 'package:driver_app/services/driver_api_service.dart';
import 'package:flutter/material.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final DriverApiService _api = DriverApiService();
  DeliveryAssignment? _assignment;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    final driver = DriverSession.instance.driver;
    if (driver == null) {
      setState(() {
        _errorMessage = 'Debes iniciar sesion nuevamente';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assignment = await _api.fetchActiveDelivery(driver.id);
      setState(() {
        _assignment = assignment;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goToMap() {
    final assignment = _assignment;
    if (assignment == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(assignment: assignment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        backgroundColor: const Color(0xFF126ABC),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAssignment,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssignment,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF126ABC)));
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ErrorState(message: _errorMessage!, onRetry: _loadAssignment),
        ],
      );
    }

    if (_assignment == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _EmptyState(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AssignmentCard(
          assignment: _assignment!,
          onGoToMap: _goToMap,
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment, required this.onGoToMap});

  final DeliveryAssignment assignment;
  final VoidCallback onGoToMap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido #${assignment.order.id}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(assignment.stage.label),
                  backgroundColor: const Color(0xFF126ABC).withOpacity(0.1),
                  labelStyle: const TextStyle(color: Color(0xFF126ABC)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.receipt_long,
              title: 'Estado pedido',
              value: assignment.order.status,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.attach_money,
              title: 'Total',
              value: 'Bs ${assignment.order.total}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.person,
              title: 'Cliente',
              value: assignment.order.user.name ?? 'Sin nombre',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onGoToMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ir al mapa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF126ABC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                value ?? 'Sin informacion',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'No tienes pedidos asignados por ahora',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 4),
        Text(
          'Actualiza cada cierto tiempo para verificar nuevas entregas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 80, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF126ABC), foregroundColor: Colors.white),
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}
