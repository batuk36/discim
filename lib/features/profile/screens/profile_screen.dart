import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    final uid = auth.firebaseUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                  child: user?.photoUrl == null
                      ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(user?.name ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Center(
            child: Text(user?.email ?? '',
                style: const TextStyle(color: AppColors.textGrey)),
          ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Bilgilerimi Düzenle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          ListTile(
            leading: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('notifications')
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    if (count == 0) return const SizedBox();
                    return Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    );
                  },
                ),
              ],
            ),
            title: const Text('Bildirimler'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Yardım'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Yardım'),
                content: const Text(
                  'Sorun yaşıyorsanız bize ulaşın:\n\n'
                  '📧 destek@discim.com\n\n'
                  'Dişçim v1.0.0',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tamam'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
            onTap: () => auth.signOut(),
          ),
        ],
      ),
    );
  }
}
