import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_backend_client.dart';
import '../../services/app_notification_service.dart';
import '../../services/decorator_ai_api.dart';
import '../../services/notification_service.dart';
import '../design/design_detail_page.dart';

/// Processing page shown after camera capture.
///
/// Uploads the image, creates a design job, and polls until completion.
/// Shows animated progress with the current AI stage.
class ScanProcessingPage extends StatefulWidget {
  const ScanProcessingPage({
    required this.imagePath,
    this.options = const ScanDesignOptions(),
    super.key,
  });

  final String imagePath;
  final ScanDesignOptions options;

  @override
  State<ScanProcessingPage> createState() => _ScanProcessingPageState();
}

class _ScanProcessingPageState extends State<ScanProcessingPage>
    with SingleTickerProviderStateMixin {
  final DecoratorAiApi _api = BackendDecoratorAiApi();

  late final AnimationController _pulseController;
  String _currentStageKey = 'scanStageAnalyzing';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  bool _hasStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _startProcessing();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startProcessing() async {
    final l10n = AppLocalizations.of(context)!;
    final notificationText = _NotificationText(
      title: l10n.notificationDesignReady,
      body: l10n.notificationDesignReadyBody,
      channelName: l10n.notificationDesignChannelName,
      channelDescription: l10n.notificationDesignChannelDescription,
    );

    try {
      final project = await _api.submitAndPollScan(
        imageFile: File(widget.imagePath),
        options: widget.options,
        onProgress: _onProgress,
      );

      await AppNotificationService.instance.addAiDesignReady(
        designId: project.id,
      );
      await _showLocalNotification(notificationText, designId: project.id);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DesignDetailPage(project: project)),
      );
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _onProgress(DesignJobResult result) {
    if (!mounted) return;

    final stageKey = switch (result.currentStage) {
      'validate_input' => 'scanStageAnalyzing',
      'analyze_room' => 'scanStageAnalyzing',
      'create_design_strategies' => 'scanStageDesigning',
      'retrieve_candidates' => 'scanStageSearching',
      'rerank_products' => 'scanStageSearching',
      'plan_placements' => 'scanStagePlanning',
      'generate_images' => 'scanStageCompleting',
      'validate_result' => 'scanStageCompleting',
      'persist_result' => 'scanStageCompleting',
      _ => _currentStageKey,
    };

    setState(() => _currentStageKey = stageKey);
  }

  Future<void> _showLocalNotification(
    _NotificationText text, {
    required String designId,
  }) async {
    final service = NotificationService.instance;
    final enabled = await service.isLocalNotificationsEnabled;
    if (!enabled) return;

    final plugin = service.localNotificationsPlugin;
    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: text.title,
      body: text.body,
      payload: designId.trim().isEmpty ? null : 'generated_design:$designId',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'ai_updates',
          text.channelName,
          channelDescription: text.channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  String _stageText(AppLocalizations l10n) {
    return switch (_currentStageKey) {
      'scanStageAnalyzing' => l10n.scanStageAnalyzing,
      'scanStageDesigning' => l10n.scanStageDesigning,
      'scanStageSearching' => l10n.scanStageSearching,
      'scanStagePlanning' => l10n.scanStagePlanning,
      'scanStageCompleting' => l10n.scanStageCompleting,
      _ => l10n.scanStageAnalyzing,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: the captured room image, blurred
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Opacity(
              opacity: 0.35,
              child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _hasError
                      ? _ErrorContent(
                          message: _errorMessage ?? l10n.scanFailed,
                          retryLabel: l10n.scanStageRetry,
                          onRetry: () {
                            setState(() {
                              _hasError = false;
                              _errorMessage = null;
                              _currentStageKey = 'scanStageAnalyzing';
                            });
                            _startProcessing();
                          },
                        )
                      : _ProcessingContent(
                          pulseAnimation: _pulseController,
                          title: l10n.scanProcessingTitle,
                          stageText: _stageText(l10n),
                        ),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              color: Colors.white,
              iconSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationText {
  const _NotificationText({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String body;
  final String channelName;
  final String channelDescription;
}

class _ProcessingContent extends StatelessWidget {
  const _ProcessingContent({
    required this.pulseAnimation,
    required this.title,
    required this.stageText,
  });

  final AnimationController pulseAnimation;
  final String title;
  final String stageText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated pulse ring
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            final scale = 1.0 + pulseAnimation.value * 0.15;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sage.withValues(alpha: 0.25),
                  border: Border.all(
                    color: AppColors.sage.withValues(
                      alpha: 0.4 + pulseAnimation.value * 0.4,
                    ),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),

        // Title
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),

        // Stage text with animated dots
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            stageText,
            key: ValueKey(stageText),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Linear progress
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              backgroundColor: Color(0x33FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.sage),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.heart.withValues(alpha: 0.20),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.heart,
            size: 40,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              retryLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sage,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
