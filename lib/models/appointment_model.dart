import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { pending, confirmed, cancelled }

class AppointmentModel {
  final String id;
  final String userId;
  final String clinicId;
  final String clinicName;
  final DateTime date;
  final String time;
  final String treatmentType;
  final AppointmentStatus status;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.clinicId,
    required this.clinicName,
    required this.date,
    required this.time,
    required this.treatmentType,
    required this.status,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> m, String id) =>
      AppointmentModel(
        id: id,
        userId: m['userId'] ?? '',
        clinicId: m['clinicId'] ?? '',
        clinicName: m['clinicName'] ?? '',
        date: (m['date'] as Timestamp).toDate(),
        time: m['time'] ?? '',
        treatmentType: m['treatmentType'] ?? '',
        status: AppointmentStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => AppointmentStatus.pending,
        ),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'clinicId': clinicId,
        'clinicName': clinicName,
        'date': Timestamp.fromDate(date),
        'time': time,
        'treatmentType': treatmentType,
        'status': status.name,
      };
}
