import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/remote_image.dart';
import '../../data/sample_furniture.dart';
import '../../l10n/app_localizations.dart';
import '../../models/design_project.dart';
import '../../models/furniture_item.dart';
import '../../models/product_spot.dart';
import '../../services/app_notification_service.dart';
import '../../services/decorator_ai_api.dart';
import '../design/design_detail_page.dart';
import '../notifications/notifications_page.dart';
import '../product/product_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onOpenScan,
    this.api,
    super.key,
  });

  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onOpenScan;
  final DecoratorAiApi? api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _profileNameKey = 'profile_name';

  late final DecoratorAiApi _api = widget.api ?? FirestoreDecoratorAiApi();
  late final Future<List<DesignProject>> _projects = _api.fetchProjects();
  late final Future<String?> _userName = _resolveUserName();
  String? _selectedCategory;

  Future<String?> _resolveUserName() async {
    User? user;
    try {
      if (Firebase.apps.isNotEmpty) user = FirebaseAuth.instance.currentUser;
    } catch (error, stackTrace) {
      debugPrint('Home user lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString(_profileNameKey)?.trim();
    if (storedName != null && storedName.isNotEmpty) return storedName;

    final authName = user?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filteredFurniture = _selectedCategory == null
        ? sampleFurniture
        : sampleFurniture
              .where((item) => item.category == _selectedCategory)
              .toList();

    return SafeArea(
      child: FutureBuilder<List<DesignProject>>(
        future: _projects,
        builder: (context, snapshot) {
          final projects = snapshot.data ?? const <DesignProject>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 116),
            children: [
              FutureBuilder<String?>(
                future: _userName,
                builder: (context, userSnapshot) {
                  return _HomeHeader(
                    l10n: l10n,
                    userName: userSnapshot.data,
                    onOpenNotifications: () => _openNotifications(context),
                  );
                },
              ),
              const SizedBox(height: 20),
              _HeroScanCard(l10n: l10n, onTap: widget.onOpenScan),
              const SizedBox(height: 22),
              _CategoryRow(
                l10n: l10n,
                selectedCategory: _selectedCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedCategory = _selectedCategory == category
                        ? null
                        : category;
                  });
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: l10n.recommendedFurniture,
                actionLabel: '${filteredFurniture.length} items',
              ),
              const SizedBox(height: 14),
              _FurnitureGrid(
                items: filteredFurniture,
                favoriteIds: widget.favoriteIds,
                onToggleFavorite: widget.onToggleFavorite,
              ),
              const SizedBox(height: 20),
              _AiSuggestionBanner(l10n: l10n),
              const SizedBox(height: 24),
              _SectionTitle(
                title: l10n.aiSuggestions,
                actionLabel: snapshot.connectionState == ConnectionState.waiting
                    ? 'Loading'
                    : '${projects.length} ideas',
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else
                ...projects.map((project) => _ProjectCard(project: project)),
            ],
          );
        },
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    try {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    } catch (error, stackTrace) {
      debugPrint('Notifications navigation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.l10n,
    required this.userName,
    required this.onOpenNotifications,
  });

  final AppLocalizations l10n;
  final String? userName;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final greeting = userName == null || userName!.isEmpty
        ? l10n.homeGreetingFallback
        : l10n.homeGreeting(userName!);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.homeReadySubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filled(
              onPressed: onOpenNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'Notifications',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.ink,
                elevation: 2,
                shadowColor: AppColors.ink.withValues(alpha: 0.18),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: AppNotificationService.instance.unreadCount,
              builder: (context, unreadCount, child) {
                if (unreadCount == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.heart,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.4),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroScanCard extends StatelessWidget {
  const _HeroScanCard({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _softShadow(radius: 24),
      child: Material(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -20,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white.withValues(alpha: 0.12),
                  size: 130,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.aiRoomScan,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.aiRoomScanBody,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(l10n.startScan),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.l10n,
    required this.selectedCategory,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final String? selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = [
      (Icons.chair_alt_rounded, 'Chair', l10n.categoryChair),
      (Icons.weekend_rounded, 'Sofa', l10n.categorySofa),
      (Icons.table_restaurant_rounded, 'Table', l10n.categoryTable),
      (Icons.light_rounded, 'Lamp', l10n.categoryLamp),
      (Icons.local_florist_rounded, 'Decor', l10n.categoryDecor),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.$2 == selectedCategory;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelected(category.$2),
            child: Container(
              width: 78,
              decoration: BoxDecoration(
                color: selected ? AppColors.sage : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.sage : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    category.$1,
                    color: selected ? Colors.white : AppColors.sage,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.$3,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          actionLabel,
          style: const TextStyle(
            color: AppColors.sage,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FurnitureGrid extends StatelessWidget {
  const _FurnitureGrid({
    required this.items,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  final List<FurnitureItem> items;
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth > 560 ? 3 : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: constraints.maxWidth > 380 ? 0.68 : 0.62,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _FurnitureCard(
              item: item,
              isFavorite: favoriteIds.contains(item.id),
              onToggleFavorite: () => onToggleFavorite(item.id),
            );
          },
        );
      },
    );
  }
}

class _FurnitureCard extends StatelessWidget {
  const _FurnitureCard({
    required this.item,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final FurnitureItem item;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _softShadow(radius: 22),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProduct(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(url: item.imageUrl),
                    Positioned(
                      top: 9,
                      right: 9,
                      child: _CardActionButton(
                        icon: isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        foregroundColor: isFavorite
                            ? AppColors.heart
                            : AppColors.ink,
                        onPressed: onToggleFavorite,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.style} / ${item.material}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.price,
                        style: const TextStyle(
                          color: AppColors.clay,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProduct(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: ProductSpot(
            id: item.id,
            name: item.title,
            brand: '${item.style} / ${item.material}',
            price: item.price,
            matchScore: 99,
            left: 0,
            top: 0,
            imageUrl: item.imageUrl,
            buyUrl: item.sourceUrl,
            storeName: item.storeName,
          ),
          isFavorite: isFavorite,
          onToggleFavorite: onToggleFavorite,
        ),
      ),
    );
  }
}

class _AiSuggestionBanner extends StatelessWidget {
  const _AiSuggestionBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.clay),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.freshAiIdeas,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.freshAiIdeasBody,
                  style: const TextStyle(color: AppColors.muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton.filled(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface.withValues(alpha: 0.94),
          foregroundColor: foregroundColor,
          elevation: 2,
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final DesignProject project;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DesignDetailPage(project: project),
            ),
          );
        },
        child: Container(
          height: 210,
          decoration: _softShadow(radius: 24),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RemoteImage(url: project.imageUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.ink.withValues(alpha: 0.84),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            project.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${project.spaceType} / ${project.style}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _softShadow({required double radius}) {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: AppColors.ink.withValues(alpha: 0.07),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
  );
}
