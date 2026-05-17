class AppNotification {
  const AppNotification({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.itemName,
  });

  final String id;
  final String titleKey;
  final String descriptionKey;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String? itemName;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      itemName: itemName,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'titleKey': titleKey,
      'descriptionKey': descriptionKey,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'itemName': itemName,
    };
  }

  static AppNotification fromJson(Map<String, Object?> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      titleKey: json['titleKey'] as String? ?? '',
      descriptionKey: json['descriptionKey'] as String? ?? '',
      type: json['type'] as String? ?? 'updates',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      itemName: json['itemName'] as String?,
    );
  }
}
