import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';

class FavoriteButton extends StatelessWidget {
  final String clinicId;
  final bool light;
  const FavoriteButton({super.key, required this.clinicId, this.light = false});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return const SizedBox();

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(clinicId);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final isFav = snap.data?.exists ?? false;
        return GestureDetector(
          onTap: () {
            if (isFav) {
              ref.delete();
            } else {
              ref.set({'clinicId': clinicId, 'savedAt': Timestamp.now()});
            }
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: light
                  ? Colors.black.withValues(alpha: 0.35)
                  : (isFav ? Colors.red.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.red : (light ? Colors.white : Colors.grey),
              size: 18,
            ),
          ),
        );
      },
    );
  }
}
