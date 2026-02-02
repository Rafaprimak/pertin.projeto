import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pertin/models/trip.dart';
export 'package:pertin/models/trip.dart' show Trip, TripStatus, TripStatusExtension, TripExpense, ExpenseCategory, ExpenseCategoryExtension;
import 'package:pertin/services/encryption_service.dart';

class TripProvider extends ChangeNotifier {
  List<Trip> _trips = [];
  Trip? _activeTrip;
  bool _isLoading = false;
  bool _isInitialized = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EncryptionService _encryption = EncryptionService.instance;

  // Campos sensíveis que serão criptografados
  static const List<String> _sensitiveFields = ['name', 'originName', 'destinationName'];

  List<Trip> get trips => _trips;
  Trip? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;

  List<Trip> get completedTrips => _trips.where((t) => t.status == TripStatus.concluida).toList();
  List<Trip> get pendingTrips => _trips.where((t) => t.status == TripStatus.emAndamento).toList();
  List<Trip> get cancelledTrips => _trips.where((t) => t.status == TripStatus.cancelada).toList();
  List<Trip> get postponedTrips => _trips.where((t) => t.status == TripStatus.adiada).toList();
  List<Trip> get scheduledTrips => _trips.where((t) => t.status == TripStatus.agendada).toList();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Retorna a referência para a coleção de viagens do usuário atual.
  /// Estrutura: users/{userId}/trips
  CollectionReference<Map<String, dynamic>>? get _userTripsCollection {
    if (_currentUserId == null) return null;
    return _firestore.collection('users').doc(_currentUserId).collection('trips');
  }

  /// Retorna a referência para a coleção de despesas de uma viagem específica.
  /// Estrutura: users/{userId}/trips/{tripId}/expenses
  CollectionReference<Map<String, dynamic>>? _tripExpensesCollection(String tripId) {
    if (_currentUserId == null) return null;
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('trips')
        .doc(tripId)
        .collection('expenses');
  }

