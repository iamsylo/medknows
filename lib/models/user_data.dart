class UserData {
  final String id;  // Changed from uid
  final String username;  // Changed from email
  final String name;
  final String birthdate;
  final int age;
  final String sex;
  final double height;
  final double weight;

  UserData({
    required this.id,
    required this.username,
    required this.name,
    required this.birthdate,
    required this.age,
    required this.sex,
    required this.height,
    required this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'birthdate': birthdate,
      'age': age,
      'sex': sex,
      'height': height,
      'weight': weight,
      'createdAt': DateTime.now(),
    };
  }

  // Add a factory constructor to create UserData from Firestore document
  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      name: map['name'] ?? '',
      birthdate: map['birthdate'] ?? '',
      age: map['age'] ?? 0,
      sex: map['sex'] ?? 'Male',
      height: (map['height'] ?? 0).toDouble(),
      weight: (map['weight'] ?? 0).toDouble(),
    );
  }
}
