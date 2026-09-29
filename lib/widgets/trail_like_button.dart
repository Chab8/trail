import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/trail_like_service.dart';

/// Corazón + contador de likes de un trail.
///
/// Muestra el corazón violeta (relleno) si el usuario actual ya le dio
/// like, o el corazón blanco (contorno) si no. Al tocarlo, guarda o saca
/// el like en Supabase: el cambio se ve al instante en pantalla
/// (actualización optimista) y se revierte solo si el guardado falla.
///
/// Usa el caché en memoria de [TrailLikeService] para que múltiples
/// instancias del mismo trail (p. ej. lista + dialog de detalle) compartan
/// el estado y la primera apertura sea instantánea si el trail ya fue visto.
class TrailLikeButton extends StatefulWidget {
  const TrailLikeButton({
    super.key,
    required this.trailId,
    this.iconSize = 16,
  });

  final String trailId;
  final double iconSize;

  @override
  State<TrailLikeButton> createState() => _TrailLikeButtonState();
}

class _TrailLikeButtonState extends State<TrailLikeButton> {
  final _likeService = TrailLikeService();

  bool _isLoading = true;
  bool _isLiked = false;
  int _count = 0;
  bool _isSaving = false;
  StreamSubscription<String>? _changeSub;

  @override
  void initState() {
    super.initState();
    _initFromCache();
    // Escucha cambios de otros botones del mismo trail para mantenerse sincronizado.
    _changeSub = _likeService.changes.listen(_onExternalChange);
  }

  @override
  void dispose() {
    _changeSub?.cancel();
    super.dispose();
  }

  void _onExternalChange(String changedTrailId) {
    if (changedTrailId != widget.trailId) return;
    if (_isSaving) return; // ya estamos en medio de nuestro propio toggle
    if (!_likeService.isCached(changedTrailId)) return;
    final (count, isLiked) = _likeService.getCached(changedTrailId);
    if (mounted) {
      setState(() {
        _count = count;
        _isLiked = isLiked;
      });
    }
  }

  /// Si ya hay datos en caché los aplica de inmediato (sin loading),
  /// y en paralelo lanza la carga real (que también actualiza el caché).
  void _initFromCache() {
    if (_likeService.isCached(widget.trailId)) {
      final (count, isLiked) = _likeService.getCached(widget.trailId);
      // Sin setState asíncrono: en initState podemos asignar directamente.
      _count = count;
      _isLiked = isLiked;
      _isLoading = false;
    } else {
      _loadLikeInfo();
    }
  }

  Future<void> _loadLikeInfo() async {
    try {
      final (count, isLiked) = await _likeService.fetchLikeInfo(widget.trailId);
      if (!mounted) return;
      setState(() {
        _count = count;
        _isLiked = isLiked;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_isSaving) return;

    final wasLiked = _isLiked;
    final previousCount = _count;

    // Actualización optimista: cambiamos en pantalla y en el caché compartido
    // antes de que termine de guardarse, para que se sienta instantáneo.
    _likeService.applyOptimisticLike(widget.trailId, liked: !wasLiked);
    setState(() {
      _isLiked = !wasLiked;
      _count = wasLiked ? _count - 1 : _count + 1;
      _isSaving = true;
    });

    try {
      if (wasLiked) {
        await _likeService.unlike(widget.trailId);
      } else {
        await _likeService.like(widget.trailId);
      }
    } catch (_) {
      // Si falló el guardado, volvemos el corazón, el contador y el caché atrás.
      _likeService.revertLike(
        widget.trailId,
        wasLiked: wasLiked,
        previousCount: previousCount,
      );
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _count = previousCount;
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isLoading ? 0 : 1,
      child: GestureDetector(
        onTap: _isLoading ? null : _toggleLike,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              _isLiked
                  ? 'assets/icons/selected_heart.svg'
                  : 'assets/icons/unselected_heart.svg',
              width: widget.iconSize,
              height: widget.iconSize,
            ),
            const SizedBox(width: 4),
            Text(
              '$_count',
              style: const TextStyle(
                color: Color(0xFFFEFEFE),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}