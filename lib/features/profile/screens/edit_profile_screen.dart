import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  File? _pickedImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 512);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser!.uid;

    String? photoUrl = auth.userModel?.photoUrl;

    if (_pickedImage != null) {
      final ref = FirebaseStorage.instance.ref('profile_images/$uid.jpg');
      await ref.putFile(_pickedImage!);
      photoUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      if (photoUrl != null) 'photoUrl': photoUrl,
    });

    await auth.reloadUser();
    setState(() => _loading = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellendi'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().userModel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilgilerimi Düzenle'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (user?.photoUrl != null ? NetworkImage(user!.photoUrl!) as ImageProvider : null),
                    child: (_pickedImage == null && user?.photoUrl == null)
                        ? const Icon(Icons.person, size: 54, color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Fotoğrafı değiştir', style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Ad Soyad',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Telefon',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, size: 18, color: AppColors.textGrey),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('E-posta', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    Text(user?.email ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
