import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/config/backend_config.dart';

/// Exception thrown when the backend returns an error.
class BackendException implements Exception {
  const BackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BackendException($statusCode): $message';
}

/// HTTP response from uploading a room image.
class UploadResult {
  const UploadResult({
    required this.imagePath,
    required this.width,
    required this.height,
  });

  final String imagePath;
  final int width;
  final int height;

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      imagePath: json['image_path'] as String? ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Parsed design job status from the backend.
class DesignJobResult {
  const DesignJobResult({
    required this.jobId,
    required this.status,
    this.currentStage,
    this.errorMessage,
    this.designs = const [],
  });

  final String jobId;
  final String status;
  final String? currentStage;
  final String? errorMessage;
  final List<Map<String, dynamic>> designs;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed' || status == 'cancelled';
  bool get isRunning => status == 'running' || status == 'queued';

  factory DesignJobResult.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map<String, dynamic>?;
    final rawDesigns = json['designs'] as List<dynamic>? ?? [];

    return DesignJobResult(
      jobId: json['job_id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      currentStage: progress?['current_stage'] as String?,
      errorMessage: json['error_message'] as String?,
      designs: rawDesigns
          .map((d) => d as Map<String, dynamic>)
          .toList(growable: false),
    );
  }
}

/// User-provided scan options sent to the AI backend.
class ScanDesignOptions {
  const ScanDesignOptions({
    this.currentWallLengthCm = 400,
    this.roomDepthCm = 350,
    this.ceilingHeightCm = 270,
    this.replaceExistingFurniture = false,
    this.requestedFurnitureTypes = const <String>[],
    this.designStyle,
    this.material,
    this.colors = const <String>[],
    this.temperature,
    this.size,
    this.extraPreferences,
    this.designCount = 2,
  });

  final double? currentWallLengthCm;
  final double? roomDepthCm;
  final double? ceilingHeightCm;
  final bool replaceExistingFurniture;
  final List<String> requestedFurnitureTypes;
  final String? designStyle;
  final String? material;
  final List<String> colors;
  final String? temperature;
  final String? size;
  final String? extraPreferences;
  final int designCount;

  Map<String, dynamic> get roomDimensions {
    return {
      'unit': 'cm',
      if (currentWallLengthCm != null)
        'current_wall_length_cm': currentWallLengthCm,
      if (roomDepthCm != null) 'room_depth_cm': roomDepthCm,
      if (ceilingHeightCm != null) 'ceiling_height_cm': ceilingHeightCm,
      'known_reference_objects': const <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> get preferences {
    final hasGuidance =
        replaceExistingFurniture ||
        requestedFurnitureTypes.isNotEmpty ||
        designStyle != null ||
        material != null ||
        colors.isNotEmpty ||
        temperature != null ||
        size != null ||
        (extraPreferences?.trim().isNotEmpty ?? false);

    return {
      'mode': hasGuidance ? 'guided_design' : 'auto_design',
      'replace_existing_furniture': replaceExistingFurniture,
      'requested_furniture_types': requestedFurnitureTypes,
      'replace_targets': const <String>[],
      if (designStyle != null) 'design_style': designStyle,
      if (material != null) 'material': material,
      'colors': colors,
      if (temperature != null) 'temperature': temperature,
      if (size != null) 'size': size,
      if (extraPreferences?.trim().isNotEmpty ?? false)
        'extra_preferences': extraPreferences!.trim(),
    };
  }
}

/// REST client for the ai-service backend.
class AiBackendClient {
  AiBackendClient({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  String get _baseUrl => BackendConfig.instance.baseUrl;

  /// Check if the backend is reachable.
  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload a room image to the backend.
  Future<UploadResult> uploadRoomImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/uploads/room-image');
    final request = http.MultipartRequest('POST', uri);

    final extension = imageFile.path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: mimeType,
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw BackendException(
        'Upload failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UploadResult.fromJson(json);
  }

  /// Create a design job.
  Future<String> createDesignJob({
    required String roomImagePath,
    ScanDesignOptions options = const ScanDesignOptions(),
  }) async {
    final uri = Uri.parse('$_baseUrl/design-jobs');
    final body = {
      'room_image_path': roomImagePath,
      'room_dimensions': options.roomDimensions,
      'preferences': options.preferences,
      'requested_design_count': options.designCount,
    };

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw BackendException(
        'Job creation failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['job_id'] as String;
  }

  /// Get the current status of a design job.
  Future<DesignJobResult> getDesignJob(String jobId) async {
    final uri = Uri.parse('$_baseUrl/design-jobs/$jobId');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      throw const BackendException('Design job not found', statusCode: 404);
    }
    if (response.statusCode != 200) {
      throw BackendException(
        'Failed to get job: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DesignJobResult.fromJson(json);
  }

  /// Poll a design job until it completes or fails.
  ///
  /// Calls [onProgress] with each poll result so the UI can update.
  /// Returns the final completed result.
  Future<DesignJobResult> pollDesignJob(
    String jobId, {
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 10),
    void Function(DesignJobResult)? onProgress,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await getDesignJob(jobId);
        onProgress?.call(result);

        if (result.isCompleted || result.isFailed) {
          return result;
        }
      } catch (e) {
        debugPrint('Poll error: $e');
      }

      await Future<void>.delayed(interval);
    }

    throw const BackendException('Job timed out');
  }

  /// Convert a backend-relative image path into a URL the Flutter app can load.
  String imageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return '';
    final parsed = Uri.tryParse(imagePath);
    if (parsed != null && parsed.hasScheme) return imagePath;

    final normalized = imagePath.startsWith('/')
        ? imagePath.substring(1)
        : imagePath;
    final base = Uri.parse(_baseUrl);
    final pathSegments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'images',
      ...normalized.split('/').where((segment) => segment.isNotEmpty),
    ];
    return base.replace(pathSegments: pathSegments).toString();
  }

  void dispose() {
    _client.close();
  }
}
