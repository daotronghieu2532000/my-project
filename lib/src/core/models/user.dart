class User {
  final int userId;
  final String name;
  final String username;
  final String email;
  final String mobile;
  final String? avatar;
  final int userMoney;
  final int userMoney2;

  const User({
    required this.userId,
    required this.name,
    required this.username,
    required this.email,
    required this.mobile,
    this.avatar,
    required this.userMoney,
    required this.userMoney2,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '', // ✅ Cho phép empty nếu chưa điền
      mobile: json['mobile'] as String? ?? '', // ✅ Cho phép empty nếu chưa điền
      avatar: json['avatar'] as String?,
      userMoney: (json['user_money'] as num?)?.toInt() ?? 0,
      userMoney2: (json['user_money2'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'username': username,
      'email': email,
      'mobile': mobile,
      'avatar': avatar,
      'user_money': userMoney,
      'user_money2': userMoney2,
    };
  }

  User copyWith({
    int? userId,
    String? name,
    String? username,
    String? email,
    String? mobile,
    String? avatar,
    int? userMoney,
    int? userMoney2,
  }) {
    return User(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      avatar: avatar ?? this.avatar,
      userMoney: userMoney ?? this.userMoney,
      userMoney2: userMoney2 ?? this.userMoney2,
    );
  }

  @override
  String toString() {
    return 'User(userId: $userId, name: $name, username: $username, email: $email, mobile: $mobile, avatar: $avatar, userMoney: $userMoney, userMoney2: $userMoney2)';
  }
}
