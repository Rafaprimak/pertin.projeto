import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pertin/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (_isLoggedIn) {
        final userData = prefs.getString('userData');
        if (userData != null) {
          _user = UserModel.fromMap(jsonDecode(userData));
        }
      }
    } catch (e) {
      debugPrint('Erro ao inicializar usuário: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> register(String name, String email, String password) async {
    _errorMessage = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      debugPrint('Registrando novo usuário: $name, $email');
      
      // Verifica se já existe um usuário com esse email
      final existingUsers = prefs.getStringList('users') ?? [];
      debugPrint('Usuários existentes: ${existingUsers.length}');
      
      for (final userJson in existingUsers) {
        final userData = jsonDecode(userJson);
        if (userData['email'] == email) {
          _errorMessage = 'Este e-mail já está cadastrado';
          notifyListeners();
          return false;
        }
      }

      // Cria novo usuário
      final newUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        email: email,
        passwordHash: UserModel.hashPassword(password),
      );

      // Salva na lista de usuários
      existingUsers.add(jsonEncode(newUser.toMap()));
      await prefs.setStringList('users', existingUsers);
      
      debugPrint('Usuário salvo. Total de usuários: ${existingUsers.length}');

      // Faz login automático
      _user = newUser;
      await prefs.setString('userData', jsonEncode(newUser.toMap()));
      await prefs.setBool('isLoggedIn', true);
      _isLoggedIn = true;

      debugPrint('Registro e login automático concluídos!');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erro ao registrar usuário: $e');
      _errorMessage = 'Erro ao criar conta. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingUsers = prefs.getStringList('users') ?? [];
      
      debugPrint('Tentando login com email: $email');
      debugPrint('Usuários cadastrados: ${existingUsers.length}');
      
      final passwordHash = UserModel.hashPassword(password);
      
      for (final userJson in existingUsers) {
        final userData = jsonDecode(userJson);
        debugPrint('Verificando usuário: ${userData['email']}');
        if (userData['email'] == email) {
          if (userData['passwordHash'] == passwordHash) {
            _user = UserModel.fromMap(userData);
            await prefs.setString('userData', jsonEncode(_user!.toMap()));
            await prefs.setBool('isLoggedIn', true);
            _isLoggedIn = true;
            debugPrint('Login bem sucedido!');
            notifyListeners();
            return true;
          } else {
            _errorMessage = 'Senha incorreta';
            debugPrint('Senha incorreta');
            notifyListeners();
            return false;
          }
        }
      }
      
      _errorMessage = 'E-mail não encontrado. Crie uma conta primeiro.';
      debugPrint('Email não encontrado');
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Erro ao fazer login: $e');
      _errorMessage = 'Erro ao fazer login. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email, String newPassword) async {
    _errorMessage = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingUsers = prefs.getStringList('users') ?? [];
      
      for (int i = 0; i < existingUsers.length; i++) {
        final userData = jsonDecode(existingUsers[i]);
        if (userData['email'] == email) {
          // Atualiza a senha
          userData['passwordHash'] = UserModel.hashPassword(newPassword);
          existingUsers[i] = jsonEncode(userData);
          await prefs.setStringList('users', existingUsers);
          return true;
        }
      }
      
      _errorMessage = 'E-mail não encontrado';
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Erro ao redefinir senha: $e');
      _errorMessage = 'Erro ao redefinir senha. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({String? name, String? email, String? photoUrl}) async {
    if (_user == null) return;

    final updatedUser = _user!.copyWith(
      name: name ?? _user!.name,
      email: email ?? _user!.email,
      photoUrl: photoUrl ?? _user!.photoUrl,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(updatedUser.toMap()));
      
      // Atualiza na lista de usuários também
      final existingUsers = prefs.getStringList('users') ?? [];
      for (int i = 0; i < existingUsers.length; i++) {
        final userData = jsonDecode(existingUsers[i]);
        if (userData['id'] == _user!.id) {
          existingUsers[i] = jsonEncode(updatedUser.toMap());
          await prefs.setStringList('users', existingUsers);
          break;
        }
      }
      
      _user = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao atualizar perfil: $e');
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userData');
      _isLoggedIn = false;
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao fazer logout: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
