import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class DentistRegisterScreen extends StatefulWidget {
  const DentistRegisterScreen({super.key});

  @override
  State<DentistRegisterScreen> createState() => _DentistRegisterScreenState();
}

class _DentistRegisterScreenState extends State<DentistRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _clinicCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await FirebaseFirestore.instance.collection('clinics').add({
        'name': _clinicCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'lat': 39.9208,
        'lng': 32.8541,
        'photos': [],
        'treatments': [],
        'workingHours': {},
        'rating': 0.0,
        'reviewCount': 0,
        'isVerified': false,
        'isApproved': false,
        'subscriptionStatus': 'active',
        'ownerId': cred.user!.uid,
      });
      // Firebase Extensions "Trigger Email from Firestore" ile email gönder
      // Firebase Console > Extensions > "Trigger Email from Firestore" kurulumu gerekli
      await FirebaseFirestore.instance.collection('mail').add({
        'to': 'destekdiscim@gmail.com',
        'message': {
          'subject': 'Yeni Klinik Onay Bekliyor - ${_clinicCtrl.text.trim()}',
          'text':
              'Yeni bir klinik kaydı onay bekliyor.\n\n'
              'Klinik: ${_clinicCtrl.text.trim()}\n'
              'Adres: ${_addressCtrl.text.trim()}\n'
              'Telefon: ${_phoneCtrl.text.trim()}\n'
              'Email: ${_emailCtrl.text.trim()}\n\n'
              'Onaylamak için Firebase Console > clinics koleksiyonunda '
              'ilgili klinik belgesinde isApproved alanını true yapın.',
        },
      });
      if (mounted) context.go('/dentist');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata oluştu')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF005F6B), Color(0xFF00BCD4)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.medical_services_rounded, color: Colors.white, size: 44),
                  const SizedBox(height: 8),
                  const Text('Dişçim', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const Text('Klinik kaydı oluştur', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Klinik Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          _field(_clinicCtrl, 'Klinik Adı', Icons.business_outlined),
                          const SizedBox(height: 12),
                          _field(_phoneCtrl, 'Telefon', Icons.phone_outlined, type: TextInputType.phone),
                          const SizedBox(height: 12),
                          _field(_addressCtrl, 'Adres', Icons.location_on_outlined),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Klinik Hakkında',
                              prefixIcon: Icon(Icons.info_outline),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text('Hesap Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          _field(_nameCtrl, 'Ad Soyad', Icons.person_outline),
                          const SizedBox(height: 12),
                          _field(_emailCtrl, 'E-posta', Icons.email_outlined, type: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => v!.length < 6 ? 'En az 6 karakter' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _loading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Kayıt Ol', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Zaten hesabın var mı? Giriş yap', style: TextStyle(color: AppColors.primary)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType? type}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) => v!.isEmpty ? '$label gerekli' : null,
    );
  }
}
