import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../data/sample_furniture.dart';
import '../features/favorites/favorites_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../features/scan/scan_page.dart';
import '../l10n/app_localizations.dart';
import '../services/app_notification_service.dart';
import '../services/decorator_ai_api.dart';

class AppShell extends StatefulWidget {
  const AppShell({this.initialIndex = 0, this.homeApi, super.key});

  static const enteredAppKey = 'has_entered_app';
  static const selectedTabKey = 'selected_tab_index';

  final int initialIndex;
  final DecoratorAiApi? homeApi;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _favoriteFurnitureKey = 'favorite_furniture_ids';

  late int _index;
  Set<String> _favoriteFurnitureIds = <String>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3).toInt();
    _persistSelectedIndex(_index);
    _loadFurnitureState();
    AppNotificationService.instance.loadNotifications();
  }

  Future<void> _loadFurnitureState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _favoriteFurnitureIds =
          (prefs.getStringList(_favoriteFurnitureKey) ?? const <String>[])
              .toSet();
    });
  }

  Future<void> _persistSet(String key, Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, values.toList()..sort());
  }

  Future<void> _persistSelectedIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppShell.enteredAppKey, true);
    await prefs.setInt(AppShell.selectedTabKey, index);
  }

  void _selectIndex(int index) {
    setState(() => _index = index);
    _persistSelectedIndex(index);
  }

  void _toggleFavorite(String furnitureId) {
    final wasFavorite = _favoriteFurnitureIds.contains(furnitureId);
    setState(() {
      if (wasFavorite) {
        _favoriteFurnitureIds.remove(furnitureId);
      } else {
        _favoriteFurnitureIds.add(furnitureId);
      }
    });
    _persistSet(_favoriteFurnitureKey, _favoriteFurnitureIds);
    String? itemName;
    for (final item in sampleFurniture) {
      if (item.id == furnitureId) {
        itemName = item.title;
        break;
      }
    }
    if (itemName != null) {
      if (wasFavorite) {
        AppNotificationService.instance.addFavoriteRemoved(itemName);
      } else {
        AppNotificationService.instance.addFavoriteAdded(itemName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = [
      HomePage(
        favoriteIds: _favoriteFurnitureIds,
        onToggleFavorite: _toggleFavorite,
        onOpenScan: () => _selectIndex(1),
        api: widget.homeApi,
      ),
      const ScanPage(),
      FavoritesPage(
        favoriteIds: _favoriteFurnitureIds,
        onToggleFavorite: _toggleFavorite,
      ),
      const ProfilePage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: SafeArea(
              child: Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.10),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: l10n.navHome,
                      selected: _index == 0,
                      onTap: () => _selectIndex(0),
                    ),
                    _NavItem(
                      icon: Icons.document_scanner_rounded,
                      label: l10n.navScan,
                      selected: _index == 1,
                      onTap: () => _selectIndex(1),
                    ),
                    _NavItem(
                      icon: Icons.favorite_rounded,
                      label: l10n.navSaved,
                      selected: _index == 2,
                      onTap: () => _selectIndex(2),
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: l10n.navProfile,
                      selected: _index == 3,
                      onTap: () => _selectIndex(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          decoration: BoxDecoration(
            color: selected ? AppColors.sage : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : AppColors.muted,
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
