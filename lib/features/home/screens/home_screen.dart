import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _ExplorePage(),
          _PlaceholderPage(icon: Icons.calendar_month_rounded, label: 'Randevularım'),
          _PlaceholderPage(icon: Icons.chat_bubble_rounded, label: 'Mesajlar'),
          _PlaceholderPage(icon: Icons.person_rounded, label: 'Profil'),
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
    // Check upcoming appointment reminders
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
          // Add in-app notification
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
                      child: Center(
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
                Container(
                  margin: const EdgeInsets.only(bottom: 0),
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
                          : Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                            ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _QuickActions(
                  onAcil: () => setState(() { _activeFilter = 'Şimdi Açık'; _searchQuery = ''; _searchCtrl.clear(); }),
                  onYakinimda: () => _fetchLocation(),
                  onFiyat: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PriceComparisonScreen())),
                  onFavoriler: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
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
                  onPressed: () => setState(() { _activeFilter = 'Tümü'; _searchQuery = ''; _searchCtrl.clear(); }),
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
                .where((c) {
              if (_searchQuery.isNotEmpty) {
                return c.name.toLowerCase().contains(_searchQuery) ||
                    c.treatments.any((t) => t.name.toLowerCase().contains(_searchQuery));
              }
              if (_activeFilter == 'Şimdi Açık') {
                return isClinicOpenNow(c.workingHours);
              }
              if (_activeFilter != 'Tümü') {
                return c.treatments.any((t) => t.name.contains(_activeFilter));
              }
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
