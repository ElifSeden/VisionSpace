import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/remote_image.dart';
import '../../l10n/app_localizations.dart';
import '../../models/design_project.dart';
import '../../models/product_spot.dart';
import '../product/product_detail_page.dart';

class DesignDetailPage extends StatelessWidget {
  const DesignDetailPage({required this.project, super.key});

  final DesignProject project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              project.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.designMatchedProducts(
                project.spaceType,
                project.style,
                project.products.length,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            AspectRatio(
              aspectRatio: 0.78,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        RemoteImage(url: project.imageUrl),
                        for (final product in project.products)
                          Positioned(
                            left: constraints.maxWidth * product.left - 19,
                            top: constraints.maxHeight * product.top - 19,
                            child: _Hotspot(product: product),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.designClickableProducts,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...project.products.map((product) {
              return _ProductTile(product: product);
            }),
          ],
        ),
      ),
    );
  }
}

class _Hotspot extends StatelessWidget {
  const _Hotspot({required this.product});

  final ProductSpot product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 23),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final ProductSpot product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(product: product),
            ),
          );
        },
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: RemoteImage(url: product.imageUrl, width: 58, height: 58),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(l10n.productMatchScore(product.matchScore)),
        trailing: Text(
          product.price,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
