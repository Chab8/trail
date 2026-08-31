import 'dart:ui';
import 'package:flutter/material.dart';

/// Widget base para el efecto "liquid glass" (vidrio líquido) que vamos a
/// usar en toda la app: blur de fondo (vidrio esmerilado), un tinte
/// translúcido, un brillo fino arriba y una sombra sutil abajo, para dar
/// sensación de profundidad y de luz reflejándose en el vidrio.
///
/// Lo usan tanto la bottom bar como la barra de "reproduciendo ahora" de
/// Spotify, así se ven exactamente iguales. Si más adelante agregamos más
/// elementos de vidrio (tarjetas del feed, el wrap, etc.), conviene
/// envolverlos también con este mismo widget.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color tintColor;
  final double tintOpacity;
  final EdgeInsetsGeometry? padding;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 20,
    this.tintColor = Colors.white,
    this.tintOpacity = 0.16,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tintColor.withValues(alpha: (tintOpacity + 0.08).clamp(0.0, 1.0)),
                  tintColor.withValues(alpha: tintOpacity.clamp(0.0, 1.0)),
                  tintColor.withValues(alpha: (tintOpacity - 0.06).clamp(0.0, 1.0)),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.32),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Brillo arriba: simula la luz reflejándose en el borde
                // superior del vidrio.
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopHighlight(),
                ),
                // Sombra sutil abajo: le da profundidad al vidrio.
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _BottomShade(),
                ),
                Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopHighlight extends StatelessWidget {
  const _TopHighlight();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _BottomShade extends StatelessWidget {
  const _BottomShade();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.10),
          ],
        ),
      ),
    );
  }
}