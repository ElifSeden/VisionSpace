import 'package:flutter/material.dart';

import '../features/design/design_detail_page.dart';
import '../services/generated_designs_repository.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> openGeneratedDesignFromNotification(String designId) async {
  final trimmedDesignId = designId.trim();
  if (trimmedDesignId.isEmpty) return;

  final navigator = appNavigatorKey.currentState;
  if (navigator == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openGeneratedDesignFromNotification(trimmedDesignId);
    });
    return;
  }

  final project = await GeneratedDesignsRepository().fetchGeneratedDesign(
    trimmedDesignId,
  );
  if (project == null) return;

  navigator.push(
    MaterialPageRoute(builder: (_) => DesignDetailPage(project: project)),
  );
}
