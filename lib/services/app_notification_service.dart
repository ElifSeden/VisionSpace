import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  static const _storageKey = 'app_notifications';

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<List<AppNotification>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_storageKey) ?? const <String>[];
    final notifications = rawItems.map((raw) {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return AppNotification.fromJson(json);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    unreadCount.value = notifications.where((item) => !item.isRead).length;
    return notifications;
  }

  Future<void> addFavoriteAdded(String itemName) {
    return _add(
      titleKey: 'addedToFavorites',
      descriptionKey: 'favoriteAddedDescription',
      type: 'updates',
      itemName: itemName,
    );
  }

  Future<void> addFavoriteRemoved(String itemName) {
    return _add(
      titleKey: 'removedFromFavorites',
      descriptionKey: 'favoriteRemovedDescription',
      type: 'updates',
      itemName: itemName,
    );
  }

  Future<void> addWelcome() {
    return _add(
      titleKey: 'welcomeToVisionSpace',
      descriptionKey: 'welcomeNotificationDescription',
      type: 'updates',
    );
  }

  Future<void> addAiDesignReady() {
    return _add(
      titleKey: 'newAiDesignReady',
      descriptionKey: 'newAiDesignReadyDescription',
      type: 'updates',
    );
  }

  Future<void> addDesignSaved() {
    return _add(
      titleKey: 'designSaved',
      descriptionKey: 'designSavedDescription',
      type: 'updates',
    );
  }

  Future<void> addProfileUpdated() {
    return _add(
      titleKey: 'profileUpdated',
      descriptionKey: 'profileUpdatedDescription',
      type: 'updates',
    );
  }

  Future<void> markRead(String id) async {
    final notifications = await loadNotifications();
    final updated = notifications.map((notification) {
      if (notification.id != id) return notification;
      return notification.copyWith(isRead: true);
    }).toList();
    await _save(updated);
  }

  Future<void> _add({
    required String titleKey,
    required String descriptionKey,
    required String type,
    String? itemName,
  }) async {
    final notifications = await loadNotifications();
    notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        titleKey: titleKey,
        descriptionKey: descriptionKey,
        type: type,
        createdAt: DateTime.now(),
        isRead: false,
        itemName: itemName,
      ),
    );
    await _save(notifications.take(50).toList());
  }

  Future<void> _save(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      notifications.map((item) => jsonEncode(item.toJson())).toList(),
    );
    unreadCount.value = notifications.where((item) => !item.isRead).length;
  }
}
