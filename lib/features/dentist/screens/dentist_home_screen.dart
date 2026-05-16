import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/floating_bottom_nav.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/appointment_model.dart';
import '../../../models/clinic_model.dart';
import 'dentist_edit_profile_screen.dart';
import 'dentist_messages_screen.dart';
import 'dentist_notifications_screen.dart';
import 'dentist_statistics_screen.dart';

class DentistHomeScreen extends StatefulWidget {
  const DentistHomeScreen({super.key});

  @override
  State<DentistHomeScreen> createState() => _DentistHomeScreenState();
}

class _DentistHomeScreenState extends State<DentistHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clinics')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .snapshots(),
      builder: (context, clinicSnap) {
        final clinicDoc  = clinicSnap.data?.docs.firstOrNull;
        final clinicId   = clinicDoc?.id ?? '';
        final clinicData = clinicDoc?.data() as Map<String, dynamic>?;
        final clinicName      = clinicData?['name'] as String? ?? '';
        final dentistPhotoUrl = clinicData?['dentistPhotoUrl'] as String?;
        final isApproved      = clinicData?['isApproved'] as bool? ?? true;

        if (clinicSnap.connectionState != ConnectionState.waiting && clinicData != null && !isApproved) {
          return const _PendingApprovalScreen();
        }

        return StreamBuilder<QuerySnapshot>(
          stream: clinicId.isNotEmpty
              ? FirebaseFirestore.instance
                  .collection('chats')
                  .where('clinicId', isEqualTo: clinicId)
                  .snapshots()
              : const Stream.empty(),
          builder: (context, chatSnap) {
            final unread = chatSnap.data?.docs.where((d) {
              final data       = d.data() as Map<String, dynamic>;
              final lastSender = data['lastSenderId'] as String? ?? '';
              final lastMsg    = data['lastMessage']  as String? ?? '';
              final patientId  = data['userId']       as String? ?? '';
              return lastMsg.isNotEmpty && lastSender.isNotEmpty && lastSender == patientId;
            }).length ?? 0;

            return Scaffold(
              extendBody: true,
              body: IndexedStack(
                index: _currentIndex,
                children: [
                  _DentistDashboard(
                    onNavigate: (i) => setState(() => _currentIndex = i),
                    clinicName: clinicName,
                    clinicId: clinicId,
                    dentistPhotoUrl: dentistPhotoUrl,
                  ),
                  const _DentistAppointments(),
                  const DentistMessagesScreen(),
                  const _DentistProfile(),
                ],
              ),
              bottomNavigationBar: FloatingBottomNav(
                currentIndex: _currentIndex,
                badgeCounts: unread > 0 ? {2: unread} : {},
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            );
          },
        );
      },
    );
  }
}

