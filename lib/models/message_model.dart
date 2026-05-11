import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> m, String id) => MessageModel(
        id: id,
        senderId: m['senderId'] ?? '',
        text: m['text'] ?? '',
        createdAt: (m['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class ChatModel {
  final String id;
  final String userId;
  final String clinicId;
  final String clinicName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastSenderId;

  ChatModel({
    required this.id,
    required this.userId,
    required this.clinicId,
    required this.clinicName,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastSenderId = '',
  });

  factory ChatModel.fromMap(Map<String, dynamic> m, String id) => ChatModel(
        id: id,
        userId: m['userId'] ?? '',
        clinicId: m['clinicId'] ?? '',
        clinicName: m['clinicName'] ?? '',
        lastMessage: m['lastMessage'] ?? '',
        lastMessageAt: (m['lastMessageAt'] as Timestamp).toDate(),
        lastSenderId: m['lastSenderId'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'clinicId': clinicId,
        'clinicName': clinicName,
        'lastMessage': lastMessage,
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'lastSenderId': lastSenderId,
      };
}
