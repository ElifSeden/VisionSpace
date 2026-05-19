import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/remote_image.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product_spot.dart';
import '../../models/store_offer.dart';

String normalizeStoreName({
  required String storeName,
  required String brand,
  required String buyUrl,
}) {
  final raw = storeName.trim().isNotEmpty ? storeName.trim() : brand.trim();
  final lowerRaw = raw.toLowerCase();
  final lowerUrl = buyUrl.toLowerCase();

  if (lowerRaw.contains('ikea') || lowerUrl.contains('ikea')) return 'IKEA';
  if (lowerRaw.contains('vivense') || lowerUrl.contains('vivense')) {
    return 'Vivense';
  }
  if (lowerRaw.contains('istikbal') || lowerUrl.contains('istikbal')) {
    return 'İstikbal';
  }

  if (raw.isNotEmpty && !raw.contains('_') && !raw.contains('/')) {
    return raw;
  }
  return 'Mağaza';
}

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    required this.product,
    this.isFavorite = false,
    this.onToggleFavorite,
    super.key,
  });

  final ProductSpot product;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
  }

  String get _storeDisplayName {
    return normalizeStoreName(
      storeName: widget.product.storeName,
      brand: widget.product.brand,
      buyUrl: widget.product.buyUrl,
    );
  }

  List<StoreOffer> get _offers {
    if (widget.product.buyUrl.isNotEmpty) {
      return [
        StoreOffer(
          storeName: _storeDisplayName,
          price: widget.product.price,
          url: widget.product.buyUrl,
          buttonColor: AppColors.sage,
        ),
      ];
    }

    return [
      const StoreOffer(
        storeName: 'trendyol',
        price: '18.499 TL',
        url: 'https://www.trendyol.com',
        buttonColor: Color(0xFFF26A21),
      ),
      const StoreOffer(
        storeName: 'IKEA',
        price: '17.999 TL',
        url: 'https://www.ikea.com.tr',
        buttonColor: Color(0xFF0B6FB3),
      ),
      const StoreOffer(
        storeName: 'VIVENSE',
        price: '18.250 TL',
        url: 'https://www.vivense.com',
        buttonColor: Color(0xFF3B464B),
      ),
      const StoreOffer(
        storeName: 'hepsiburada',
        price: '18.499 TL',
        url: 'https://www.hepsiburada.com',
        buttonColor: Color(0xFFFF6000),
      ),
      const StoreOffer(
        storeName: 'amazon.com.tr',
        price: '19.250 TL',
        url: 'https://www.amazon.com.tr',
        buttonColor: Color(0xFFFFA41C),
      ),
    ];
  }

  Future<void> _openStore(BuildContext context, StoreOffer offer) async {
    final uri = Uri.parse(offer.url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.productStoreOpenFailed(offer.storeName),
          ),
        ),
      );
    }
  }

  void _handleToggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    widget.onToggleFavorite?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                _ProductHeader(
                  title: l10n.productDetailTitle,
                  isFavorite: _isFavorite,
                  onToggleFavorite: _handleToggleFavorite,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1.55,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: AppColors.surface),
                      child: RemoteImage(url: widget.product.imageUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(widget.product.name, style: textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  _descriptionFor(widget.product, l10n),
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.ink,
                      size: 23,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.productRatingSummary('4.6', 128),
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  widget.product.buyUrl.isNotEmpty
                      ? _storeDisplayName
                      : l10n.productPurchaseOptions,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < _offers.length; index++)
                        _StoreOfferRow(
                          offer: _offers[index],
                          buttonLabel: l10n.productGoToProduct,
                          showDivider: index != _offers.length - 1,
                          onOpen: () => _openStore(context, _offers[index]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SecurityNote(message: l10n.productSecurityNote),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _descriptionFor(ProductSpot product, AppLocalizations l10n) {
    if (product.name.toLowerCase().contains('koltuk')) {
      return l10n.productDescriptionSofa;
    }

    return l10n.productDescriptionGeneric;
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.title,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onBack,
  });

  final String title;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.ink,
            ),
          ),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _ProductFavoriteButton(
              isFavorite: isFavorite,
              onPressed: onToggleFavorite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFavoriteButton extends StatelessWidget {
  const _ProductFavoriteButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton.filled(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 20,
        ),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface.withValues(alpha: 0.94),
          foregroundColor: isFavorite ? AppColors.heart : AppColors.ink,
          elevation: 2,
        ),
      ),
    );
  }
}

class _StoreOfferRow extends StatelessWidget {
  const _StoreOfferRow({
    required this.offer,
    required this.buttonLabel,
    required this.showDivider,
    required this.onOpen,
  });

  final StoreOffer offer;
  final String buttonLabel;
  final bool showDivider;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(child: _StoreLogoText(storeName: offer.storeName)),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: Text(
                offer.price,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 104,
              height: 42,
              child: FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: offer.buttonColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreLogoText extends StatelessWidget {
  const _StoreLogoText({required this.storeName});

  final String storeName;

  @override
  Widget build(BuildContext context) {
    final lowerName = storeName.toLowerCase();
    final color = switch (lowerName) {
      'trendyol' => const Color(0xFFF26A21),
      'ikea' => const Color(0xFF0B4F9F),
      'vivense' => const Color(0xFF3B464B),
      'hepsiburada' => const Color(0xFFFF6000),
      _ => AppColors.ink,
    };

    return Text(
      storeName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: lowerName == 'amazon.com.tr' ? 18 : 20,
        fontWeight: lowerName == 'vivense' ? FontWeight.w800 : FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.lock_outline_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
