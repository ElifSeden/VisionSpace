import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_notification_service.dart';
import '../../services/decorator_ai_api.dart';
import '../design/design_detail_page.dart';

enum _CameraErrorKind {
  notFound,
  couldNotStart,
  permissionDenied,
  couldNotOpen,
}

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({super.key});

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> {
  final DecoratorAiApi _api = FirestoreDecoratorAiApi();
  CameraController? _controller;
  Future<void>? _initializeCamera;
  _CameraErrorKind? _errorKind;
  String? _errorDetails;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera = _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorKind = _CameraErrorKind.notFound;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } on CameraException catch (error) {
      setState(() {
        if (error.code == 'CameraAccessDenied' ||
            error.code == 'CameraAccessDeniedWithoutPrompt') {
          _errorKind = _CameraErrorKind.permissionDenied;
          _errorDetails = null;
        } else {
          _errorKind = _CameraErrorKind.couldNotOpen;
          _errorDetails = error.description ?? error.code;
        }
      });
    } catch (_) {
      setState(() {
        _errorKind = _CameraErrorKind.couldNotStart;
      });
    }
  }

  Future<void> _captureAndAnalyze() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isAnalyzing) {
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final scan = await controller.takePicture();
      final project = await _api.analyzeSpace(scanId: scan.path);
      await AppNotificationService.instance.addAiDesignReady();

      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DesignDetailPage(project: project)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cameraCaptureFailed),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _CameraHeader(
                  title: l10n.cameraScanTitle,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: FutureBuilder<void>(
                        future: _initializeCamera,
                        builder: (context, snapshot) {
                          if (_errorKind != null) {
                            return _CameraError(
                              message: _cameraErrorText(l10n),
                            );
                          }

                          final controller = _controller;
                          if (snapshot.connectionState !=
                                  ConnectionState.done ||
                              controller == null ||
                              !controller.value.isInitialized) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          }

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(controller),
                              _ScanOverlay(hint: l10n.cameraOverlayHint),
                              if (_isAnalyzing)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.48),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          l10n.cameraAnalyzing,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.cameraCaptureHint,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: _captureAndAnalyze,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white54, width: 5),
                          ),
                          child: Icon(
                            _isAnalyzing
                                ? Icons.hourglass_top_rounded
                                : Icons.camera_alt_rounded,
                            color: AppColors.ink,
                            size: 30,
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
      ),
    );
  }

  String _cameraErrorText(AppLocalizations l10n) {
    return switch (_errorKind) {
      _CameraErrorKind.notFound => l10n.cameraNotFound,
      _CameraErrorKind.couldNotStart => l10n.cameraCouldNotStart,
      _CameraErrorKind.permissionDenied => l10n.cameraPermissionDenied,
      _CameraErrorKind.couldNotOpen => l10n.cameraCouldNotOpen(
        _errorDetails ?? '',
      ),
      null => '',
    };
  }
}

class _CameraHeader extends StatelessWidget {
  const _CameraHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 270,
            height: 360,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        Positioned(
          left: 26,
          right: 26,
          bottom: 28,
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.all(26),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
