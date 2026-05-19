import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/remote_image.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_backend_client.dart';
import 'camera_scan_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _wallLengthController = TextEditingController(text: '400');
  final _roomDepthController = TextEditingController(text: '350');
  final _ceilingHeightController = TextEditingController(text: '270');
  final _extraPreferencesController = TextEditingController();

  bool _replaceExistingFurniture = false;
  int _designCount = 2;
  final Set<String> _requestedFurnitureTypes = <String>{};
  final Set<String> _colors = <String>{};
  String? _designStyle;
  String? _material;
  String? _temperature;
  String? _size;

  @override
  void dispose() {
    _wallLengthController.dispose();
    _roomDepthController.dispose();
    _ceilingHeightController.dispose();
    _extraPreferencesController.dispose();
    super.dispose();
  }

  void _openCamera(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraScanPage(options: _scanOptions()),
      ),
    );
  }

  ScanDesignOptions _scanOptions() {
    return ScanDesignOptions(
      currentWallLengthCm: _parseDimension(_wallLengthController.text),
      roomDepthCm: _parseDimension(_roomDepthController.text),
      ceilingHeightCm: _parseDimension(_ceilingHeightController.text),
      replaceExistingFurniture: _replaceExistingFurniture,
      requestedFurnitureTypes: _requestedFurnitureTypes.toList()..sort(),
      designStyle: _designStyle,
      material: _material,
      colors: _colors.toList()..sort(),
      temperature: _temperature,
      size: _size,
      extraPreferences: _extraPreferencesController.text,
      designCount: _designCount,
    );
  }

  double? _parseDimension(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void _showTips(BuildContext context, AppLocalizations l10n) {
    final tips = [
      l10n.scanTipNaturalLight,
      l10n.scanTipTidyRoom,
      l10n.scanTipWholeRoom,
      l10n.scanTipAvoidBlur,
      l10n.scanTipCornerPhoto,
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.sage,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.tipsForBestResults,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...tips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.sage,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 124),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scanYourRoom,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.scanPremiumSubtitle,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showTips(context, l10n),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.help_outline_rounded, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _CameraHeroCard(
            label: l10n.bestResultsNaturalLight,
            onTap: () => _openCamera(context),
          ),
          const SizedBox(height: 24),
          _preferencesCard(l10n),
          const SizedBox(height: 24),
          _TakePhotoButton(l10n: l10n, onTap: () => _openCamera(context)),
          const SizedBox(height: 24),
          _HowItWorksCard(l10n: l10n),
          const SizedBox(height: 16),
          _TipsCard(l10n: l10n, onTap: () => _showTips(context, l10n)),
        ],
      ),
    );
  }

  Widget _preferencesCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.sage),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scanPreferencesTitle,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.scanPreferencesSubtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DimensionField(
                  controller: _wallLengthController,
                  label: l10n.scanRoomWidthLabel,
                  suffix: l10n.scanCentimetersSuffix,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionField(
                  controller: _roomDepthController,
                  label: l10n.scanRoomDepthLabel,
                  suffix: l10n.scanCentimetersSuffix,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionField(
                  controller: _ceilingHeightController,
                  label: l10n.scanCeilingHeightLabel,
                  suffix: l10n.scanCentimetersSuffix,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _designCount,
                  decoration: _inputDecoration(l10n.scanDesignCountLabel),
                  borderRadius: BorderRadius.circular(18),
                  items: const [1, 2, 3]
                      .map(
                        (count) => DropdownMenuItem<int>(
                          value: count,
                          child: Text('$count'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _designCount = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _replaceExistingFurniture,
                  activeTrackColor: AppColors.sage,
                  title: Text(
                    l10n.scanReplaceFurnitureLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _replaceExistingFurniture = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionLabel(l10n.scanFurnitureTypesLabel),
          _multiSelectChips(_furnitureChoices(l10n), _requestedFurnitureTypes),
          const SizedBox(height: 12),
          _sectionLabel(l10n.scanStyleLabel),
          _singleSelectChips(
            _styleChoices(l10n),
            _designStyle,
            (value) => setState(() => _designStyle = value),
          ),
          const SizedBox(height: 12),
          _sectionLabel(l10n.scanMaterialLabel),
          _singleSelectChips(
            _materialChoices(l10n),
            _material,
            (value) => setState(() => _material = value),
          ),
          const SizedBox(height: 12),
          _sectionLabel(l10n.scanColorsLabel),
          _multiSelectChips(_colorChoices(l10n), _colors),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(l10n.scanTemperatureLabel),
                    _singleSelectChips(
                      _temperatureChoices(l10n),
                      _temperature,
                      (value) => setState(() => _temperature = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(l10n.scanSizeLabel),
                    _singleSelectChips(
                      _sizeChoices(l10n),
                      _size,
                      (value) => setState(() => _size = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _extraPreferencesController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
              l10n.scanExtraPreferencesLabel,
            ).copyWith(hintText: l10n.scanExtraPreferencesHint),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _multiSelectChips(List<_ScanChoice> choices, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: choices.map((choice) {
        final isSelected = selected.contains(choice.value);
        return FilterChip(
          label: Text(choice.label),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                selected.add(choice.value);
              } else {
                selected.remove(choice.value);
              }
            });
          },
          selectedColor: AppColors.sage.withValues(alpha: 0.22),
          checkmarkColor: AppColors.sage,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          side: const BorderSide(color: AppColors.border),
        );
      }).toList(),
    );
  }

  Widget _singleSelectChips(
    List<_ScanChoice> choices,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: choices.map((choice) {
        final isSelected = selected == choice.value;
        return ChoiceChip(
          label: Text(choice.label),
          selected: isSelected,
          onSelected: (_) => onChanged(isSelected ? null : choice.value),
          selectedColor: AppColors.sage.withValues(alpha: 0.22),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          side: const BorderSide(color: AppColors.border),
        );
      }).toList(),
    );
  }

  List<_ScanChoice> _furnitureChoices(AppLocalizations l10n) => [
    _ScanChoice('sofa', l10n.scanFurnitureSofa),
    _ScanChoice('armchair', l10n.scanFurnitureArmchair),
    _ScanChoice('coffee_table', l10n.scanFurnitureCoffeeTable),
    _ScanChoice('carpet', l10n.scanFurnitureRug),
    _ScanChoice('tv_unit', l10n.scanFurnitureTvUnit),
    _ScanChoice('storage', l10n.scanFurnitureStorage),
    _ScanChoice('lighting', l10n.scanFurnitureLighting),
  ];

  List<_ScanChoice> _styleChoices(AppLocalizations l10n) => [
    _ScanChoice('modern', l10n.scanStyleModern),
    _ScanChoice('scandinavian', l10n.scanStyleScandinavian),
    _ScanChoice('minimalist', l10n.scanStyleMinimal),
    _ScanChoice('classic', l10n.scanStyleClassic),
  ];

  List<_ScanChoice> _materialChoices(AppLocalizations l10n) => [
    _ScanChoice('wood', l10n.scanMaterialWood),
    _ScanChoice('fabric', l10n.scanMaterialFabric),
    _ScanChoice('metal', l10n.scanMaterialMetal),
    _ScanChoice('glass', l10n.scanMaterialGlass),
  ];

  List<_ScanChoice> _colorChoices(AppLocalizations l10n) => [
    _ScanChoice('beige', l10n.scanColorBeige),
    _ScanChoice('oak', l10n.scanColorOak),
    _ScanChoice('white', l10n.scanColorWhite),
    _ScanChoice('gray', l10n.scanColorGray),
    _ScanChoice('green', l10n.scanColorGreen),
  ];

  List<_ScanChoice> _temperatureChoices(AppLocalizations l10n) => [
    _ScanChoice('warm', l10n.scanTemperatureWarm),
    _ScanChoice('neutral', l10n.scanTemperatureNeutral),
    _ScanChoice('cold', l10n.scanTemperatureCool),
  ];

  List<_ScanChoice> _sizeChoices(AppLocalizations l10n) => [
    _ScanChoice('small', l10n.scanSizeSmall),
    _ScanChoice('medium', l10n.scanSizeMedium),
    _ScanChoice('large', l10n.scanSizeLarge),
  ];
}

class _ScanChoice {
  const _ScanChoice(this.value, this.label);

  final String value;
  final String label;
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: AppColors.cream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _CameraHeroCard extends StatelessWidget {
  const _CameraHeroCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.13),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RemoteImage(
            url:
                'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=1200&q=80',
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surface.withValues(alpha: 0.08),
                  AppColors.ink.withValues(alpha: 0.18),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.36),
                      blurRadius: 30,
                      spreadRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.sage,
                  size: 50,
                ),
              ),
            ),
          ),
          Positioned(
            left: 54,
            right: 54,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wb_sunny_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakePhotoButton extends StatelessWidget {
  const _TakePhotoButton({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppColors.sage.withValues(alpha: 0.32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_rounded),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                l10n.takePhoto,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.auto_awesome_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StepItem(
              icon: Icons.camera_alt_rounded,
              title: l10n.takeAPhoto,
              description: l10n.scanPhotoDescription,
              backgroundColor: AppColors.sand.withValues(alpha: 0.70),
            ),
          ),
          const _StepArrow(),
          Expanded(
            child: _StepItem(
              icon: Icons.auto_awesome_rounded,
              title: l10n.aiAnalysis,
              description: l10n.scanAnalysisDescription,
              backgroundColor: AppColors.sage,
              iconColor: Colors.white,
            ),
          ),
          const _StepArrow(),
          Expanded(
            child: _StepItem(
              icon: Icons.chair_alt_rounded,
              title: l10n.getIdeas,
              description: l10n.scanIdeasDescription,
              backgroundColor: AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.backgroundColor,
    this.iconColor = AppColors.sage,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: backgroundColor,
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 48),
      child: Icon(Icons.arrow_forward_rounded, color: AppColors.sage, size: 18),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.sage,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tipsForBestResults,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.scanTipsBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
