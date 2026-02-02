import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pertin/models/user.dart';
import 'package:pertin/services/encryption_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  User? _firebaseUser;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _errorMessage;
  
  // Rate limiting para reset de senha
  DateTime? _lastResetAttempt;
  int _resetAttemptCount = 0;
  static const int _maxResetAttempts = 3;
  static const Duration _resetCooldown = Duration(minutes: 5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? get user => _user;
  User? get firebaseUser => _firebaseUser;
  String? get currentUserId => _firebaseUser?.uid;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Verifica se há usuário autenticado no Firebase Auth
      _firebaseUser = _auth.currentUser;
      _isLoggedIn = _firebaseUser != null;

      if (_isLoggedIn && _firebaseUser != null) {
        // Inicializa a criptografia com o UID do usuário
        await EncryptionService.instance.onUserLogin(_firebaseUser!.uid);
        
        // Busca dados do usuário no Firestore
        final doc = await _usersCollection.doc(_firebaseUser!.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          _user = UserModel.fromMap(data);
          debugPrint('Usuário carregado do Firebase: ${_user?.name}');
        } else {
          // Cria documento do usuário se não existir
          final newUser = UserModel(
            name: _firebaseUser!.displayName ?? 'Usuário',
            email: _firebaseUser!.email ?? '',
            photoUrl: _firebaseUser!.photoURL,
          );
          await _usersCollection.doc(_firebaseUser!.uid).set(newUser.toMap());
          _user = newUser;
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
      debugPrint('Registrando novo usuário no Firebase Auth: $name, $email');
      
      // Cria usuário no Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _firebaseUser = userCredential.user;
      
      if (_firebaseUser == null) {
        _errorMessage = 'Erro ao criar conta';
        notifyListeners();
        return false;
      }

      // Inicializa a criptografia com o UID do usuário
      await EncryptionService.instance.onUserLogin(_firebaseUser!.uid);

      // Atualiza o nome do usuário
      await _firebaseUser!.updateDisplayName(name);
      
      // Cria documento do usuário no Firestore
      final newUser = UserModel(
        name: name,
        email: email,
      );
      
      await _usersCollection.doc(_firebaseUser!.uid).set(newUser.toMap());
      debugPrint('Usuário salvo no Firebase com UID: ${_firebaseUser!.uid}');

      _user = newUser;
      _isLoggedIn = true;

      debugPrint('Registro concluído com sucesso!');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Erro Firebase Auth: ${e.code} - ${e.message}');
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
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
      debugPrint('Tentando login com email: $email');
      
      // Faz login no Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _firebaseUser = userCredential.user;
      
      if (_firebaseUser == null) {
        _errorMessage = 'Erro ao fazer login';
        notifyListeners();
        return false;
      }

      // Inicializa a criptografia com o UID do usuário
      await EncryptionService.instance.onUserLogin(_firebaseUser!.uid);

      // Busca dados do usuário no Firestore
      final doc = await _usersCollection.doc(_firebaseUser!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        _user = UserModel.fromMap(data);
      }
      
      _isLoggedIn = true;
      debugPrint('Login bem sucedido!');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Erro Firebase Auth: ${e.code} - ${e.message}');
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Erro ao fazer login: $e');
      _errorMessage = 'Erro ao fazer login. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _errorMessage = null;
    
    // Validação básica do email
    if (email.isEmpty) {
      _errorMessage = 'Por favor, insira seu e-mail';
      notifyListeners();
      return false;
    }
    
    final trimmedEmail = email.trim().toLowerCase();
    
    // Validação de formato de email
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      _errorMessage = 'E-mail inválido. Verifique o formato.';
      notifyListeners();
      return false;
    }
    
    // Rate limiting - verifica se pode fazer nova tentativa
    final now = DateTime.now();
    if (_lastResetAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastResetAttempt!);
      
      // Se passou o tempo de cooldown, reseta o contador
      if (timeSinceLastAttempt >= _resetCooldown) {
        _resetAttemptCount = 0;
      } else if (_resetAttemptCount >= _maxResetAttempts) {
        // Ainda em cooldown e excedeu tentativas
        final remainingTime = _resetCooldown - timeSinceLastAttempt;
        final minutes = remainingTime.inMinutes;
        final seconds = remainingTime.inSeconds % 60;
        _errorMessage = 'Muitas tentativas. Aguarde ${minutes}m ${seconds}s.';
        notifyListeners();
        return false;
      }
    }
    
    // Registra a tentativa
    _lastResetAttempt = now;
    _resetAttemptCount++;
    
    try {
      // Envia email de redefinição de senha
      debugPrint('Tentando enviar email de redefinição para: $trimmedEmail (tentativa $_resetAttemptCount/$_maxResetAttempts)');
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
      debugPrint('Email de redefinição de senha enviado com sucesso para: $trimmedEmail');
      
      // Sucesso - reseta o contador após envio bem-sucedido
      _resetAttemptCount = 0;
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Erro Firebase Auth: ${e.code} - ${e.message}');
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Erro ao redefinir senha: $e');
      debugPrint('Tipo do erro: ${e.runtimeType}');
      
      // Tenta extrair código de erro do Firebase
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('user-not-found') || errorString.contains('user not found')) {
        _errorMessage = 'E-mail não encontrado. Verifique se está correto ou crie uma conta.';
      } else if (errorString.contains('invalid-email') || errorString.contains('invalid email')) {
        _errorMessage = 'E-mail inválido. Verifique o formato.';
      } else if (errorString.contains('too-many-requests')) {
        _errorMessage = 'Muitas tentativas. Aguarde alguns minutos.';
        // Firebase também limita - reseta nosso contador
        _resetAttemptCount = _maxResetAttempts;
      } else if (errorString.contains('network')) {
        _errorMessage = 'Erro de conexão. Verifique sua internet.';
        // Não conta como tentativa válida
        _resetAttemptCount--;
      } else {
        _errorMessage = 'Erro ao enviar email. Tente novamente.';
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({String? name, String? email, String? photoUrl}) async {
    if (_user == null || _firebaseUser == null) return;

    try {
      // Atualiza no Firebase Auth
      if (name != null) {
        await _firebaseUser!.updateDisplayName(name);
      }
      if (photoUrl != null) {
        await _firebaseUser!.updatePhotoURL(photoUrl);
      }

      final updatedUser = _user!.copyWith(
        name: name ?? _user!.name,
        email: email ?? _user!.email,
        photoUrl: photoUrl ?? _user!.photoUrl,
      );

      // Atualiza no Firestore
      await _usersCollection.doc(_firebaseUser!.uid).update(updatedUser.toMap());
      
      _user = updatedUser;
      debugPrint('Perfil atualizado no Firebase');
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao atualizar perfil: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      EncryptionService.instance.onUserLogout();
      _isLoggedIn = false;
      _user = null;
      _firebaseUser = null;
      debugPrint('Logout realizado com sucesso');
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao fazer logout: $e');
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado';
      case 'invalid-email':
        return 'E-mail inválido';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres';
      case 'user-not-found':
        return 'E-mail não encontrado. Crie uma conta primeiro.';
      case 'wrong-password':
        return 'Senha incorreta';
      case 'invalid-credential':
        return 'E-mail ou senha incorretos';
      case 'user-disabled':
        return 'Esta conta foi desativada';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Erro de autenticação. Tente novamente.';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
