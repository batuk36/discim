import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/message_model.dart';
import '../../auth/providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String clinicName;
  final String? patientName;
  final String? patientPhone;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.clinicName,
    this.patientName,
    this.patientPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    final lastSender = (doc.data()?['lastSenderId'] as String?) ?? '';
    if (lastSender != uid && lastSender.isNotEmpty) {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'lastSenderId': '',
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    _ctrl.clear();

    final msg = MessageModel(
      id: '',
      senderId: uid,
      text: text,
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(msg.toMap());

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastSenderId': uid,
    });

    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent + 100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    final isDentistView = widget.patientName != null;
    final displayName = isDentistView ? widget.patientName! : widget.clinicName;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                isDentistView ? Icons.person_rounded : Icons.medical_services_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(displayName, style: const TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          if (isDentistView && widget.patientPhone != null && widget.patientPhone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_outlined),
              tooltip: widget.patientPhone,
              onPressed: () => launchUrl(Uri.parse('tel:${widget.patientPhone}')),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Konuşmayı başlatın', style: TextStyle(color: AppColors.textGrey)),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final msg = MessageModel.fromMap(docs[i].data() as Map<String, dynamic>, docs[i].id);
                    final isMe = msg.senderId == uid;
                    return _MessageBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(color: isMe ? Colors.white : AppColors.textDark, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: isMe ? Colors.white60 : AppColors.textGrey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
