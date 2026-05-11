import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/review_model.dart';
import '../../auth/providers/auth_provider.dart';

class AddReviewScreen extends StatefulWidget {
  final String clinicId;
  final String clinicName;
  const AddReviewScreen({super.key, required this.clinicId, required this.clinicName});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _ctrl = TextEditingController();
  double _rating = 5;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser!.uid;
    final userName = auth.userModel?.name ?? 'Kullanıcı';

    final review = ReviewModel(
      id: '',
      userId: uid,
      userName: userName,
      clinicId: widget.clinicId,
      rating: _rating,
      comment: _ctrl.text.trim(),
      createdAt: DateTime.now(),
    );

    final db = FirebaseFirestore.instance;
    await db.collection('clinics').doc(widget.clinicId)
        .collection('reviews').add(review.toMap());

    final clinicRef = db.collection('clinics').doc(widget.clinicId);
    final clinicDoc = await clinicRef.get();
    final data = clinicDoc.data() as Map<String, dynamic>;
    final oldRating = (data['rating'] ?? 0).toDouble();
    final oldCount = (data['reviewCount'] ?? 0) as int;
    final newCount = oldCount + 1;
    final newRating = ((oldRating * oldCount) + _rating) / newCount;
    await clinicRef.update({'rating': newRating, 'reviewCount': newCount});

    setState(() => _loading = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.clinicName)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Puanınız', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 40,
                ),
              )),
            ),
            const SizedBox(height: 24),
            const Text('Yorumunuz', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Deneyiminizi paylaşın...'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Yorum Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
