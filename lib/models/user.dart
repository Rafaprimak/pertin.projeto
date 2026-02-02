import 'dart:convert';
import 'package:crypto/crypto.dart';

class UserModel {
  final int? id;
  final String name;
  final String email;
  final String? passwordHash;
  final String? photoUrl;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.passwordHash,
    this.photoUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Hash de senha para segurança
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Verifica se a senha está correta
  bool verifyPassword(String password) {
    return passwordHash == hashPassword(password);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      passwordHash: map['passwordHash'],
      photoUrl: map['photoUrl'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? passwordHash,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

