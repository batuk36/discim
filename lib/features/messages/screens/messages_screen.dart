import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    bool _isUnread(ChatModel chat) =>
        chat.lastMessage.isNotEmpty && chat.lastSenderId.isNotEmpty && chat.lastSenderId != uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('userId', isEqualTo: uid)
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
                  const Text('Henüz mesajınız yok', style: TextStyle(color: AppColors.textGrey)),
                  const SizedBox(height: 8),
                  const Text('Bir klinikle iletişime geçin', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                ],
              ),
            );
          }
          final chats = docs.map((d) => ChatModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
          chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          return RefreshIndicator(
            onRefresh: () async {},
            color: AppColors.primary,
            child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final chat = chats[i];
              final unread = _isUnread(chat);
              return Dismissible(
                key: Key(chat.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.error,
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (dlgCtx) => AlertDialog(
                      title: const Text('Sohbeti Sil'),
                      content: Text('${chat.clinicName} ile olan sohbet silinecek.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('İptal')),
                        TextButton(
                          onPressed: () => Navigator.pop(dlgCtx, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Sil'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) async {
                  final db = FirebaseFirestore.instance;
                  final msgSnap = await db.collection('chats').doc(chat.id).collection('messages').get();
                  for (final m in msgSnap.docs) {
                    await m.reference.delete();
                  }
                  await db.collection('chats').doc(chat.id).delete();
                },
                child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.medical_services_rounded, color: AppColors.primary),
                ),
                title: Text(
                  chat.clinicName,
                  style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                ),
                subtitle: Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread ? AppColors.textDark : AppColors.textGrey,
                    fontSize: 13,
                    fontWeight: unread ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${chat.lastMessageAt.hour.toString().padLeft(2, '0')}:${chat.lastMessageAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: unread ? AppColors.primary : AppColors.textGrey,
                        fontSize: 12,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: chat.id, clinicName: chat.clinicName),
                )),
              ),
              );
            },
          ));
        },
      ),
    );
  }
}
