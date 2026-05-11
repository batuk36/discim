import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/notification_model.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          TextButton(
            onPressed: () async {
              final snap = await col.where('isRead', isEqualTo: false).get();
              final batch = FirebaseFirestore.instance.batch();
              for (final doc in snap.docs) {
                batch.update(doc.reference, {'isRead': true});
              }
              await batch.commit();
            },
            child: const Text('Tümünü oku', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: col.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.border),
                  const SizedBox(height: 12),
                  const Text('Henüz bildirim yok', style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = NotificationModel.fromMap(
                  docs[i].data() as Map<String, dynamic>, docs[i].id);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: n.isRead
                        ? AppColors.border.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_rounded,
                    color: n.isRead ? AppColors.textGrey : AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.body, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(n.createdAt),
                        style: const TextStyle(color: AppColors.border, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  if (!n.isRead) {
                    docs[i].reference.update({'isRead': true});
                  }
                  final raw = docs[i].data() as Map<String, dynamic>;
                  final route = raw['route'] as String?;
                  if (route != null && route.isNotEmpty) {
                    context.push(route);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dakika önce';
    if (diff.inDays < 1) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
