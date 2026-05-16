import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/clinic_model.dart';
import '../../auth/providers/auth_provider.dart';

class AppointmentScreen extends StatefulWidget {
  final String clinicId;
  const AppointmentScreen({super.key, required this.clinicId});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  String? _selectedTreatment;
  bool _loading = false;
  late Future<DocumentSnapshot> _clinicFuture;
  List<String> _takenTimes = [];

  @override
  void initState() {
    super.initState();
    _clinicFuture = FirebaseFirestore.instance.collection('clinics').doc(widget.clinicId).get();
    _fetchTakenTimes();
  }

  Future<void> _fetchTakenTimes() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('clinicId', isEqualTo: widget.clinicId)
        .get();
    final taken = snap.docs
        .map((d) => d.data())
        .where((d) {
          if (d['status'] == 'cancelled') return false;
          final date = (d['date'] as Timestamp).toDate();
          return DateFormat('yyyy-MM-dd').format(date) == dateStr;
        })
        .map((d) => d['time'] as String)
        .toList();
    if (mounted) setState(() => _takenTimes = taken);
  }

  static const _engDayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  static const _trDayKeys  = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  List<String> _timeSlotsFor(DateTime date, ClinicModel clinic) {
    final idx = date.weekday - 1; // 0=Mon ... 6=Sun
    var raw = clinic.workingHours[_engDayKeys[idx]] ??
              clinic.workingHours[_trDayKeys[idx]] ?? '';
    if (raw == 'Kapalı') return [];
    if (raw.isEmpty) raw = '09:00 - 18:00'; // workingHours tanımlanmamışsa varsayılan
    final parts = raw.split(' - ');
    if (parts.length != 2) return [];

    int h(String s) => int.tryParse(s.trim().split(':').first) ?? 0;
    int m(String s) => int.tryParse(s.trim().split(':').last)  ?? 0;

    final openMins  = h(parts[0]) * 60 + m(parts[0]);
    final closeMins = h(parts[1]) * 60 + m(parts[1]);

    final slots = <String>[];
    var t = openMins;
    while (t + 30 <= closeMins) {
      slots.add('${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}');
      t += 30;
    }
    return slots;
  }

  Future<void> _confirm(ClinicModel clinic) async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen saat seçin')));
      return;
    }
    final conn = await Connectivity().checkConnectivity();
    if (conn.every((r) => r == ConnectivityResult.none)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İnternet bağlantınız yok')));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final appointment = AppointmentModel(
      id: '',
      userId: auth.firebaseUser!.uid,
      clinicId: widget.clinicId,
      clinicName: clinic.name,
      date: _selectedDate,
      time: _selectedTime!,
      treatmentType: _selectedTreatment ?? 'Genel Muayene',
      status: AppointmentStatus.pending,
    );
    await FirebaseFirestore.instance
        .collection('appointments')
        .add(appointment.toMap());

    await FirebaseFirestore.instance
        .collection('clinics')
        .doc(widget.clinicId)
        .collection('notifications')
        .add({
      'title': 'Yeni randevu talebi',
      'body': '${auth.userModel?.name ?? 'Hasta'} ${DateFormat('d MMM', 'tr').format(_selectedDate)} ${_selectedTime!} için randevu talep etti.',
      'isRead': false,
      'createdAt': Timestamp.now(),
      'route': '/appointments',
    });

    await NotificationService.showLocalNotification(
      title: 'Randevu talebiniz alındı ✓',
      body: '${clinic.name} kliniğine ${DateFormat('d MMM', 'tr').format(_selectedDate)} ${_selectedTime!} randevusu oluşturuldu.',
    );

    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Randevu talebiniz gönderildi!')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Randevu Al')),
      body: FutureBuilder<DocumentSnapshot>(
        future: _clinicFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clinic = ClinicModel.fromMap(
              snap.data!.data() as Map<String, dynamic>, widget.clinicId);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clinic.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text('Tarih Seç',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 14,
                    itemBuilder: (_, i) {
                      final date =
                          DateTime.now().add(Duration(days: i + 1));
                      final selected = DateFormat('yyyy-MM-dd')
                              .format(date) ==
                          DateFormat('yyyy-MM-dd').format(_selectedDate);
                      return GestureDetector(
                        onTap: () {
                          setState(() { _selectedDate = date; _selectedTime = null; });
                          _fetchTakenTimes();
                        },
                        child: Container(
                          width: 56,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('MMM', 'tr').format(date),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textGrey),
                              ),
                              Text(
                                DateFormat('d').format(date),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textDark),
                              ),
                              Text(
                                DateFormat('E', 'tr').format(date),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Saat Seç',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final slots = _timeSlotsFor(_selectedDate, clinic);
                  if (slots.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.block_rounded, color: AppColors.textGrey, size: 18),
                          SizedBox(width: 8),
                          Text('Bu gün klinik kapalı', style: TextStyle(color: AppColors.textGrey)),
                        ],
                      ),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slots.map((t) {
                      final selected = t == _selectedTime;
                      final taken = _takenTimes.contains(t);
                      return ChoiceChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: taken ? null : (_) => setState(() => _selectedTime = t),
                        selectedColor: AppColors.primary,
                        disabledColor: AppColors.border,
                        labelStyle: TextStyle(
                          color: taken ? AppColors.textGrey : selected ? Colors.white : AppColors.textDark,
                          decoration: taken ? TextDecoration.lineThrough : null,
                        ),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 20),
                const Text('Tedavi Seç',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                clinic.treatments.isEmpty
                    ? const Text('Bu klinik henüz tedavi eklememiş.',
                        style: TextStyle(color: AppColors.textGrey))
                    : DropdownButtonFormField<String>(
                        value: _selectedTreatment,
                        decoration: const InputDecoration(hintText: 'Tedavi türü seçin'),
                        items: clinic.treatments
                            .map((t) => DropdownMenuItem(value: t.name, child: Text(t.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedTreatment = v),
                      ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : () => _confirm(clinic),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Randevuyu Onayla'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
