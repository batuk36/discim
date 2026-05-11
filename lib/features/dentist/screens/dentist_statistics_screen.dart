import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class DentistStatisticsScreen extends StatelessWidget {
  const DentistStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistikler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clinics')
            .where('ownerId', isEqualTo: uid)
            .limit(1)
            .snapshots(),
        builder: (context, clinicSnap) {
          if (!clinicSnap.hasData || clinicSnap.data!.docs.isEmpty) {
            return const Center(child: Text('Klinik bulunamadı'));
          }
          final clinicId = clinicSnap.data!.docs.first.id;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('clinicId', isEqualTo: clinicId)
                .snapshots(),
            builder: (context, apSnap) {
              if (apSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = apSnap.data?.docs ?? [];
              final all = docs.map((d) => d.data() as Map<String, dynamic>).toList();

              final total     = all.length;
              final pending   = all.where((d) => d['status'] == 'pending').length;
              final confirmed = all.where((d) => d['status'] == 'confirmed').length;
              final cancelled = all.where((d) => d['status'] == 'cancelled').length;

              // Top treatments
              final treatmentCount = <String, int>{};
              for (final d in all) {
                final t = d['treatmentType'] as String? ?? '';
                if (t.isNotEmpty) treatmentCount[t] = (treatmentCount[t] ?? 0) + 1;
              }
              final topTreatments = treatmentCount.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              // Last 7 days
              final now = DateTime.now();
              final weekDays = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
              final dayCounts = weekDays.map((day) {
                return all.where((d) {
                  final date = (d['date'] as dynamic)?.toDate();
                  if (date == null) return false;
                  return date.year == day.year && date.month == day.month && date.day == day.day;
                }).length;
              }).toList();
              final maxDay = dayCounts.isEmpty ? 1 : dayCounts.reduce((a, b) => a > b ? a : b);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Genel özet kartları
                  const Text('Genel Özet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(label: 'Toplam', value: '$total', color: AppColors.primary, icon: Icons.calendar_month_rounded),
                      const SizedBox(width: 10),
                      _StatCard(label: 'Bekleyen', value: '$pending', color: Colors.orange, icon: Icons.hourglass_empty_rounded),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatCard(label: 'Onaylı', value: '$confirmed', color: AppColors.success, icon: Icons.check_circle_outline_rounded),
                      const SizedBox(width: 10),
                      _StatCard(label: 'İptal', value: '$cancelled', color: AppColors.error, icon: Icons.cancel_outlined),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Son 7 günlük grafik
                  const Text('Son 7 Gün', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 120,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (i) {
                              final count = dayCounts[i];
                              final ratio = maxDay == 0 ? 0.0 : count / maxDay;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (count > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    width: 28,
                                    height: count == 0 ? 4 : (ratio * 96).clamp(4, 96),
                                    decoration: BoxDecoration(
                                      color: count == 0 ? AppColors.border : AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: weekDays.map((d) {
                            const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                            return SizedBox(
                              width: 28,
                              child: Text(
                                days[d.weekday - 1],
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // En çok yapılan tedaviler
                  if (topTreatments.isNotEmpty) ...[
                    const Text('En Çok Yapılan Tedaviler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: topTreatments.take(5).toList().asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          final ratio = total == 0 ? 0.0 : e.value / total;
                          final colors = [AppColors.primary, Colors.orange, Colors.purple, AppColors.success, Colors.teal];
                          final color = colors[i % colors.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                                    Text('${e.value} randevu', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 6,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  if (total == 0)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.bar_chart_rounded, size: 56, color: AppColors.border),
                            SizedBox(height: 12),
                            Text('Henüz randevu yok', style: TextStyle(color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
                Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
