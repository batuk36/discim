import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clinic/screens/add_review_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid != null) _checkReviewReminders(uid);
  }

  Future<void> _checkReviewReminders(String uid) async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'confirmed')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['reviewNotified'] == true) continue;
      final date = (data['date'] as Timestamp).toDate();
      if (date.isBefore(now)) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
          'title': 'Randevunuzu değerlendirin ⭐',
          'body': '${data['clinicName']} kliniğindeki deneyiminizi paylaşın.',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
        await doc.reference.update({'reviewNotified': true});
      }
    }
  }

  Future<void> _cancelAppointment(BuildContext context, AppointmentModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Randevuyu İptal Et'),
        content: Text('${a.clinicName} kliniğindeki ${a.treatmentType} randevunuzu iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance.collection('appointments').doc(a.id).update({'status': 'cancelled'});
    await FirebaseFirestore.instance
        .collection('clinics')
        .doc(a.clinicId)
        .collection('notifications')
        .add({
      'title': 'Randevu iptal edildi',
      'body': '${a.treatmentType} randevusu hasta tarafından iptal edildi (${DateFormat('d MMM', 'tr').format(a.date)} ${a.time}).',
      'isRead': false,
      'createdAt': Timestamp.now(),
      'route': '/appointments',
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu iptal edildi.')),
      );
    }
  }

  Color _statusColor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.confirmed: return AppColors.success;
      case AppointmentStatus.cancelled: return AppColors.error;
      default: return Colors.orange;
    }
  }

  String _statusLabel(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.confirmed: return 'Onaylandı';
      case AppointmentStatus.cancelled: return 'İptal';
      default: return 'Bekliyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Randevularım')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Henüz randevunuz yok'));
          }
          docs = List.from(docs)..sort((a, b) {
            final da = (a.data() as Map)['date'] as Timestamp;
            final db = (b.data() as Map)['date'] as Timestamp;
            return db.compareTo(da);
          });
          return RefreshIndicator(
            onRefresh: () async {},
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final a = AppointmentModel.fromMap(
                    docs[i].data() as Map<String, dynamic>, docs[i].id);
                final isPast = a.date.isBefore(now);
                final canReview = isPast && a.status == AppointmentStatus.confirmed;
                final canCancel = !isPast && a.status != AppointmentStatus.cancelled;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(a.clinicName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(a.status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(a.status),
                                style: TextStyle(
                                    color: _statusColor(a.status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textGrey),
                            const SizedBox(width: 4),
                            Text(
                              '${DateFormat('d MMMM yyyy', 'tr').format(a.date)} - ${a.time}',
                              style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.medical_services_outlined, size: 14, color: AppColors.textGrey),
                            const SizedBox(width: 4),
                            Text(a.treatmentType,
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                          ],
                        ),
                        if (canCancel || canReview) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (canReview)
                                TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddReviewScreen(
                                        clinicId: a.clinicId,
                                        clinicName: a.clinicName,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.star_outline_rounded, size: 16),
                                  label: const Text('Yorum Yap'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.amber.shade700,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                ),
                              if (canCancel)
                                TextButton.icon(
                                  onPressed: () => _cancelAppointment(context, a),
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text('İptal Et'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
