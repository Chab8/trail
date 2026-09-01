import 'package:flutter/material.dart';

import '../models/follow_request.dart';
import '../services/follow_service.dart';

/// Pantalla donde ves las solicitudes de seguimiento pendientes y las
/// podés aceptar o rechazar. Se llega acá desde Configuración.
class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final _followService = FollowService();

  bool _isLoading = true;
  String? _errorMessage;
  List<FollowRequest> _requests = [];

  // Guardamos qué solicitud está "ocupada" (aceptando/rechazando) para
  // deshabilitar sus botones mientras se procesa, sin bloquear las demás.
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requests = await _followService.getPendingRequestsForMe();
      if (mounted) setState(() => _requests = requests);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudieron cargar las solicitudes.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(FollowRequest request, bool approve) async {
    setState(() => _busyIds.add(request.id));

    try {
      await _followService.respondToFollowRequest(
        requestId: request.id,
        approve: approve,
      );
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r.id == request.id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo procesar la solicitud.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de seguidor')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _requests.isEmpty
          ? const Center(child: Text('No tenés solicitudes pendientes.'))
          : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                final isBusy = _busyIds.contains(request.id);
                final hasAvatar = request.requesterAvatarUrl != null &&
                    request.requesterAvatarUrl!.isNotEmpty;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF3A3A3A),
                    backgroundImage: hasAvatar
                        ? NetworkImage(request.requesterAvatarUrl!)
                        : null,
                    child: hasAvatar
                        ? null
                        : const Icon(Icons.person, color: Colors.white70),
                  ),
                  title: Text('@${request.requesterUsername}'),
                  subtitle: const Text('Quiere seguirte'),
                  trailing: isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent),
                              tooltip: 'Rechazar',
                              onPressed: () => _respond(request, false),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.greenAccent),
                              tooltip: 'Aceptar',
                              onPressed: () => _respond(request, true),
                            ),
                          ],
                        ),
                );
              },
            ),
    );
  }
}