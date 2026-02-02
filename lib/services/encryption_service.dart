import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Serviço de criptografia para proteger dados sensíveis do usuário.
/// Usa XOR com chave derivada do UID do usuário.
class EncryptionService {
  static EncryptionService? _instance;
  static EncryptionService get instance => _instance ??= EncryptionService._();

  EncryptionService._();

  String? _encryptionKey;
  String? _currentUserId;
  static const String _keyStorageKey = 'encryption_key_v2';

  /// Inicializa o serviço de criptografia.
  /// A chave é derivada do UID do usuário para garantir consistência.
  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _initWithUserId(user.uid);
      debugPrint('EncryptionService inicializado para usuário: ${user.uid}');
    } else {
      // Sem usuário logado, não inicializa a chave
      // A chave será inicializada quando o usuário fizer login
      _encryptionKey = null;
      _currentUserId = null;
      debugPrint('EncryptionService: aguardando login do usuário');
    }
  }

  /// Inicializa com o UID do usuário específico.
  /// Isso garante que a mesma chave seja usada em qualquer dispositivo.
  Future<void> _initWithUserId(String userId) async {
    if (_currentUserId == userId && _encryptionKey != null) {
      return; // Já inicializado para este usuário
    }

    _currentUserId = userId;
    // Deriva a chave do UID do usuário usando SHA-256
    // Isso garante que o mesmo usuário sempre tenha a mesma chave
    final keySource = 'pertin_key_$userId';
    final keyBytes = sha256.convert(utf8.encode(keySource)).bytes;
    _encryptionKey = base64Encode(keyBytes);

    debugPrint('Chave de criptografia inicializada para usuário: $userId');
  }

  /// Atualiza a chave quando o usuário faz login.
  Future<void> onUserLogin(String userId) async {
    await _initWithUserId(userId);
  }

  /// Limpa a chave quando o usuário faz logout.
  void onUserLogout() {
    _encryptionKey = null;
    _currentUserId = null;
  }

  /// Gera uma chave segura de 256 bits.
  String _generateSecureKey() {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(keyBytes);
  }

  /// Criptografa um texto usando XOR com a chave.
  /// Em produção, use um pacote como encrypt ou pointycastle para AES real.
  String encrypt(String plainText) {
    if (_encryptionKey == null) {
      debugPrint(
        'EncryptionService: chave não inicializada, retornando texto sem criptografar',
      );
      return plainText;
    }

    // Não criptografa strings vazias ou muito curtas
    if (plainText.isEmpty || plainText.length < 2) {
      return plainText;
    }

    try {
      final keyBytes = base64Decode(_encryptionKey!);
      final textBytes = utf8.encode(plainText);

      // XOR encryption (para demo - em produção use AES)
      final encryptedBytes = <int>[];
      for (int i = 0; i < textBytes.length; i++) {
        encryptedBytes.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      // Adiciona hash para verificação de integridade
      final hash = sha256.convert(textBytes).bytes.sublist(0, 8);
      final combined = [...hash, ...encryptedBytes];

      return base64Encode(combined);
    } catch (e) {
      debugPrint('Erro ao criptografar: $e');
      return plainText;
    }
  }

  /// Descriptografa um texto criptografado.
  String decrypt(String encryptedText) {
    if (_encryptionKey == null) {
      debugPrint(
        'EncryptionService: chave não inicializada, retornando texto original',
      );
      return encryptedText;
    }

    // Strings vazias ou muito curtas não estão criptografadas
    if (encryptedText.isEmpty || encryptedText.length < 20) {
      return encryptedText;
    }

    try {
      final keyBytes = base64Decode(_encryptionKey!);
      final combined = base64Decode(encryptedText);

      // Precisa ter pelo menos hash (8 bytes) + dados
      if (combined.length < 9) {
        return encryptedText;
      }

      // Extrai hash e dados criptografados
      final storedHash = combined.sublist(0, 8);
      final encryptedBytes = combined.sublist(8);

      // XOR decryption
      final decryptedBytes = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      // Verifica integridade
      final computedHash = sha256.convert(decryptedBytes).bytes.sublist(0, 8);
      bool isValid = true;
      for (int i = 0; i < 8; i++) {
        if (storedHash[i] != computedHash[i]) {
          isValid = false;
          break;
        }
      }

      if (!isValid) {
        // Hash não corresponde - texto não foi criptografado com esta chave
        // Retorna o texto original (provavelmente não está criptografado)
        debugPrint('Aviso: Hash não corresponde, retornando texto original');
        return encryptedText;
      }

      final decoded = utf8.decode(decryptedBytes, allowMalformed: true);

      // Verifica se o resultado parece ser texto válido
      if (_containsOnlyValidChars(decoded)) {
        return decoded;
      } else {
        // Resultado não parece ser texto válido, retorna original
        return encryptedText;
      }
    } catch (e) {
      debugPrint('Erro ao descriptografar (pode não estar criptografado): $e');
      return encryptedText;
    }
  }

  /// Verifica se a string contém apenas caracteres válidos de texto.
  bool _containsOnlyValidChars(String text) {
    // Verifica se contém caracteres de controle inválidos
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Permite caracteres imprimíveis, espaços, tabs, newlines
      if (code < 32 && code != 9 && code != 10 && code != 13) {
        return false;
      }
    }
    return true;
  }

  /// Criptografa um Map de dados sensíveis.
  Map<String, dynamic> encryptMap(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) {
    final result = Map<String, dynamic>.from(data);

    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        final value = result[field];
        if (value is String) {
          result[field] = encrypt(value);
          result['${field}_encrypted'] = true;
        }
      }
    }

    return result;
  }

  /// Descriptografa um Map de dados sensíveis.
  Map<String, dynamic> decryptMap(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) {
    final result = Map<String, dynamic>.from(data);

    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        final value = result[field];
        if (value is String) {
          // Verifica se está marcado como criptografado OU se parece ser base64 válido
          final isMarkedEncrypted = result['${field}_encrypted'] == true;
          final looksEncrypted = _looksLikeEncrypted(value);

          if (isMarkedEncrypted || looksEncrypted) {
            final decrypted = decrypt(value);

            // Se o resultado ainda parece base64/criptografado ou é igual ao original,
            // significa que a descriptografia falhou - usa valor padrão
            if (decrypted == value ||
                _looksLikeEncrypted(decrypted) ||
                !_isReadableText(decrypted)) {
              result[field] = _getDefaultValueForField(field);
              debugPrint(
                'Campo "$field" com dados corrompidos, usando valor padrão',
              );
            } else {
              result[field] = decrypted;
            }
          }
        }
      }
      result.remove('${field}_encrypted');
    }

    return result;
  }

  /// Verifica se o texto é legível (contém caracteres normais de texto).
  bool _isReadableText(String text) {
    if (text.isEmpty) return true;

    // Conta quantos caracteres são "normais" (letras, números, espaços, pontuação comum)
    int normalChars = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Espaço, letras, números, pontuação comum, acentos
      if ((code >= 32 && code <= 126) || // ASCII básico
          (code >= 192 && code <= 255) || // Acentos Latin-1
          code == 9 ||
          code == 10 ||
          code == 13) {
        // Tab, newline
        normalChars++;
      }
    }

    // Se mais de 80% dos caracteres são normais, considera legível
    return normalChars / text.length > 0.8;
  }

  /// Retorna um valor padrão para um campo baseado no nome.
  String _getDefaultValueForField(String fieldName) {
    switch (fieldName) {
      case 'name':
        return 'Viagem';
      case 'originName':
        return 'Origem';
      case 'destinationName':
        return 'Destino';
      case 'description':
        return 'Sem descrição';
      default:
        return 'Dado indisponível';
    }
  }

  /// Verifica se um texto parece estar criptografado (base64 com hash).
  bool _looksLikeEncrypted(String value) {
    try {
      // Texto criptografado é base64 e tem pelo menos 8 bytes de hash + algum conteúdo
      final decoded = base64Decode(value);
      // Mínimo: 8 bytes de hash + 1 byte de dados
      if (decoded.length >= 9) {
        // Verifica se não contém caracteres comuns de texto normal
        // (textos normais geralmente não são base64 válido com esse formato)
        return !value.contains(' ') && value.length > 20;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Verifica se um texto parece ser dados criptografados inválidos/corrompidos.
  /// Retorna true se parece ser base64 mas não pode ser descriptografado.
  bool isCorruptedEncryptedData(String value) {
    if (value.isEmpty || value.length < 20) return false;

    // Verifica se parece base64 mas não contém caracteres normais de texto
    if (!value.contains(' ') && !value.contains(',')) {
      try {
        base64Decode(value);
        // É base64 válido - provavelmente criptografado
        // Tenta descriptografar para ver se funciona
        final decrypted = decrypt(value);
        // Se retornou o mesmo valor, não conseguiu descriptografar
        return decrypted == value && _looksLikeEncrypted(value);
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Limpa um texto que parece estar corrompido, retornando um valor padrão.
  String cleanCorruptedData(String value, String defaultValue) {
    if (isCorruptedEncryptedData(value)) {
      debugPrint(
        'Dados corrompidos detectados, usando valor padrão: $defaultValue',
      );
      return defaultValue;
    }
    return value;
  }

  /// Gera um hash seguro de uma senha (para armazenamento local).
  String hashPassword(String password, String salt) {
    final combined = '$password:$salt';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Gera um salt aleatório.
  String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }
}
