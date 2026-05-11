import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/screens/chat_screen.dart';

class DentistMessagesScreen extends StatelessWidget {
  const DentistMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
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
          final clinicName = (clinicSnap.data!.docs.first.data() as Map<String, dynamic>)['name'] ?? '';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('clinicId', isEqualTo: clinicId)
                .snapshots(),
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
                      Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.border),
                      const SizedBox(height: 12),
                      const Text('Henüz mesaj yok', style: TextStyle(color: AppColors.textGrey)),
                    ],
                  ),
                );
              }
              final chats = docs.map((d) => ChatModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
              chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: chats.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final chat = chats[i];
                  final hasUnread = chat.lastMessage.isNotEmpty && chat.lastSenderId.isNotEmpty && chat.lastSenderId == chat.userId;
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(chat.userId).get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.hasData && userSnap.data!.exists
                          ? userSnap.data!.data() as Map<String, dynamic>
                          : <String, dynamic>{};
                      final userName = userData['name'] as String? ?? 'Hasta';
                      final userPhone = userData['phone'] as String? ?? '';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person_rounded, color: AppColors.primary),
                        ),
                        title: Text(userName,
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: hasUnread ? AppColors.textDark : null,
                            )),
                        subtitle: Text(chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread ? AppColors.textDark : AppColors.textGrey,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              fontSize: 13,
                            )),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${chat.lastMessageAt.hour.toString().padLeft(2, '0')}:${chat.lastMessageAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: hasUnread ? AppColors.primary : AppColors.textGrey,
                                fontSize: 12,
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              ),
                            ],
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chat.id,
                              clinicName: clinicName,
                              patientName: userName,
                              patientPhone: userPhone,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