class _DentistDashboard extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  final String clinicName;
  final String clinicId;
  final String? dentistPhotoUrl;
  const _DentistDashboard({required this.onNavigate, required this.clinicName, required this.clinicId, this.dentistPhotoUrl});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF005F6B), Color(0xFF00BCD4)],
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: (dentistPhotoUrl != null && dentistPhotoUrl!.isNotEmpty)
                          ? ClipOval(child: Image.network(dentistPhotoUrl!, fit: BoxFit.cover, width: 46, height: 46))
                          : const Icon(Icons.medical_services_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dişçi Paneli', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          Text(
                            clinicName.isNotEmpty ? clinicName : 'Klinik',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: clinicId.isNotEmpty
                          ? FirebaseFirestore.instance
                              .collection('clinics')
                              .doc(clinicId)
                              .collection('notifications')
                              .where('isRead', isEqualTo: false)
                              .snapshots()
                          : const Stream.empty(),
                      builder: (context, notifSnap) {
                        final count = notifSnap.data?.docs.length ?? 0;
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DentistNotificationsScreen(clinicId: clinicId),
                          )),
                          child: Container(
                            width: 40, height: 40,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                const Center(child: Icon(Icons.notifications_rounded, color: Colors.white, size: 20)),
                                if (count > 0)
                                  Positioned(
                                    top: 6, right: 6,
                                    child: Container(
                                      width: 14, height: 14,
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: Center(
                                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: () => context.read<AuthProvider>().signOut(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Bugünün Özeti', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                clinicId.isEmpty
                    ? const SizedBox()
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('appointments')
                            .where('clinicId', isEqualTo: clinicId)
                            .snapshots(),
                        builder: (context, apSnap) {
                          final all = apSnap.data?.docs ?? [];
                          final todayDocs = all.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final date = (data['date'] as Timestamp).toDate();
                            return date.year == today.year &&
                                   date.month == today.month &&
                                   date.day == today.day;
                          }).toList();
                          final pending   = todayDocs.where((d) => (d.data() as Map)['status'] == 'pending').length;
                          final confirmed = todayDocs.where((d) => (d.data() as Map)['status'] == 'confirmed').length;
                          return Row(
                            children: [
                              _StatCard(label: 'Bekleyen',  value: '$pending',            color: Colors.orange,      onTap: () => onNavigate(1)),
                              const SizedBox(width: 12),
                              _StatCard(label: 'Onaylı',    value: '$confirmed',           color: AppColors.success,  onTap: () => onNavigate(1)),
                              const SizedBox(width: 12),
                              _StatCard(label: 'Toplam',    value: '${todayDocs.length}',  color: Colors.white,       onTap: () => onNavigate(1)),
                            ],
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('Hızlı Erişim', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            delegate: SliverChildListDelegate([
              _QuickCard(icon: Icons.checklist_rounded, title: 'Randevular', color: Colors.orange, onTap: () => onNavigate(1)),
              _QuickCard(icon: Icons.store_outlined, title: 'Profilim', color: AppColors.primary, onTap: () => onNavigate(3)),
              _QuickCard(icon: Icons.chat_bubble_outline_rounded, title: 'Mesajlar', color: Colors.purple, onTap: () => onNavigate(2)),
              _QuickCard(
                icon: Icons.bar_chart_rounded,
                title: 'İstatistikler',
                color: AppColors.success,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DentistStatisticsScreen())),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color == Colors.white ? Colors.white : color, fontSize: 24, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _DentistAppointments extends StatefulWidget {
  const _DentistAppointments();
  @override
  State<_DentistAppointments> createState() => _DentistAppointmentsState();
}

class _DentistAppointmentsState extends State<_DentistAppointments> {
  bool _showCalendar = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Randevular'),
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.list_rounded : Icons.calendar_month_rounded),
            tooltip: _showCalendar ? 'Liste' : 'Takvim',
            onPressed: () => setState(() { _showCalendar = !_showCalendar; _selectedDay = null; }),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clinics').where('ownerId', isEqualTo: uid).limit(1).snapshots(),
        builder: (context, clinicSnap) {
          if (!clinicSnap.hasData || clinicSnap.data!.docs.isEmpty) {
            return const Center(child: Text('Klinik bulunamadı'));
          }
          final clinicId = clinicSnap.data!.docs.first.id;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('appointments').where('clinicId', isEqualTo: clinicId).snapshots(),
            builder: (context, apSnap) {
              if (apSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = apSnap.data?.docs ?? [];
              final appointments = docs
                  .map((d) => AppointmentModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .toList();

              if (_showCalendar) {
                return _CalendarView(
                  appointments: appointments,
                  month: _calendarMonth,
                  selectedDay: _selectedDay,
                  onMonthChanged: (m) => setState(() { _calendarMonth = m; _selectedDay = null; }),
                  onDaySelected: (d) => setState(() => _selectedDay = _selectedDay?.day == d.day && _selectedDay?.month == d.month ? null : d),
                );
              }

              if (appointments.isEmpty) return const Center(child: Text('Henüz randevu yok'));
              appointments.sort((a, b) => a.date.compareTo(b.date));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appointments.length,
                itemBuilder: (_, i) => _AppointmentCard(a: appointments[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel a;
  const _AppointmentCard({required this.a});

  @override
  Widget build(BuildContext context) {
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
                Expanded(child: Text(a.treatmentType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                _StatusChip(
                  status: a.status,
                  appointmentId: a.id,
                  userId: a.userId,
                  clinicName: a.clinicName,
                  treatmentType: a.treatmentType,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${a.date.day}.${a.date.month}.${a.date.year} - ${a.time}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(a.userId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox();
                final u = userSnap.data!.data() as Map<String, dynamic>;
                final name = u['name'] ?? '';
                final phone = u['phone'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(phone, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarView extends StatelessWidget {
  final List<AppointmentModel> appointments;
  final DateTime month;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  const _CalendarView({
    required this.appointments,
    required this.month,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  static const _monthNames = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  static const _dayNames = ['Pt','Sa','Ça','Pe','Cu','Ct','Pz'];

  List<AppointmentModel> _appsForDay(DateTime day) => appointments.where((a) =>
    a.date.year == day.year && a.date.month == day.month && a.date.day == day.day
  ).toList();

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;
    final today = DateTime.now();

    final dayApps = <int, List<AppointmentModel>>{};
    for (var d = 1; d <= lastDay.day; d++) {
      final date = DateTime(month.year, month.month, d);
      dayApps[d] = _appsForDay(date);
    }

    final selectedApps = selectedDay != null ? _appsForDay(selectedDay!) : <AppointmentModel>[];

    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => onMonthChanged(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => onMonthChanged(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
        ),
        // Day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _dayNames.map((d) => Expanded(
              child: Center(
                child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + lastDay.day,
            itemBuilder: (_, idx) {
              if (idx < startOffset) return const SizedBox();
              final day = idx - startOffset + 1;
              final date = DateTime(month.year, month.month, day);
              final apps = dayApps[day] ?? [];
              final isToday = date.day == today.day && date.month == today.month && date.year == today.year;
              final isSelected = selectedDay?.day == day && selectedDay?.month == month.month && selectedDay?.year == month.year;
              final hasPending = apps.any((a) => a.status == AppointmentStatus.pending);
              final hasConfirmed = apps.any((a) => a.status == AppointmentStatus.confirmed);

              return GestureDetector(
                onTap: apps.isNotEmpty ? () => onDaySelected(date) : null,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : isToday ? AppColors.primary.withValues(alpha: 0.1) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.normal,
                          color: isSelected ? Colors.white : isToday ? AppColors.primary : AppColors.textDark,
                        ),
                      ),
                      if (apps.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasPending) Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                            if (hasConfirmed) Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: isSelected ? Colors.white : AppColors.success, shape: BoxShape.circle)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 24),
        // Selected day appointments
        if (selectedDay != null)
          Expanded(
            child: selectedApps.isEmpty
                ? const Center(child: Text('Bu gün randevu yok', style: TextStyle(color: AppColors.textGrey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedApps.length,
                    itemBuilder: (_, i) => _AppointmentCard(a: selectedApps[i]),
                  ),
          )
        else
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 40, color: AppColors.border),
                  SizedBox(height: 8),
                  Text('Gün seçin', style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AppointmentStatus status;
  final String appointmentId;
  final String userId;
  final String clinicName;
  final String treatmentType;
  const _StatusChip({
    required this.status,
    required this.appointmentId,
    required this.userId,
    required this.clinicName,
    required this.treatmentType,
  });

  Future<void> _updateStatus(String newStatus) async {
    final db = FirebaseFirestore.instance;
    await db.collection('appointments').doc(appointmentId).update({'status': newStatus});
    final isConfirmed = newStatus == 'confirmed';
    await db.collection('users').doc(userId).collection('notifications').add({
      'title': isConfirmed ? 'Randevunuz onaylandı ✓' : 'Randevunuz iptal edildi',
      'body': isConfirmed
          ? '$clinicName kliniği $treatmentType randevunuzu onayladı.'
          : '$clinicName kliniği $treatmentType randevunuzu iptal etti.',
      'isRead': false,
      'createdAt': Timestamp.now(),
      'route': '/appointments',
    });
  }

  @override
  Widget build(BuildContext context) {
    if (status == AppointmentStatus.pending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
            onPressed: () => _updateStatus('confirmed'),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            onPressed: () => _updateStatus('cancelled'),
          ),
        ],
      );
    }
    final isConfirmed = status == AppointmentStatus.confirmed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isConfirmed ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isConfirmed ? 'Onaylandı' : 'İptal',
        style: TextStyle(color: isConfirmed ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _DentistProfile extends StatelessWidget {
  const _DentistProfile();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Klinik Profilim')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clinics').where('ownerId', isEqualTo: uid).limit(1).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('Klinik bilgisi bulunamadı'));
          }
          final doc = snap.data!.docs.first;
          final clinic = ClinicModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                  ),
                  child: (clinic.dentistPhotoUrl != null && clinic.dentistPhotoUrl!.isNotEmpty)
                      ? ClipOval(child: Image.network(clinic.dentistPhotoUrl!, fit: BoxFit.cover, width: 90, height: 90))
                      : const Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 36),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(clinic.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              Center(child: Text(clinic.address, style: const TextStyle(color: AppColors.textGrey))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DentistEditProfileScreen(clinicId: doc.id, clinic: clinic),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Profili Düzenle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _InfoTile(icon: Icons.phone_outlined, label: 'Telefon', value: clinic.phone),
              _InfoTile(icon: Icons.email_outlined, label: 'E-posta', value: clinic.email),
              _InfoTile(icon: Icons.info_outline, label: 'Hakkında', value: clinic.description),
              if (clinic.treatments.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Tedaviler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...clinic.treatments.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                      Text(t.priceRange, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                    ],
                  ),
                )),
              ],
              if (clinic.workingHours.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Çalışma Saatleri', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...clinic.workingHours.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 90, child: Text(_dayLabel(e.key), style: const TextStyle(color: AppColors.textGrey, fontSize: 13))),
                      Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.read<AuthProvider>().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  String _dayLabel(String key) {
    const map = {
      'monday': 'Pazartesi', 'tuesday': 'Salı', 'wednesday': 'Çarşamba',
      'thursday': 'Perşembe', 'friday': 'Cuma', 'saturday': 'Cumartesi', 'sunday': 'Pazar',
    };
    return map[key] ?? key;
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingApprovalScreen extends StatelessWidget {
  const _PendingApprovalScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF005F6B), Color(0xFF00BCD4)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Kliniğiniz İnceleniyor',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kayıt talebiniz alındı. Ekibimiz kliniğinizi inceleyecek ve en kısa sürede onaylayacaktır.',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Onaylandığında sisteme erişebileceksiniz.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<AuthProvider>().signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                    label: const Text('Çıkış Yap', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

