import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/clinic_model.dart';

class DentistEditProfileScreen extends StatefulWidget {
  final String clinicId;
  final ClinicModel clinic;
  const DentistEditProfileScreen({super.key, required this.clinicId, required this.clinic});

  @override
  State<DentistEditProfileScreen> createState() => _DentistEditProfileScreenState();
}

class _DentistEditProfileScreenState extends State<DentistEditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;

  late List<_TreatmentEntry> _treatments;
  late Map<String, _HoursEntry> _hours;
  late List<String> _existingPhotos;
  final List<File> _newPhotos = [];
  File? _dentistPhotoFile;
  String? _dentistPhotoUrl;

  bool _loading = false;

  static const _days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  static const _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  @override
  void initState() {
    super.initState();
    final c = widget.clinic;
    _nameCtrl = TextEditingController(text: c.name);
    _descCtrl = TextEditingController(text: c.description);
    _addressCtrl = TextEditingController(text: c.address);
    _phoneCtrl = TextEditingController(text: c.phone);
    _existingPhotos = List<String>.from(c.photos);
    _dentistPhotoUrl = c.dentistPhotoUrl;
    _treatments = c.treatments.map((t) => _TreatmentEntry(
      nameCtrl: TextEditingController(text: t.name),
      priceCtrl: TextEditingController(text: t.priceRange),
    )).toList();
    const trKeys = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    _hours = {
      for (var i = 0; i < _dayKeys.length; i++)
        _dayKeys[i]: _HoursEntry.fromString(
          widget.clinic.workingHours[_dayKeys[i]] ??
          widget.clinic.workingHours[trKeys[i]] ?? '',
        ),
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    for (final t in _treatments) {
      t.nameCtrl.dispose();
      t.priceCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDentistPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1024);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fotoğrafı Kırp',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
      ],
    );
    if (cropped != null) setState(() => _dentistPhotoFile = File(cropped.path));
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1080);
    if (picked.isNotEmpty) {
      setState(() => _newPhotos.addAll(picked.map((x) => File(x.path))));
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final imgMeta = SettableMetadata(contentType: 'image/jpeg');
      if (_dentistPhotoFile != null) {
        final ref = FirebaseStorage.instance.ref('dentist_photos/${widget.clinicId}/photo.jpg');
        await ref.putFile(_dentistPhotoFile!, imgMeta);
        _dentistPhotoUrl = await ref.getDownloadURL();
      }

      final uploadedUrls = <String>[];
      for (final file in _newPhotos) {
        final ref = FirebaseStorage.instance
            .ref('clinic_photos/${widget.clinicId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(file, imgMeta);
        uploadedUrls.add(await ref.getDownloadURL());
      }
      final allPhotos = [..._existingPhotos, ...uploadedUrls];

      final treatments = _treatments
          .where((t) => t.nameCtrl.text.trim().isNotEmpty)
          .map((t) => Treatment(
                name: t.nameCtrl.text.trim(),
                priceRange: t.priceCtrl.text.trim(),
              ).toMap())
          .toList();

      final workingHours = {
        for (var i = 0; i < _dayKeys.length; i++)
          _dayKeys[i]: _hours[_dayKeys[i]]!.closed ? 'Kapalı' : '${_hours[_dayKeys[i]]!.open} - ${_hours[_dayKeys[i]]!.close}',
      };

      await FirebaseFirestore.instance.collection('clinics').doc(widget.clinicId).update({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'treatments': treatments,
        'workingHours': workingHours,
        'photos': allPhotos,
        'dentistPhotoUrl': _dentistPhotoUrl,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil güncellendi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt başarısız: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
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
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            title: 'Profil Fotoğrafı',
            child: Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickDentistPhoto,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                      ),
                      child: _dentistPhotoFile != null
                          ? ClipOval(child: Image.file(_dentistPhotoFile!, fit: BoxFit.cover, width: 100, height: 100))
                          : (_dentistPhotoUrl != null && _dentistPhotoUrl!.isNotEmpty)
                              ? ClipOval(child: Image.network(_dentistPhotoUrl!, fit: BoxFit.cover, width: 100, height: 100))
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_outlined, color: AppColors.primary, size: 28),
                                    SizedBox(height: 4),
                                    Text('Fotoğraf Ekle', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                                  ],
                                ),
                    ),
                  ),
                  if (_dentistPhotoFile != null)
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _dentistPhotoFile = null),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  if (_dentistPhotoFile == null && _dentistPhotoUrl != null && _dentistPhotoUrl!.isNotEmpty)
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _dentistPhotoUrl = null),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Klinik Bilgileri',
            child: Column(
              children: [
                _Field(ctrl: _nameCtrl, label: 'Klinik Adı', icon: Icons.medical_services_outlined),
                const SizedBox(height: 12),
                _Field(ctrl: _phoneCtrl, label: 'Telefon', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                _Field(ctrl: _addressCtrl, label: 'Adres', icon: Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 12),
                _Field(ctrl: _descCtrl, label: 'Hakkında', icon: Icons.info_outline, maxLines: 4),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Klinik Fotoğrafları',
            trailing: TextButton.icon(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
              label: const Text('Ekle'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_existingPhotos.isEmpty && _newPhotos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Henüz fotoğraf eklenmedi', style: TextStyle(color: AppColors.textGrey)),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._existingPhotos.asMap().entries.map((e) => Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(e.value, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 4, right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _existingPhotos.removeAt(e.key)),
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        )),
                        ..._newPhotos.asMap().entries.map((e) => Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(e.value, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 4, right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _newPhotos.removeAt(e.key)),
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Tedaviler',
            trailing: TextButton.icon(
              onPressed: () => setState(() => _treatments.add(_TreatmentEntry(
                nameCtrl: TextEditingController(),
                priceCtrl: TextEditingController(),
              ))),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ekle'),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _treatments.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _treatments[i].nameCtrl,
                          decoration: InputDecoration(
                            hintText: 'Tedavi adı',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _treatments[i].priceCtrl,
                          decoration: InputDecoration(
                            hintText: '₺500 - ₺1000',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        onPressed: () => setState(() => _treatments.removeAt(i)),
                      ),
                    ],
                  ),
                  if (i < _treatments.length - 1) const SizedBox(height: 8),
                ],
                if (_treatments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Henüz tedavi eklenmedi', style: TextStyle(color: AppColors.textGrey)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Çalışma Saatleri',
            child: Column(
              children: [
                for (int i = 0; i < _dayKeys.length; i++)
                  _HourRow(
                    label: _days[i],
                    entry: _hours[_dayKeys[i]]!,
                    onChange: (e) => setState(() => _hours[_dayKeys[i]] = e),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _TreatmentEntry {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  _TreatmentEntry({required this.nameCtrl, required this.priceCtrl});
}

class _HoursEntry {
  bool closed;
  String open;
  String close;
  _HoursEntry({required this.closed, required this.open, required this.close});

  factory _HoursEntry.fromString(String s) {
    if (s.isEmpty || s == 'Kapalı') return _HoursEntry(closed: true, open: '09:00', close: '18:00');
    final parts = s.split(' - ');
    if (parts.length == 2) return _HoursEntry(closed: false, open: parts[0].trim(), close: parts[1].trim());
    return _HoursEntry(closed: false, open: '09:00', close: '18:00');
  }
}

class _HourRow extends StatelessWidget {
  final String label;
  final _HoursEntry entry;
  final ValueChanged<_HoursEntry> onChange;
  const _HourRow({required this.label, required this.entry, required this.onChange});

  Future<void> _pickTime(BuildContext context, bool isOpen) async {
    final parts = (isOpen ? entry.open : entry.close).split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onChange(_HoursEntry(
        closed: entry.closed,
        open: isOpen ? str : entry.open,
        close: isOpen ? entry.close : str,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Switch(
            value: !entry.closed,
            onChanged: (v) => onChange(_HoursEntry(closed: !v, open: entry.open, close: entry.close)),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          if (!entry.closed) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _pickTime(context, true),
              child: _TimeChip(entry.open),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('–', style: TextStyle(color: AppColors.textGrey)),
            ),
            GestureDetector(
              onTap: () => _pickTime(context, false),
              child: _TimeChip(entry.close),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('Kapalı', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  const _TimeChip(this.time);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(time, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboard;
  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
