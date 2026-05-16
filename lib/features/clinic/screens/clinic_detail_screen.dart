import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/clinic_model.dart';
import '../../../models/message_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../messages/screens/chat_screen.dart';
import 'add_review_screen.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/utils/time_utils.dart';

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _PhotoViewerScreen({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.photos[i],
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

class ClinicDetailScreen extends StatefulWidget {
  final String clinicId;
  const ClinicDetailScreen({super.key, required this.clinicId});

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  final _photoPageCtrl = PageController();
  int _photoIndex = 0;
  double _dragStartX = 0;
  late Future<DocumentSnapshot> _clinicFuture;

  @override
  void initState() {
    super.initState();
    _clinicFuture = FirebaseFirestore.instance.collection('clinics').doc(widget.clinicId).get();
  }

  @override
  void dispose() {
    _photoPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAndReview(BuildContext context, String clinicName) async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;

    final apSnap = await db.collection('appointments')
        .where('userId', isEqualTo: uid)
        .where('clinicId', isEqualTo: widget.clinicId)
        .where('status', isEqualTo: 'confirmed')
        .limit(1)
        .get();
    if (!context.mounted) return;
    if (apSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum yapabilmek için onaylı randevunuz olması gerekiyor.')),
      );
      return;
    }

    final reviewSnap = await db.collection('clinics').doc(widget.clinicId)
        .collection('reviews')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (!context.mounted) return;
    if (reviewSnap.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu klinik için zaten yorum yaptınız.')),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddReviewScreen(clinicId: widget.clinicId, clinicName: clinicName),
    ));
  }

  void _openPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PhotoViewerScreen(photos: photos, initialIndex: initialIndex),
    ));
  }

  Future<void> _startChat(BuildContext context, String clinicId) async {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    final db = FirebaseFirestore.instance;

    final existing = await db.collection('chats')
        .where('userId', isEqualTo: uid)
        .where('clinicId', isEqualTo: clinicId)
        .limit(1)
        .get();

    String chatId;
    String clinicName = '';

    final clinicDoc = await db.collection('clinics').doc(clinicId).get();
    clinicName = (clinicDoc.data() as Map<String, dynamic>)['name'] ?? '';

    if (existing.docs.isNotEmpty) {
      chatId = existing.docs.first.id;
    } else {
      final chat = ChatModel(
        id: '',
        userId: uid,
        clinicId: clinicId,
        clinicName: clinicName,
        lastMessage: '',
        lastMessageAt: DateTime.now(),
      );
      final ref = await db.collection('chats').add(chat.toMap());
      chatId = ref.id;
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, clinicName: clinicName),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: _clinicFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Klinik bulunamadı'));
          }
          final clinic = ClinicModel.fromMap(
              snap.data!.data() as Map<String, dynamic>, widget.clinicId);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    onPressed: () {
                      final parts = <String>[
                        '🦷 ${clinic.name}',
                        if (clinic.address.isNotEmpty) '📍 ${clinic.address}',
                        if (clinic.phone.isNotEmpty) '📞 ${clinic.phone}',
                        if (clinic.rating > 0) '⭐ ${clinic.rating.toStringAsFixed(1)} (${clinic.reviewCount} yorum)',
                        if (clinic.lat != 0 && clinic.lng != 0)
                          '🗺️ https://maps.google.com/?q=${clinic.lat},${clinic.lng}',
                        '\nDişçim uygulamasından paylaşıldı.',
                      ];
                      Share.share(parts.join('\n'));
                    },
                  ),
                  FavoriteButton(clinicId: widget.clinicId, light: true),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(clinic.name),
                  background: clinic.photos.isEmpty
                      ? Container(color: AppColors.primary.withValues(alpha: 0.2))
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _photoPageCtrl,
                              itemCount: clinic.photos.length,
                              onPageChanged: (i) => setState(() => _photoIndex = i),
                              itemBuilder: (_, i) => GestureDetector(
                                onTap: () => _openPhotoViewer(context, clinic.photos, i),
                                child: CachedNetworkImage(
                                  imageUrl: clinic.photos[i],
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: AppColors.primary.withValues(alpha: 0.1)),
                                  errorWidget: (_, __, ___) => Container(color: AppColors.primary.withValues(alpha: 0.1)),
                                ),
                              ),
                            ),
                            if (clinic.photos.length > 1) ...[
                              Positioned(
                                bottom: 48,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(clinic.photos.length, (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _photoIndex == i ? 16 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _photoIndex == i ? Colors.white : Colors.white54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  )),
                                ),
                              ),
                              Positioned(
                                left: 8, top: 0, bottom: 52,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () => _photoPageCtrl.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    ),
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8, top: 0, bottom: 52,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () => _photoPageCtrl.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    ),
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                      child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text('${clinic.rating.toStringAsFixed(1)} (${clinic.reviewCount} yorum)'),
                          const Spacer(),
                          if (clinic.isVerified)
                            Row(
                              children: const [
                                Icon(Icons.verified, color: AppColors.primary, size: 16),
                                SizedBox(width: 4),
                                Text('Onaylı Klinik',
                                    style: TextStyle(color: AppColors.primary, fontSize: 12)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final Uri uri;
                          if (clinic.lat != 0 && clinic.lng != 0) {
                            uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${clinic.lat},${clinic.lng}');
                          } else {
                            uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(clinic.address)}');
                          }
                          if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                clinic.address,
                                style: const TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                              ),
                            ),
                            const Icon(Icons.directions_rounded, color: AppColors.primary, size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri(scheme: 'tel', path: clinic.phone);
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.phone_outlined, color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(clinic.phone, style: const TextStyle(color: AppColors.primary, decoration: TextDecoration.underline)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Hakkında',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(clinic.description),
                      const SizedBox(height: 20),
                      const Text('Tedaviler',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...clinic.treatments.map((t) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.name),
                            trailing: Text(t.priceRange,
                                style: const TextStyle(color: AppColors.primary)),
                            dense: true,
                          )),
                      if (clinic.workingHours.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('Çalışma Saatleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            Builder(builder: (_) {
                              final open = isClinicOpenNow(clinic.workingHours);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: open ? const Color(0xFF4CAF50).withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7, height: 7,
                                      decoration: BoxDecoration(
                                        color: open ? const Color(0xFF4CAF50) : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      open ? 'Şimdi Açık' : 'Şu An Kapalı',
                                      style: TextStyle(
                                        color: open ? const Color(0xFF4CAF50) : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...clinic.workingHours.entries.map((e) {
                          const dayMap = {
                            'monday': 'Pazartesi', 'tuesday': 'Salı', 'wednesday': 'Çarşamba',
                            'thursday': 'Perşembe', 'friday': 'Cuma', 'saturday': 'Cumartesi', 'sunday': 'Pazar',
                          };
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                SizedBox(width: 90, child: Text(dayMap[e.key] ?? e.key, style: const TextStyle(color: AppColors.textGrey, fontSize: 13))),
                                Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Yorumlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          TextButton(
                            onPressed: () => _checkAndReview(context, clinic.name),
                            child: const Text('Yorum Yap', style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('clinics')
                            .doc(widget.clinicId)
                            .collection('reviews')
                            .orderBy('createdAt', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, snap) {
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) return const Text('Henüz yorum yok', style: TextStyle(color: AppColors.textGrey));
                          return Column(
                            children: docs.map((d) {
                              final r = d.data() as Map<String, dynamic>;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(r['userName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        const Spacer(),
                                        ...List.generate(5, (i) => Icon(
                                          i < (r['rating'] ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                                          color: Colors.amber, size: 14,
                                        )),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(r['comment'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _startChat(context, widget.clinicId),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Mesaj'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => context.push('/appointment/${widget.clinicId}'),
                child: const Text('Randevu Al'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
