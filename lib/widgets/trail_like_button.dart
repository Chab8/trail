import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/trail_like_service.dart';

/// Corazón + contador de likes de un trail.
///
/// Muestra el corazón violeta (relleno) si el usuario actual ya le dio
/// like, o el corazón blanco (contorno) si no. Al tocarlo, guarda o saca
/// el like en Supabase: el cambio se ve al instante en pantalla
/// (actualización optimista) y se revierte solo si el guardado falla.
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

  @override
  void initState() {
    super.initState();
    _loadLikeInfo();
  }

  Future<void> _loadLikeInfo() async {
    try {
      final results = await Future.wait([
        _likeService.getLikeCount(widget.trailId),
        _likeService.hasLiked(widget.trailId),
      ]);
      if (!mounted) return;
      setState(() {
        _count = results[0] as int;
        _isLiked = results[1] as bool;
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

    // Actualización optimista: cambiamos en pantalla antes de que
    // termine de guardarse, para que se sienta instantáneo.
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
      // Si falló el guardado, volvemos el corazón y el contador atrás.
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
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}