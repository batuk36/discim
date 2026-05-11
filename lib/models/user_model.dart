class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) => UserModel(
        id: id,
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'],
        photoUrl: map['photoUrl'],
        createdAt: (map['createdAt'] as dynamic).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'createdAt': createdAt,
      };
}