  Future<void> loadTrips() async {
    if (_isInitialized) {
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    notifyListeners();

    try {
      if (_currentUserId == null || _userTripsCollection == null) {
        debugPrint('Usuário não autenticado, não é possível carregar viagens');
        _trips = [];
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      debugPrint('Carregando viagens do Firebase para usuário: $_currentUserId');
      
      // Busca viagens do usuário (subcoleção)
      final tripSnapshot = await _userTripsCollection!
          .orderBy('startTime', descending: true)
          .get();
      
      _trips = [];
      for (var doc in tripSnapshot.docs) {
        var tripData = doc.data();
        tripData['id'] = doc.id;
        
        // Descriptografa dados sensíveis
        tripData = _encryption.decryptMap(tripData, _sensitiveFields);
        
        // Buscar expenses da viagem (subcoleção da viagem)
        final expensesCollection = _tripExpensesCollection(doc.id);
        if (expensesCollection != null) {
          final expenseSnapshot = await expensesCollection
              .orderBy('date', descending: true)
              .get();
          
          final expenses = expenseSnapshot.docs.map((expDoc) {
            var expData = expDoc.data();
            expData['id'] = expDoc.id;
            expData['tripId'] = doc.id;
            // Descriptografa descrição da despesa
            expData = _encryption.decryptMap(expData, ['description']);
            return TripExpense.fromMap(expData);
          }).toList();
          
          _trips.add(Trip.fromMap(tripData, expenses: expenses));
        } else {
          _trips.add(Trip.fromMap(tripData));
        }
      }
      
      debugPrint('Viagens carregadas do Firebase: ${_trips.length}');
      
      // Restaura a viagem ativa (em andamento) se existir
      final activeTrips = _trips.where((t) => t.status == TripStatus.emAndamento).toList();
      if (activeTrips.isNotEmpty) {
        _activeTrip = activeTrips.first;
        debugPrint('Viagem ativa restaurada: ${_activeTrip?.name}');
      }
    } catch (e) {
      debugPrint('Erro ao carregar viagens do Firebase: $e');
      _trips = [];
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  /// Força recarregamento das viagens (útil após login)
  Future<void> reloadTrips() async {
    _isInitialized = false;
    await loadTrips();
  }

  /// Cria uma nova viagem com passagem opcional.
  /// Se scheduledStartTime for fornecido, a viagem será agendada para o futuro.
  Future<Trip?> createTrip({
    required String name,
    required String originName,
    required double originLat,
    required double originLng,
    required String destinationName,
    required double destinationLat,
    required double destinationLng,
    double? ticketPrice, // Valor da passagem (opcional)
    DateTime? scheduledStartTime, // Data/hora agendada (opcional)
  }) async {
    if (_currentUserId == null || _userTripsCollection == null) {
      debugPrint('Usuário não autenticado');
      return null;
    }

    final isScheduled = scheduledStartTime != null && scheduledStartTime.isAfter(DateTime.now());
    final status = isScheduled ? TripStatus.agendada : TripStatus.emAndamento;

    try {
      var tripData = {
        'name': name,
        'originName': originName,
        'originLat': originLat,
        'originLng': originLng,
        'destinationName': destinationName,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'startTime': DateTime.now().toIso8601String(),
        'scheduledStartTime': scheduledStartTime?.toIso8601String(),
        'completed': false,
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Criptografa dados sensíveis antes de salvar
      final encryptedTripData = _encryption.encryptMap(tripData, _sensitiveFields);

      // Salva viagem no Firebase (subcoleção do usuário)
      final docRef = await _userTripsCollection!.add(encryptedTripData);
      debugPrint('Viagem salva no Firebase com ID: ${docRef.id}');
      
      tripData['id'] = docRef.id;
      
      List<TripExpense> expenses = [];
      
      // Se tiver valor da passagem, cria despesa automaticamente
      if (ticketPrice != null && ticketPrice > 0) {
        var expenseData = {
          'tripId': docRef.id,
          'description': 'Passagem - $name',
          'amount': ticketPrice,
          'category': ExpenseCategory.passagem.name,
          'date': DateTime.now().toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        // Criptografa descrição da despesa
        final encryptedExpenseData = _encryption.encryptMap(expenseData, ['description']);
        
        final expensesCollection = _tripExpensesCollection(docRef.id);
        if (expensesCollection != null) {
          final expenseRef = await expensesCollection.add(encryptedExpenseData);
          expenseData['id'] = expenseRef.id;
          expenses.add(TripExpense.fromMap(expenseData));
          debugPrint('Despesa de passagem criada: R\$ $ticketPrice');
        }
      }
      
      final trip = Trip.fromMap(tripData, expenses: expenses);

      _trips.insert(0, trip);
      _activeTrip = trip;

      notifyListeners();
      return trip;
    } catch (e) {
      debugPrint('Erro ao criar viagem no Firebase: $e');
      return null;
    }
  }

  Future<void> completeTrip(dynamic tripId, {double? distance}) async {
    final tripIdStr = tripId.toString();
    final index = _trips.indexWhere((t) => t.id.toString() == tripIdStr);
    if (index == -1 || _userTripsCollection == null) return;

    try {
      final updatedTrip = _trips[index].copyWith(
        completed: true,
        endTime: DateTime.now(),
        distance: distance,
        status: TripStatus.concluida,
      );

      // Atualiza no Firebase
      await _userTripsCollection!.doc(tripIdStr).update({
        'completed': true,
        'endTime': DateTime.now().toIso8601String(),
        'distance': distance,
        'status': TripStatus.concluida.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Viagem completada no Firebase');

      _trips[index] = updatedTrip;
      
      if (_activeTrip?.id.toString() == tripIdStr) {
        _activeTrip = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao completar viagem no Firebase: $e');
    }
  }

  /// Atualiza o status de uma viagem.
  Future<bool> updateTripStatus(dynamic tripId, TripStatus newStatus) async {
    final tripIdStr = tripId.toString();
    final index = _trips.indexWhere((t) => t.id.toString() == tripIdStr);
    if (index == -1 || _userTripsCollection == null) return false;

    try {
      final bool shouldMarkCompleted = newStatus == TripStatus.concluida;
      final bool shouldClearActiveTrip = newStatus == TripStatus.cancelada || 
                                          newStatus == TripStatus.concluida ||
                                          newStatus == TripStatus.adiada;

      final updatedTrip = _trips[index].copyWith(
        status: newStatus,
        completed: shouldMarkCompleted ? true : _trips[index].completed,
        endTime: shouldMarkCompleted ? DateTime.now() : _trips[index].endTime,
      );

      // Atualiza no Firebase
      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (shouldMarkCompleted) {
        updateData['completed'] = true;
        updateData['endTime'] = DateTime.now().toIso8601String();
      }

      await _userTripsCollection!.doc(tripIdStr).update(updateData);
      
      debugPrint('Status da viagem atualizado para: ${newStatus.displayName}');

      _trips[index] = updatedTrip;
      
      if (shouldClearActiveTrip && _activeTrip?.id.toString() == tripIdStr) {
        _activeTrip = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erro ao atualizar status da viagem: $e');
      return false;
    }
  }

  /// Inicia uma viagem agendada antecipadamente.
  /// Retorna a viagem atualizada se bem-sucedido, null caso contrário.
  Future<Trip?> startScheduledTrip(dynamic tripId) async {
    final tripIdStr = tripId.toString();
    final index = _trips.indexWhere((t) => t.id.toString() == tripIdStr);
    if (index == -1 || _userTripsCollection == null) return null;

    final trip = _trips[index];
    if (trip.status != TripStatus.agendada) {
      debugPrint('Viagem não está agendada, não pode ser iniciada');
      return null;
    }

    try {
      final now = DateTime.now();
      final updatedTrip = trip.copyWith(
        status: TripStatus.emAndamento,
        startTime: now,
      );

      // Atualiza no Firebase
      await _userTripsCollection!.doc(tripIdStr).update({
        'status': TripStatus.emAndamento.name,
        'startTime': now.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Viagem agendada iniciada antecipadamente');

      _trips[index] = updatedTrip;
      _activeTrip = updatedTrip;

      notifyListeners();
      return updatedTrip;
    } catch (e) {
      debugPrint('Erro ao iniciar viagem agendada: $e');
      return null;
    }
  }

  void setActiveTrip(Trip? trip) {
    _activeTrip = trip;
    notifyListeners();
  }

  Future<void> deleteTrip(dynamic tripId) async {
    final tripIdStr = tripId.toString();
    if (_userTripsCollection == null) return;
    
    try {
      // Deletar todas as expenses da viagem (subcoleção)
      final expensesCollection = _tripExpensesCollection(tripIdStr);
      if (expensesCollection != null) {
        final expenseSnapshot = await expensesCollection.get();
        for (var doc in expenseSnapshot.docs) {
          await doc.reference.delete();
        }
      }
      
      // Deletar a viagem
      await _userTripsCollection!.doc(tripIdStr).delete();
      
      debugPrint('Viagem e despesas deletadas do Firebase');

      _trips.removeWhere((t) => t.id.toString() == tripIdStr);
      
      if (_activeTrip?.id.toString() == tripIdStr) {
        _activeTrip = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao deletar viagem do Firebase: $e');
    }
  }

  /// Adiciona uma nova despesa a uma viagem.
  Future<TripExpense?> addExpense({
    required dynamic tripId,
    required String description,
    required double amount,
    required ExpenseCategory category,
    DateTime? date,
  }) async {
    if (_currentUserId == null) {
      debugPrint('Usuário não autenticado');
      return null;
    }

    final tripIdStr = tripId.toString();
    final index = _trips.indexWhere((t) => t.id.toString() == tripIdStr);
    if (index == -1) return null;

    try {
      final expensesCollection = _tripExpensesCollection(tripIdStr);
      if (expensesCollection == null) return null;

      var expenseData = {
        'tripId': tripIdStr,
        'description': description,
        'amount': amount,
        'category': category.name,
        'date': (date ?? DateTime.now()).toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Criptografa descrição antes de salvar
      final encryptedData = _encryption.encryptMap(expenseData, ['description']);

      // Salva no Firebase (subcoleção da viagem)
      final docRef = await expensesCollection.add(encryptedData);
      debugPrint('Despesa salva no Firebase com ID: ${docRef.id}');
      
      expenseData['id'] = docRef.id;
      final expense = TripExpense.fromMap(expenseData);

      final updatedExpenses = [..._trips[index].expenses, expense];
      _trips[index] = _trips[index].copyWith(expenses: updatedExpenses);

      // Atualiza a viagem ativa se for a mesma viagem
      if (_activeTrip?.id == tripIdStr) {
        _activeTrip = _trips[index];
      }

      notifyListeners();
      return expense;
    } catch (e) {
      debugPrint('Erro ao adicionar despesa no Firebase: $e');
      return null;
    }
  }

  /// Edita uma despesa existente.
  Future<bool> updateExpense({
    required dynamic tripId,
    required dynamic expenseId,
    String? description,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
  }) async {
    final tripIdStr = tripId.toString();
    final expenseIdStr = expenseId.toString();
    final tripIndex = _trips.indexWhere((t) => t.id.toString() == tripIdStr);
    if (tripIndex == -1) return false;

    final expenseIndex = _trips[tripIndex].expenses
        .indexWhere((e) => e.id.toString() == expenseIdStr);
    if (expenseIndex == -1) return false;

    try {
      final expensesCollection = _tripExpensesCollection(tripIdStr);
      if (expensesCollection == null) return false;

      final currentExpense = _trips[tripIndex].expenses[expenseIndex];
      
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Criptografa descrição se fornecida
      if (description != null) {
        updateData['description'] = _encryption.encrypt(description);
      }
      if (amount != null) updateData['amount'] = amount;
      if (category != null) updateData['category'] = category.name;
      if (date != null) updateData['date'] = date.toIso8601String();

      // Atualiza no Firebase
      await expensesCollection.doc(expenseIdStr).update(updateData);
      debugPrint('Despesa atualizada no Firebase');

      // Atualiza localmente
      final updatedExpense = TripExpense(
        id: expenseIdStr,
        tripId: tripIdStr,
        description: description ?? currentExpense.description,
        amount: amount ?? currentExpense.amount,
        category: category ?? currentExpense.category,
        date: date ?? currentExpense.date,
      );

      final updatedExpenses = List<TripExpense>.from(_trips[tripIndex].expenses);
      updatedExpenses[expenseIndex] = updatedExpense;
      _trips[tripIndex] = _trips[tripIndex].copyWith(expenses: updatedExpenses);

      // Atualiza a viagem ativa se for a mesma viagem
      if (_activeTrip?.id == tripIdStr) {
        _activeTrip = _trips[tripIndex];
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erro ao atualizar despesa no Firebase: $e');
      return false;
    }
  }

  /// Deleta uma despesa.
  Future<void> deleteExpense(dynamic tripId, dynamic expenseId) async {
    final tripIdStr = tripId.toString();
    final expenseIdStr = expenseId.toString();
    final index = _trips.indexWhere((t) => t.id.toString() == tripIdStr);
    if (index == -1) return;

    try {
      final expensesCollection = _tripExpensesCollection(tripIdStr);
      if (expensesCollection == null) return;

      // Deleta do Firebase
      await expensesCollection.doc(expenseIdStr).delete();
      debugPrint('Despesa deletada do Firebase');

      final updatedExpenses = _trips[index].expenses
          .where((e) => e.id.toString() != expenseIdStr)
          .toList();
      _trips[index] = _trips[index].copyWith(expenses: updatedExpenses);

      // Atualiza a viagem ativa se for a mesma viagem
      if (_activeTrip?.id == tripIdStr) {
        _activeTrip = _trips[index];
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao deletar despesa do Firebase: $e');
    }
  }

  Trip? getTripById(dynamic id) {
    final idStr = id.toString();
    try {
      return _trips.firstWhere((t) => t.id.toString() == idStr);
    } catch (e) {
      return null;
    }
  }

  TripExpense? getExpenseById(dynamic tripId, dynamic expenseId) {
    final trip = getTripById(tripId);
    if (trip == null) return null;
    
    try {
      return trip.expenses.firstWhere((e) => e.id.toString() == expenseId.toString());
    } catch (e) {
      return null;
    }
  }

  double get totalExpenses {
    return _trips.fold(0.0, (sum, trip) => sum + trip.totalExpenses);
  }

  Map<ExpenseCategory, double> get expensesByCategory {
    Map<ExpenseCategory, double> result = {};
    for (var trip in _trips) {
      for (var expense in trip.expenses) {
        result[expense.category] = (result[expense.category] ?? 0) + expense.amount;
      }
    }
    return result;
  }

  Map<String, double> get monthlyExpenses {
    Map<String, double> result = {};
    for (var trip in _trips) {
      for (var expense in trip.expenses) {
        final key = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
        result[key] = (result[key] ?? 0) + expense.amount;
      }
    }
    return result;
  }

  /// Limpa dados ao fazer logout
  void clearData() {
    _trips = [];
    _activeTrip = null;
    _isInitialized = false;
    notifyListeners();
  }
}
