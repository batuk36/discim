class Treatment {
  final String name;
  final String priceRange;

  Treatment({required this.name, required this.priceRange});

  factory Treatment.fromMap(Map<String, dynamic> m) =>
      Treatment(name: m['name'] ?? '', priceRange: m['priceRange'] ?? '');

  Map<String, dynamic> toMap() => {'name': name, 'priceRange': priceRange};
}

class ClinicModel {
  final String id;
  final String name;
  final String description;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final String email;
  final List<String> photos;
  final List<Treatment> treatments;
  final Map<String, String> workingHours;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String subscriptionStatus;
  final String ownerId;
  final bool isOnline;
  final bool isApproved;
  final String? dentistPhotoUrl;

  ClinicModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.lat,
    required this.lng,
    required this.phone,
    required this.email,
    required this.photos,
    required this.treatments,
    required this.workingHours,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.subscriptionStatus,
    required this.ownerId,
    this.isOnline = false,
    this.isApproved = false,
    this.dentistPhotoUrl,
  });

  factory ClinicModel.fromMap(Map<String, dynamic> m, String id) => ClinicModel(
        id: id,
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        address: m['address'] ?? '',
        lat: (m['lat'] ?? 0).toDouble(),
        lng: (m['lng'] ?? 0).toDouble(),
        phone: m['phone'] ?? '',
        email: m['email'] ?? '',
        photos: List<String>.from(m['photos'] ?? []),
        treatments: (m['treatments'] as List? ?? [])
            .map((t) => Treatment.fromMap(Map<String, dynamic>.from(t)))
            .toList(),
        workingHours: Map<String, String>.from(m['workingHours'] ?? {}),
        rating: (m['rating'] ?? 0).toDouble(),
        reviewCount: m['reviewCount'] ?? 0,
        isVerified: m['isVerified'] ?? false,
        subscriptionStatus: m['subscriptionStatus'] ?? 'free',
        ownerId: m['ownerId'] ?? '',
        isOnline: m['isOnline'] ?? false,
        isApproved: m['isApproved'] ?? true,
        dentistPhotoUrl: m['dentistPhotoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'address': address,
        'lat': lat,
        'lng': lng,
        'phone': phone,
        'email': email,
        'photos': photos,
        'treatments': treatments.map((t) => t.toMap()).toList(),
        'workingHours': workingHours,
        'rating': rating,
        'reviewCount': reviewCount,
        'isVerified': isVerified,
        'subscriptionStatus': subscriptionStatus,
        'ownerId': ownerId,
        'isOnline': isOnline,
        'isApproved': isApproved,
        if (dentistPhotoUrl != null) 'dentistPhotoUrl': dentistPhotoUrl,
      };
}
