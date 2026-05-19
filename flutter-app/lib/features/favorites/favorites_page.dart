import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/remote_image.dart';
import '../../data/sample_furniture.dart';
import '../../l10n/app_localizations.dart';
import '../../models/design_project.dart';
import '../../models/furniture_item.dart';
import '../../models/product_spot.dart';
import '../../services/generated_designs_repository.dart';
import '../design/design_detail_page.dart';
import '../product/product_detail_page.dart';

enum _FavoritesSection { furniture, designs }

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    required this.favoriteIds,
    required this.onToggleFavorite,
    this.generatedDesignsRepository,
    super.key,
  });

  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;
  final GeneratedDesignsRepository? generatedDesignsRepository;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const _filters = ['All', 'Chair', 'Sofa', 'Table', 'Decor'];

  late final GeneratedDesignsRepository _generatedDesignsRepository =
      widget.generatedDesignsRepository ?? GeneratedDesignsRepository();
  late Future<List<DesignProject>> _generatedDesigns =
      _generatedDesignsRepository.fetchGeneratedDesigns();

  String _selectedFilter = 'All';
  _FavoritesSection _selectedSection = _FavoritesSection.furniture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final favorites = sampleFurniture.where((item) {
      if (!widget.favoriteIds.contains(item.id)) return false;
      if (_selectedFilter == 'All') return true;
      return _matchesFilter(item, _selectedFilter);
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 116),
        children: [
          Text(
            l10n.myFavorites,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.favoritesSubtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _FavoritesSectionTabs(
            l10n: l10n,
            selectedSection: _selectedSection,
            onChanged: (section) => setState(() => _selectedSection = section),
          ),
          const SizedBox(height: 18),
          if (_selectedSection == _FavoritesSection.furniture) ...[
            _FilterChips(
              l10n: l10n,
              filters: _filters,
              selectedFilter: _selectedFilter,
              onChanged: (filter) => setState(() => _selectedFilter = filter),
            ),
            const SizedBox(height: 18),
            if (favorites.isEmpty)
              _EmptyFavoritesCard(l10n: l10n)
            else
              _FavoriteGrid(
                favorites: favorites,
                onToggleFavorite: widget.onToggleFavorite,
              ),
          ] else
            _GeneratedDesignsList(
              future: _generatedDesigns,
              onRefresh: () {
                setState(() {
                  _generatedDesigns = _generatedDesignsRepository
                      .fetchGeneratedDesigns();
                });
              },
            ),
        ],
      ),
    );
  }
}

class _FavoritesSectionTabs extends StatelessWidget {
  const _FavoritesSectionTabs({
    required this.l10n,
    required this.selectedSection,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final _FavoritesSection selectedSection;
  final ValueChanged<_FavoritesSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _FavoritesSectionButton(
            label: l10n.favoritesFurnitureTab,
            icon: Icons.favorite_rounded,
            selected: selectedSection == _FavoritesSection.furniture,
            onTap: () => onChanged(_FavoritesSection.furniture),
          ),
          _FavoritesSectionButton(
            label: l10n.favoritesDesignsTab,
            icon: Icons.auto_awesome_rounded,
            selected: selectedSection == _FavoritesSection.designs,
            onTap: () => onChanged(_FavoritesSection.designs),
          ),
        ],
      ),
    );
  }
}

class _FavoritesSectionButton extends StatelessWidget {
  const _FavoritesSectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppColors.sage : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.l10n,
    required this.filters,
    required this.selectedFilter,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == selectedFilter;
          return ChoiceChip(
            label: Text(_localizedFilter(l10n, filter)),
            selected: selected,
            onSelected: (_) => onChanged(filter),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.sage,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: selected ? AppColors.sage : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteGrid extends StatelessWidget {
  const _FavoriteGrid({
    required this.favorites,
    required this.onToggleFavorite,
  });

  final List<FurnitureItem> favorites;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: favorites.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth > 560 ? 3 : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: constraints.maxWidth > 380 ? 0.68 : 0.62,
          ),
          itemBuilder: (context, index) {
            final item = favorites[index];
            return _FavoriteCard(
              item: item,
              onToggleFavorite: () => onToggleFavorite(item.id),
            );
          },
        );
      },
    );
  }
}

class _GeneratedDesignsList extends StatelessWidget {
  const _GeneratedDesignsList({required this.future, required this.onRefresh});

  final Future<List<DesignProject>> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<DesignProject>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final designs = snapshot.data ?? const <DesignProject>[];
        if (designs.isEmpty) {
          return _EmptyGeneratedDesignsCard(l10n: l10n, onRefresh: onRefresh);
        }

        return Column(
          children: designs.map((project) {
            return _GeneratedDesignCard(project: project);
          }).toList(),
        );
      },
    );
  }
}

class _GeneratedDesignCard extends StatelessWidget {
  const _GeneratedDesignCard({required this.project});

  final DesignProject project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.07),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
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
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.generatedDesignBadge,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
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
                            l10n.designProductCount(project.products.length),
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

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.item, required this.onToggleFavorite});

  final FurnitureItem item;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
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
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: IconButton.filled(
                          padding: EdgeInsets.zero,
                          onPressed: onToggleFavorite,
                          icon: const Icon(Icons.favorite_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface.withValues(
                              alpha: 0.94,
                            ),
                            foregroundColor: AppColors.heart,
                          ),
                        ),
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
          isFavorite: true,
          onToggleFavorite: onToggleFavorite,
        ),
      ),
    );
  }
}

class _EmptyFavoritesCard extends StatelessWidget {
  const _EmptyFavoritesCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.cream,
            child: Icon(Icons.favorite_border_rounded, color: AppColors.sage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.noFavoritesMessage,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGeneratedDesignsCard extends StatelessWidget {
  const _EmptyGeneratedDesignsCard({
    required this.l10n,
    required this.onRefresh,
  });

  final AppLocalizations l10n;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.cream,
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.sage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.noGeneratedDesignsMessage,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.ink,
            tooltip: l10n.refreshGeneratedDesigns,
          ),
        ],
      ),
    );
  }
}

bool _matchesFilter(FurnitureItem item, String filter) {
  final value = '${item.title} ${item.category} ${item.description}'
      .toLowerCase();
  switch (filter) {
    case 'Chair':
      return value.contains('chair');
    case 'Sofa':
      return value.contains('sofa');
    case 'Table':
      return value.contains('table');
    case 'Decor':
      return value.contains('decor') ||
          value.contains('shelf') ||
          value.contains('storage');
    default:
      return true;
  }
}

String _localizedFilter(AppLocalizations l10n, String filter) {
  switch (filter) {
    case 'All':
      return l10n.all;
    case 'Chair':
      return l10n.categoryChair;
    case 'Sofa':
      return l10n.categorySofa;
    case 'Table':
      return l10n.categoryTable;
    case 'Decor':
      return l10n.categoryDecor;
  }
  return filter;
}
