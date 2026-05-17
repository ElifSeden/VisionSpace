import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/remote_image.dart';
import '../../data/sample_furniture.dart';
import '../../l10n/app_localizations.dart';
import '../../models/furniture_item.dart';
import '../../models/product_spot.dart';
import '../product/product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    required this.favoriteIds,
    required this.onToggleFavorite,
    super.key,
  });

  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const _filters = ['All', 'Chair', 'Sofa', 'Table', 'Decor'];
  String _selectedFilter = 'All';

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
            LayoutBuilder(
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
                      onToggleFavorite: () => widget.onToggleFavorite(item.id),
                    );
                  },
                );
              },
            ),
        ],
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
