import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_notification.dart';
import '../../services/app_notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _filters = ['All', 'Unread', 'Offers', 'Updates'];
  late Future<List<AppNotification>> _notifications = AppNotificationService
      .instance
      .loadNotifications();
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background.withValues(alpha: 0.92),
        foregroundColor: AppColors.ink,
        titleTextStyle: Theme.of(context).textTheme.headlineMedium,
      ),
      body: SafeArea(
        child: FutureBuilder<List<AppNotification>>(
          future: _notifications,
          builder: (context, snapshot) {
            final notifications = (snapshot.data ?? const <AppNotification>[])
                .where((notification) {
                  if (_selectedFilter == 'All') return true;
                  if (_selectedFilter == 'Unread') return !notification.isRead;
                  return notification.type == _selectedFilter.toLowerCase();
                })
                .toList();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: notifications.isEmpty ? 2 : notifications.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _NotificationFilters(
                    l10n: l10n,
                    filters: _filters,
                    selectedFilter: _selectedFilter,
                    onChanged: (filter) =>
                        setState(() => _selectedFilter = filter),
                  );
                }

                if (notifications.isEmpty) {
                  return _EmptyNotificationsCard(
                    message: l10n.noNotificationsMessage,
                  );
                }

                final notification = notifications[index - 1];
                return _NotificationCard(
                  notification: notification,
                  title: _titleFor(l10n, notification),
                  description: _descriptionFor(l10n, notification),
                  timeLabel: _relativeTime(l10n, notification.createdAt),
                  onTap: () async {
                    await AppNotificationService.instance.markRead(
                      notification.id,
                    );
                    setState(() {
                      _notifications = AppNotificationService.instance
                          .loadNotifications();
                    });
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationFilters extends StatelessWidget {
  const _NotificationFilters({
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
            label: Text(_filterLabel(l10n, filter)),
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.onTap,
  });

  final AppNotification notification;
  final String title;
  final String description;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = notification.type == 'offers'
        ? AppColors.clay
        : AppColors.sage;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(
                alpha: notification.isRead ? 0.78 : 0.94,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: notification.isRead
                    ? AppColors.border
                    : iconColor.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    _iconFor(notification.titleKey),
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 16,
                                fontWeight: notification.isRead
                                    ? FontWeight.w700
                                    : FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ReadStateDot(isRead: notification.isRead),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: notification.isRead
                              ? AppColors.muted.withValues(alpha: 0.78)
                              : iconColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
}

class _EmptyNotificationsCard extends StatelessWidget {
  const _EmptyNotificationsCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.muted)),
    );
  }
}

class _ReadStateDot extends StatelessWidget {
  const _ReadStateDot({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: isRead ? AppColors.border : AppColors.violet,
        shape: BoxShape.circle,
      ),
    );
  }
}

String _filterLabel(AppLocalizations l10n, String filter) {
  switch (filter) {
    case 'All':
      return l10n.all;
    case 'Unread':
      return l10n.unread;
    case 'Offers':
      return l10n.offers;
    case 'Updates':
      return l10n.updates;
  }
  return filter;
}

String _titleFor(AppLocalizations l10n, AppNotification notification) {
  switch (notification.titleKey) {
    case 'addedToFavorites':
      return l10n.addedToFavorites;
    case 'removedFromFavorites':
      return l10n.removedFromFavorites;
    case 'welcomeToVisionSpace':
      return l10n.welcomeToVisionSpace;
    case 'newAiDesignReady':
      return l10n.newAiDesignReady;
    case 'designSaved':
      return l10n.designSaved;
    case 'profileUpdated':
      return l10n.profileUpdated;
  }
  return notification.titleKey;
}

String _descriptionFor(AppLocalizations l10n, AppNotification notification) {
  final itemName = notification.itemName ?? '';
  switch (notification.descriptionKey) {
    case 'favoriteAddedDescription':
      return l10n.favoriteAddedDescription(itemName);
    case 'favoriteRemovedDescription':
      return l10n.favoriteRemovedDescription(itemName);
    case 'welcomeNotificationDescription':
      return l10n.welcomeNotificationDescription;
    case 'newAiDesignReadyDescription':
      return l10n.newAiDesignReadyDescription;
    case 'designSavedDescription':
      return l10n.designSavedDescription;
    case 'profileUpdatedDescription':
      return l10n.profileUpdatedDescription;
  }
  return notification.descriptionKey;
}

IconData _iconFor(String titleKey) {
  switch (titleKey) {
    case 'addedToFavorites':
    case 'removedFromFavorites':
      return Icons.favorite_rounded;
    case 'welcomeToVisionSpace':
      return Icons.waving_hand_rounded;
    case 'newAiDesignReady':
      return Icons.auto_awesome_rounded;
    case 'designSaved':
      return Icons.bookmark_rounded;
    case 'profileUpdated':
      return Icons.person_rounded;
  }
  return Icons.notifications_rounded;
}

String _relativeTime(AppLocalizations l10n, DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
