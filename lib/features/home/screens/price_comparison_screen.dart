import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/clinic_model.dart';

class PriceComparisonScreen extends StatefulWidget {
  const PriceComparisonScreen({super.key});

  @override
  State<PriceComparisonScreen> createState() => _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  String? _selectedTreatment;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Fiyat Karşılaştırma', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
            tooltip: _sortAscending ? 'Ucuzdan pahalıya' : 'Pahalıdan ucuza',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clinics').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final clinics = (snap.data?.docs ?? [])
              .map((d) => ClinicModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .where((c) => c.treatments.isNotEmpty)
              .toList();

          // Collect all unique treatment names
          final allTreatments = <String>{};
          for (final c in clinics) {
            for (final t in c.treatments) {
              if (t.name.isNotEmpty) allTreatments.add(t.name);
            }
          }
          final treatmentList = allTreatments.toList()..sort();

          // Build rows: clinic + selected treatment price
          final rows = <_PriceRow>[];
          for (final c in clinics) {
            if (_selectedTreatment == null) {
              // Show all treatments as separate rows
              for (final t in c.treatments) {
                rows.add(_PriceRow(clinicId: c.id, clinicName: c.name, treatment: t.name, priceRange: t.priceRange, rating: c.rating));
              }
            } else {
              final t = c.treatments.where((t) => t.name == _selectedTreatment).firstOrNull;
              if (t != null) {
                rows.add(_PriceRow(clinicId: c.id, clinicName: c.name, treatment: t.name, priceRange: t.priceRange, rating: c.rating));
              }
            }
          }

          // Sort by parsed min price
          rows.sort((a, b) {
            final pa = _parseMinPrice(a.priceRange);
            final pb = _parseMinPrice(b.priceRange);
            return _sortAscending ? pa.compareTo(pb) : pb.compareTo(pa);
          });

          return Column(
            children: [
              // Treatment filter chips
              Container(
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        'Tedavi seç',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        children: [
                          _FilterChip(
                            label: 'Tümü',
                            selected: _selectedTreatment == null,
                            onTap: () => setState(() => _selectedTreatment = null),
                          ),
                          ...treatmentList.map((t) => _FilterChip(
                            label: t,
                            selected: _selectedTreatment == t,
                            onTap: () => setState(() => _selectedTreatment = t),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (rows.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.border),
                        SizedBox(height: 12),
                        Text('Bu tedavi için fiyat bulunamadı', style: TextStyle(color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _PriceCard(row: rows[i], rank: i, onTap: () => context.push('/clinic/${rows[i].clinicId}')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int _parseMinPrice(String priceRange) {
    if (priceRange.isEmpty) return 999999;
    final digits = RegExp(r'\d+').allMatches(priceRange.replaceAll('.', '').replaceAll(',', ''));
    if (digits.isEmpty) return 999999;
    return int.tryParse(digits.first.group(0)!) ?? 999999;
  }
}

class _PriceRow {
  final String clinicId;
  final String clinicName;
  final String treatment;
  final String priceRange;
  final double rating;
  const _PriceRow({
    required this.clinicId,
    required this.clinicName,
    required this.treatment,
    required this.priceRange,
    required this.rating,
  });
}

class _PriceCard extends StatelessWidget {
  final _PriceRow row;
  final int rank;
  final VoidCallback onTap;
  const _PriceCard({required this.row, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isTop ? Border.all(color: const Color(0xFF4CAF50), width: 2) : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isTop ? const Color(0xFF4CAF50) : (rank == 1 ? const Color(0xFFFFC107) : AppColors.border),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isTop
                    ? const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18)
                    : Text(
                        '${rank + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: rank == 1 ? Colors.white : AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.clinicName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(row.treatment, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 14),
                      const SizedBox(width: 2),
                      Text(row.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  row.priceRange.isEmpty ? 'Belirtilmemiş' : row.priceRange,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isTop ? const Color(0xFF4CAF50) : AppColors.textDark,
                  ),
                ),
                if (isTop)
                  const Text('En uygun', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.white38),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : Colors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
