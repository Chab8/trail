import 'package:flutter/material.dart';

import '../models/badge_definition.dart';

/// Pantalla que lista todas las misiones de una categoría de badges.
/// Se abre al tocar un recuadro de categoría en BadgesScreen.
class BadgeCategoryScreen extends StatelessWidget {
  const BadgeCategoryScreen({super.key, required this.category});

  final BadgeCategory category;

  static const _cardColor = Color(0xFF09080B);
  static const _accentColor = Color(0xFF654CDD);
  static const _colorMain = Color(0xFFFEFEFE);
  static const _colorSub = Color(0xFF9C9C9C);

  @override
  Widget build(BuildContext context) {
    final badges = badgesForCategory(category);
    final mainBadges = badges.where((b) => !b.isExtra).toList();
    final extraBadges = badges.where((b) => b.isExtra).toList();

    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 6),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(29.5),
              ),
              child: badges.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Text(
                        'Próximamente.',
                        style: TextStyle(color: _colorSub, fontSize: 14),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final badge in mainBadges) _MissionTile(badge),
                        if (extraBadges.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text(
                              'Extras',
                              style: TextStyle(
                                color: _accentColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          for (final badge in extraBadges) _MissionTile(badge),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile(this.badge);

  final BadgeDefinition badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badge.name,
            style: const TextStyle(
              color: BadgeCategoryScreen._colorMain,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            badge.description,
            style: const TextStyle(
              color: BadgeCategoryScreen._colorSub,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}