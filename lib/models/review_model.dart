import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String clinicId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.clinicId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> m, String id) => ReviewModel(
        id: id,
        userId: m['userId'] ?? '',
        userName: m['userName'] ?? '',
        clinicId: m['clinicId'] ?? '',
        rating: (m['rating'] ?? 0).toDouble(),
        comment: m['comment'] ?? '',
        createdAt: (m['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'clinicId': clinicId,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
