import 'package:flutter/material.dart';

import '../models/badge_definition.dart';
import 'badge_category_screen.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  static const _cardColor = Color(0xFF09080B);
  static const _colorMain = Color(0xFFFEFEFE);
  static const double _radius = 29.5;
  static const double _contentWidth = 350;
  static const double _gap = 18;

  static const double _smallWidth = 166;
  static const double _smallHeight = 179;
  static const double _longHeight = 123;
  // Alto del recuadro grande "All badges" (medido de la foto de referencia).
  static const double _allBadgesHeight = 395;

  void _openCategory(BuildContext context, BadgeCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BadgeCategoryScreen(category: category),
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    BadgeCategory category, {
    required double width,
    required double height,
  }) {
    return _BadgeCard(
      width: width,
      height: height,
      title: category.title,
      titleSize: 16,
      padding: const EdgeInsets.fromLTRB(19, 16, 12, 0),
      onTap: () => _openCategory(context, category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 116;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 16, bottom: bottomPadding),
          child: Center(
            child: SizedBox(
              width: _contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Badges'),
                  const SizedBox(height: 14),
                  const _BadgeCard(
                    width: _contentWidth,
                    height: _allBadgesHeight,
                    title: 'All badges',
                    titleSize: 20,
                    padding: EdgeInsets.fromLTRB(26, 22, 26, 0),
                  ),
                  const SizedBox(height: 34),
                  const _SectionTitle('Categories'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _categoryCard(
                        context,
                        BadgeCategory.walking,
                        width: _smallWidth,
                        height: _smallHeight,
                      ),
                      const SizedBox(width: _gap),
                      _categoryCard(
                        context,
                        BadgeCategory.time,
                        width: _smallWidth,
                        height: _smallHeight,
                      ),
                    ],
                  ),
                  const SizedBox(height: _gap),
                  _categoryCard(
                    context,
                    BadgeCategory.song,
                    width: _contentWidth,
                    height: _longHeight,
                  ),
                  const SizedBox(height: _gap),
                  Row(
                    children: [
                      _categoryCard(
                        context,
                        BadgeCategory.artist,
                        width: _smallWidth,
                        height: _smallHeight,
                      ),
                      const SizedBox(width: _gap),
                      _categoryCard(
                        context,
                        BadgeCategory.genre,
                        width: _smallWidth,
                        height: _smallHeight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: BadgesScreen._colorMain,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.width,
    required this.height,
    required this.title,
    required this.titleSize,
    required this.padding,
    this.onTap,
  });

  final double width;
  final double height;
  final String title;
  final double titleSize;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: BadgesScreen._cardColor,
        borderRadius: BorderRadius.circular(BadgesScreen._radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                title,
                style: TextStyle(
                  color: BadgesScreen._colorMain,
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}