import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/clinic_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/widgets/clinic_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .orderBy('savedAt', descending: true)
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
                  Icon(Icons.favorite_border_rounded, size: 56, color: AppColors.border),
                  const SizedBox(height: 12),
                  const Text('Henüz favoriniz yok', style: TextStyle(color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  const Text('Kliniklere kalp ikonuna basarak favori ekleyin',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                ],
              ),
            );
          }
          final clinicIds = docs.map((d) => (d.data() as Map<String, dynamic>)['clinicId'] as String).toList();
          return FutureBuilder<List<ClinicModel>>(
            future: _loadClinics(clinicIds),
            builder: (context, clinicSnap) {
              if (!clinicSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final clinics = clinicSnap.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: clinics.length,
                itemBuilder: (_, i) => ClinicCard(
                  clinic: clinics[i],
                  onTap: () => context.push('/clinic/${clinics[i].id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<ClinicModel>> _loadClinics(List<String> ids) async {
    final futures = ids.map((id) =>
        FirebaseFirestore.instance.collection('clinics').doc(id).get());
    final snaps = await Future.wait(futures);
    return snaps
        .where((s) => s.exists)
        .map((s) => ClinicModel.fromMap(s.data()!, s.id))
        .toList();
  }
}
