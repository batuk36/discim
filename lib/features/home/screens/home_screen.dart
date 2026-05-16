import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/floating_bottom_nav.dart';
import '../../../core/utils/search_history.dart';
import '../../../models/clinic_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../widgets/clinic_card.dart';
import 'price_comparison_screen.dart';
import '../../../core/utils/time_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);
    });
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none));
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isOffline ? null : 0,
            child: _isOffline
                ? Container(
                    width: double.infinity,
                    color: const Color(0xFFB71C1C),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 8,
                      16,
                      8,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'İnternet bağlantısı yok',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                _ExplorePage(),
                _PlaceholderPage(icon: Icons.calendar_month_rounded, label: 'Randevularım'),
                _PlaceholderPage(icon: Icons.chat_bubble_rounded, label: 'Mesajlar'),
                _PlaceholderPage(icon: Icons.person_rounded, label: 'Profil'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          final unread = snap.data?.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final lastSender = data['lastSenderId'] as String? ?? '';
            final lastMsg = data['lastMessage'] as String? ?? '';
            return lastMsg.isNotEmpty && lastSender.isNotEmpty && lastSender != uid;
          }).length ?? 0;
          return FloatingBottomNav(
            currentIndex: _currentIndex,
            badgeCounts: unread > 0 ? {2: unread} : {},
            onTap: (i) {
              FocusManager.instance.primaryFocus?.unfocus();
              if (i == 1) return context.push('/appointments');
              if (i == 2) return context.push('/messages');
              if (i == 3) return context.push('/profile');
              setState(() => _currentIndex = i);
            },
          );
        },
      ),
    );
  }
}

class _ExplorePage extends StatefulWidget {
  const _ExplorePage();

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  String _activeFilter = 'Tümü';
  final _filters = ['Tümü', 'Implant', 'Ortodonti', 'Kanal', 'Estetik', 'Şimdi Açık'];
  Position? _userPosition;
  List<String> _searchHistory = [];
  bool _searchFocused = false;

  // Advanced filters
  final Set<String> _treatmentFilter = {};
  double _minRatingFilter = 0;
  double _maxDistanceKm = 0;
  bool _onlyOpenFilter = false;

