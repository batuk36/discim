import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> m, String id) =>
      NotificationModel(
        id: id,
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        isRead: m['isRead'] ?? false,
        createdAt: (m['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
