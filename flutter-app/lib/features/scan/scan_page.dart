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
  final _roomLengthController = TextEditingController();
  final _roomWidthController = TextEditingController();
  final _roomHeightController = TextEditingController();

  bool _preferencesExpanded = false;
  bool _replaceExistingFurniture = false;
  int _furnitureVisibleCount = 8;
  final Set<String> _requestedFurnitureTypes = <String>{};
  String? _designStyle;
  String? _material;
  String? _temperature;
  bool _colorSelected = false;
  double _hue = 34;
  double _saturation = 0.38;
  double _lightness = 0.78;

  @override
  void dispose() {
    _roomLengthController.dispose();
    _roomWidthController.dispose();
    _roomHeightController.dispose();
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
      currentWallLengthCm: _parseDimension(_roomLengthController.text),
      roomDepthCm: _parseDimension(_roomWidthController.text),
      ceilingHeightCm: _parseDimension(_roomHeightController.text),
      replaceExistingFurniture: _replaceExistingFurniture,
      requestedFurnitureTypes: _requestedFurnitureTypes.toList()..sort(),
      designStyle: _designStyle,
      material: _material,
      colors: _colorSelected ? <String>[_selectedColorName()] : const <String>[],
      temperature: _temperature,
      designCount: _hasCustomParameters ? 1 : 3,
    );
  }

  bool get _hasCustomParameters {
    return _roomLengthController.text.trim().isNotEmpty ||
        _roomWidthController.text.trim().isNotEmpty ||
        _roomHeightController.text.trim().isNotEmpty ||
        _replaceExistingFurniture ||
        _requestedFurnitureTypes.isNotEmpty ||
        _designStyle != null ||
        _material != null ||
        _temperature != null ||
        _colorSelected;
  }

  double? _parseDimension(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Color _selectedColor() {
    return HSLColor.fromAHSL(1, _hue, _saturation, _lightness).toColor();
  }

  String _selectedColorName() {
    if (_lightness > 0.88 && _saturation < 0.22) return 'white';
    if (_lightness < 0.18) return 'black';
    if (_saturation < 0.16) return 'gray';
    if (_hue < 18 || _hue >= 345) return 'red';
    if (_hue < 45) return _lightness > 0.72 ? 'beige' : 'brown';
    if (_hue < 70) return _lightness > 0.68 ? 'cream' : 'yellow';
    if (_hue < 165) return 'green';
    if (_hue < 255) return 'blue';
    if (_hue < 295) return 'purple';
    if (_hue < 345) return 'pink';
    return 'multicolor';
  }

  String _selectedColorLabel(AppLocalizations l10n) {
    final choices = _colorNameChoices(l10n);
    return choices[_selectedColorName()] ?? _selectedColorName();
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
    final designCount = _hasCustomParameters ? 1 : 3;
    return Container(
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
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() {
              _preferencesExpanded = !_preferencesExpanded;
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
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
                          _preferencesExpanded
                              ? l10n.scanPreferencesSubtitle
                              : l10n.scanPreferencesCollapsedSubtitle,
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    _preferencesExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _autoDesignCountRow(l10n, designCount),
                  const SizedBox(height: 16),
                  _sectionLabel(l10n.scanRoomDimensionsLabel),
                  Row(
                    children: [
                      Expanded(
                        child: _DimensionField(
                          controller: _roomLengthController,
                          label: l10n.scanRoomWidthLabel,
                          suffix: l10n.scanCentimetersSuffix,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DimensionField(
                          controller: _roomWidthController,
                          label: l10n.scanRoomDepthLabel,
                          suffix: l10n.scanCentimetersSuffix,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DimensionField(
                          controller: _roomHeightController,
                          label: l10n.scanCeilingHeightLabel,
                          suffix: l10n.scanCentimetersSuffix,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _replaceFurnitureRow(l10n),
                  const SizedBox(height: 14),
                  _furnitureChecklist(l10n),
                  const SizedBox(height: 14),
                  _sectionLabel(l10n.scanStyleLabel),
                  _singleSelectChips(
                    _styleChoices(l10n),
                    _designStyle,
                    (value) => setState(() => _designStyle = value),
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel(l10n.scanMaterialLabel),
                  _singleSelectChips(
                    _materialChoices(l10n),
                    _material,
                    (value) => setState(() => _material = value),
                  ),
                  const SizedBox(height: 14),
                  _colorSelector(l10n),
                  const SizedBox(height: 14),
                  _sectionLabel(l10n.scanTemperatureLabel),
                  _singleSelectChips(
                    _temperatureChoices(l10n),
                    _temperature,
                    (value) => setState(() => _temperature = value),
                  ),
                ],
              ),
            ),
            crossFadeState: _preferencesExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _autoDesignCountRow(AppLocalizations l10n, int designCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.clay),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.scanAutoDesignCount(designCount),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replaceFurnitureRow(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.scanReplaceFurnitureLabel,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch.adaptive(
            value: _replaceExistingFurniture,
            activeTrackColor: AppColors.sage,
            onChanged: (value) {
              setState(() => _replaceExistingFurniture = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _furnitureChecklist(AppLocalizations l10n) {
    final choices = _furnitureChoices(l10n);
    final visibleChoices = choices.take(_furnitureVisibleCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(l10n.scanFurnitureTypesLabel),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _furnitureVisibleCount.toDouble(),
                min: 4,
                max: choices.length.toDouble(),
                divisions: choices.length - 4,
                label: l10n.scanFurnitureVisibleCount(_furnitureVisibleCount),
                activeColor: AppColors.sage,
                onChanged: (value) {
                  setState(() => _furnitureVisibleCount = value.round());
                },
              ),
            ),
            SizedBox(
              width: 92,
              child: Text(
                l10n.scanFurnitureVisibleCount(_furnitureVisibleCount),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...visibleChoices.map((choice) {
          final selected = _requestedFurnitureTypes.contains(choice.value);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            value: selected,
            activeColor: AppColors.sage,
            title: Text(
              choice.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onChanged: (value) {
              setState(() {
                if (value ?? false) {
                  _requestedFurnitureTypes.add(choice.value);
                } else {
                  _requestedFurnitureTypes.remove(choice.value);
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _colorSelector(AppLocalizations l10n) {
    final color = _selectedColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(l10n.scanColorsLabel),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _colorSelected
                          ? l10n.scanSelectedColor(_selectedColorLabel(l10n))
                          : l10n.scanNoColorSelected,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _colorSelected = false),
                    child: Text(l10n.scanClearColor),
                  ),
                ],
              ),
              _colorSlider(
                label: l10n.scanHueLabel,
                value: _hue,
                min: 0,
                max: 360,
                onChanged: (value) => setState(() {
                  _hue = value;
                  _colorSelected = true;
                }),
              ),
              _colorSlider(
                label: l10n.scanSaturationLabel,
                value: _saturation,
                min: 0,
                max: 1,
                onChanged: (value) => setState(() {
                  _saturation = value;
                  _colorSelected = true;
                }),
              ),
              _colorSlider(
                label: l10n.scanLightnessLabel,
                value: _lightness,
                min: 0,
                max: 1,
                onChanged: (value) => setState(() {
                  _lightness = value;
                  _colorSelected = true;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _colorSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.sage,
            onChanged: onChanged,
          ),
        ),
      ],
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
    _ScanChoice('chair', l10n.scanFurnitureChair),
    _ScanChoice('dining_chair', l10n.scanFurnitureDiningChair),
    _ScanChoice('dining_table', l10n.scanFurnitureDiningTable),
    _ScanChoice('coffee_table', l10n.scanFurnitureCoffeeTable),
    _ScanChoice('side_table', l10n.scanFurnitureSideTable),
    _ScanChoice('console_table', l10n.scanFurnitureConsoleTable),
    _ScanChoice('tv_unit', l10n.scanFurnitureTvUnit),
    _ScanChoice('bed', l10n.scanFurnitureBed),
    _ScanChoice('wardrobe', l10n.scanFurnitureWardrobe),
    _ScanChoice('dresser', l10n.scanFurnitureDresser),
    _ScanChoice('nightstand', l10n.scanFurnitureNightstand),
    _ScanChoice('bookshelf', l10n.scanFurnitureBookshelf),
    _ScanChoice('desk', l10n.scanFurnitureDesk),
    _ScanChoice('office_chair', l10n.scanFurnitureOfficeChair),
    _ScanChoice('lamp', l10n.scanFurnitureLamp),
    _ScanChoice('floor_lamp', l10n.scanFurnitureFloorLamp),
    _ScanChoice('pendant_lamp', l10n.scanFurniturePendantLamp),
    _ScanChoice('rug', l10n.scanFurnitureRug),
    _ScanChoice('curtain', l10n.scanFurnitureCurtain),
    _ScanChoice('mirror', l10n.scanFurnitureMirror),
    _ScanChoice('wall_art', l10n.scanFurnitureWallArt),
    _ScanChoice('plant_pot', l10n.scanFurniturePlantPot),
    _ScanChoice('decoration', l10n.scanFurnitureDecoration),
    _ScanChoice('storage_unit', l10n.scanFurnitureStorage),
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

  List<_ScanChoice> _temperatureChoices(AppLocalizations l10n) => [
    _ScanChoice('warm', l10n.scanTemperatureWarm),
    _ScanChoice('neutral', l10n.scanTemperatureNeutral),
    _ScanChoice('cold', l10n.scanTemperatureCool),
  ];

  Map<String, String> _colorNameChoices(AppLocalizations l10n) => {
    'white': l10n.scanColorWhite,
    'black': l10n.scanColorBlack,
    'gray': l10n.scanColorGray,
    'beige': l10n.scanColorBeige,
    'cream': l10n.scanColorCream,
    'brown': l10n.scanColorBrown,
    'red': l10n.scanColorRed,
    'orange': l10n.scanColorOrange,
    'yellow': l10n.scanColorYellow,
    'green': l10n.scanColorGreen,
    'blue': l10n.scanColorBlue,
    'purple': l10n.scanColorPurple,
    'pink': l10n.scanColorPink,
    'multicolor': l10n.scanColorMulticolor,
  };
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
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
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