  int get _activeFilterCount {
    int c = 0;
    if (_treatmentFilter.isNotEmpty) c++;
    if (_minRatingFilter > 0) c++;
    if (_maxDistanceKm > 0) c++;
    if (_onlyOpenFilter) c++;
    return c;
  }

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _loadHistory();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        _loadHistory();
        setState(() => _searchFocused = true);
      } else {
        setState(() => _searchFocused = false);
      }
    });
    // Keyboard açılmasın
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid != null) {
      Future.microtask(() => _checkReminders(uid));
    }
  }

  Future<void> _loadHistory() async {
    final h = await SearchHistory.get();
    if (mounted) setState(() => _searchHistory = h);
  }

  Future<void> _checkReminders(String uid) async {
    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final tStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'confirmed')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (dateStr == tStr && data['reminderSent'] != true) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .add({
            'title': 'Yarın randevunuz var! 🦷',
            'body': '${data['clinicName']} kliniğinde saat ${data['time']} - ${data['treatmentType']}',
            'isRead': false,
            'createdAt': Timestamp.now(),
            'route': '/appointments',
          });
          await doc.reference.update({'reminderSent': true});
        }
      }
    } catch (_) {}
  }

  void _submitSearch(String value) {
    if (value.trim().isEmpty) return;
    SearchHistory.add(value.trim());
    _searchFocus.unfocus();
  }

  Future<void> _fetchLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {}
  }

  void _openFilterModal() {
    final treatmentOptions = ['Implant', 'Ortodonti', 'Kanal', 'Estetik', 'Dolgu', 'Çekim', 'Protez', 'Pedodonti'];
    final tmpTreatments = Set<String>.from(_treatmentFilter);
    var tmpRating = _minRatingFilter;
    var tmpDistance = _maxDistanceKm;
    var tmpOnlyOpen = _onlyOpenFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    const Text('Filtreler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setModal(() {
                          tmpTreatments.clear();
                          tmpRating = 0;
                          tmpDistance = 0;
                          tmpOnlyOpen = false;
                        });
                      },
                      child: const Text('Temizle', style: TextStyle(color: AppColors.textGrey)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('Tedavi Türü', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: treatmentOptions.map((t) {
                        final selected = tmpTreatments.contains(t);
                        return FilterChip(
                          label: Text(t),
                          selected: selected,
                          onSelected: (v) => setModal(() {
                            if (v) {
                              tmpTreatments.add(t);
                            } else {
                              tmpTreatments.remove(t);
                            }
                          }),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primary : AppColors.textGrey,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('Minimum Puan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return GestureDetector(
                          onTap: () => setModal(() => tmpRating = tmpRating == star.toDouble() ? 0 : star.toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.star_rounded,
                              size: 32,
                              color: star <= tmpRating ? const Color(0xFFFFC107) : AppColors.border,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (tmpRating > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${tmpRating.toInt()} yıldız ve üzeri',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      ),
                    const SizedBox(height: 24),
                    const Text('Mesafe', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_userPosition == null)
                      const Text('Konum izni gerekli', style: TextStyle(fontSize: 12, color: AppColors.textGrey))
                    else
                      Wrap(
                        spacing: 8,
                        children: [0.0, 1.0, 3.0, 5.0, 10.0].map((d) {
                          final label = d == 0 ? 'Tümü' : '${d.toInt()} km';
                          final selected = tmpDistance == d;
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) => setModal(() => tmpDistance = d),
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: selected ? AppColors.primary : AppColors.textGrey,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sadece Açık Olanlar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Switch(
                          value: tmpOnlyOpen,
                          onChanged: (v) => setModal(() => tmpOnlyOpen = v),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _treatmentFilter
                          ..clear()
                          ..addAll(tmpTreatments);
                        _minRatingFilter = tmpRating;
                        _maxDistanceKm = tmpDistance;
                        _onlyOpenFilter = tmpOnlyOpen;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Filtrele', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final firstName = user?.name.split(' ').first ?? '';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF005F6B), Color(0xFF00BCD4)],
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                          ? ClipOval(child: Image.network(user.photoUrl!, fit: BoxFit.cover, width: 46, height: 46))
                          : Center(
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hoş geldin,', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        Text(firstName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                      child: Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(context.read<AuthProvider>().firebaseUser?.uid ?? '')
                                .collection('notifications')
                                .where('isRead', isEqualTo: false)
                                .snapshots(),
                            builder: (context, snap) {
                              final count = snap.data?.docs.length ?? 0;
                              if (count == 0) return const SizedBox();
                              return Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                      count > 9 ? '9+' : '$count',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Dişçini bul,\nrandevunu al.',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          autofocus: false,
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          onSubmitted: _submitSearch,
                          decoration: InputDecoration(
                            hintText: 'Dişçi, klinik veya tedavi ara...',
                            hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: AppColors.textGrey),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _openFilterModal,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _activeFilterCount > 0 ? const Color(0xFF004F5B) : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white30, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Center(child: Icon(Icons.tune_rounded, color: Colors.white, size: 22)),
                            if (_activeFilterCount > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                      '$_activeFilterCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _QuickActions(
                  onAcil: () => setState(() { _activeFilter = 'Şimdi Açık'; _searchQuery = ''; _searchCtrl.clear(); }),
                  onYakinimda: () => _fetchLocation(),
                  onFiyat: () { FocusManager.instance.primaryFocus?.unfocus(); Navigator.push(context, MaterialPageRoute(builder: (_) => const PriceComparisonScreen())); },
                  onFavoriler: () { FocusManager.instance.primaryFocus?.unfocus(); Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())); },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: _searchFocused && _searchQuery.isEmpty && _searchHistory.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Son Aramalar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              await SearchHistory.clear();
                              setState(() => _searchHistory = []);
                            },
                            child: const Text('Temizle', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _searchHistory.map((h) => GestureDetector(
                          onTap: () {
                            _searchCtrl.text = h;
                            setState(() { _searchQuery = h.toLowerCase(); _searchFocused = false; });
                            _searchFocus.unfocus();
                            SearchHistory.add(h);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, size: 14, color: AppColors.textGrey),
                                const SizedBox(width: 6),
                                Text(h, style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 0, 4),
                  child: SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (_, i) {
                        final isActive = _filters[i] == _activeFilter;
                        return GestureDetector(
                          onTap: () => setState(() => _activeFilter = _filters[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                            ),
                            child: Text(
                              _filters[i],
                              style: TextStyle(
                                color: isActive ? Colors.white : AppColors.textGrey,
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Yakınımdaki Klinikler',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _activeFilter = 'Tümü';
                    _searchQuery = '';
                    _searchCtrl.clear();
                    _treatmentFilter.clear();
                    _minRatingFilter = 0;
                    _maxDistanceKm = 0;
                    _onlyOpenFilter = false;
                  }),
                  child: const Text('Tümünü gör', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clinics').snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )),
              );
            }

            final docs = snap.data?.docs ?? [];
            var clinics = docs
                .map((d) => ClinicModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                .where((c) => c.name.trim().isNotEmpty && c.isApproved)
                .where((c) {
              if (_searchQuery.isNotEmpty) {
                if (!c.name.toLowerCase().contains(_searchQuery) &&
                    !c.treatments.any((t) => t.name.toLowerCase().contains(_searchQuery))) {
                  return false;
                }
              }
              if (_activeFilter == 'Şimdi Açık') {
                if (!isClinicOpenNow(c.workingHours)) return false;
              } else if (_activeFilter != 'Tümü') {
                if (!c.treatments.any((t) => t.name.contains(_activeFilter))) return false;
              }
              if (_treatmentFilter.isNotEmpty) {
                if (!c.treatments.any((t) => _treatmentFilter.contains(t.name))) return false;
              }
              if (_onlyOpenFilter && !isClinicOpenNow(c.workingHours)) return false;
              if (_minRatingFilter > 0 && c.rating < _minRatingFilter) return false;
              return true;
            }).toList();

            Map<String, double> distances = {};
            if (_userPosition != null) {
              for (final c in clinics) {
                if (c.lat != 0 && c.lng != 0) {
                  distances[c.id] = Geolocator.distanceBetween(
                    _userPosition!.latitude, _userPosition!.longitude,
                    c.lat, c.lng,
                  ) / 1000;
                }
              }
              clinics.sort((a, b) {
                final da = distances[a.id] ?? double.infinity;
                final db = distances[b.id] ?? double.infinity;
                return da.compareTo(db);
              });
              if (_maxDistanceKm > 0) {
                clinics = clinics.where((c) {
                  final dist = distances[c.id];
                  return dist == null || dist <= _maxDistanceKm;
                }).toList();
              }
            }

            if (clinics.isEmpty) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.border),
                        SizedBox(height: 12),
                        Text('Klinik bulunamadı', style: TextStyle(color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ClinicCard(
                    clinic: clinics[i],
                    distanceKm: distances[clinics[i].id],
                    onTap: () => context.push('/clinic/${clinics[i].id}'),
                  ),
                  childCount: clinics.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback? onAcil;
  final VoidCallback? onYakinimda;
  final VoidCallback? onFiyat;
  final VoidCallback? onFavoriler;

  const _QuickActions({this.onAcil, this.onYakinimda, this.onFiyat, this.onFavoriler});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.flash_on_rounded, 'label': 'Acil', 'color': const Color(0xFFFF5252), 'onTap': onAcil},
      {'icon': Icons.location_on_rounded, 'label': 'Yakınımda', 'color': const Color(0xFF00BCD4), 'onTap': onYakinimda},
      {'icon': Icons.compare_arrows_rounded, 'label': 'Fiyat', 'color': const Color(0xFF9C27B0), 'onTap': onFiyat},
      {'icon': Icons.favorite_rounded, 'label': 'Favoriler', 'color': const Color(0xFFFF7043), 'onTap': onFavoriler},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((item) {
        return GestureDetector(
          onTap: item['onTap'] as VoidCallback?,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(item['icon'] as IconData, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 6),
              Text(item['label'] as String, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderPage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
