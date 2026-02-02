import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pertin/models/trip.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripProvider extends ChangeNotifier {
  List<Trip> _trips = [];
  Trip? _activeTrip;
  bool _isLoading = false;
  bool _isInitialized = false;

  List<Trip> get trips => _trips;
  Trip? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;

  List<Trip> get completedTrips => _trips.where((t) => t.completed).toList();
  List<Trip> get pendingTrips => _trips.where((t) => !t.completed).toList();

  Future<void> loadTrips() async {
    if (_isInitialized) {
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final tripsJson = prefs.getStringList('trips') ?? [];
      
      _trips = tripsJson.map((json) {
        final map = jsonDecode(json);
        return Trip.fromMap(map);
      }).toList();
      
      // Ordenar por data mais recente
      _trips.sort((a, b) => b.startTime.compareTo(a.startTime));
    } catch (e) {
      debugPrint('Erro ao carregar viagens: $e');
      _trips = [];
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripsJson = _trips.map((trip) => jsonEncode(trip.toMap())).toList();
      await prefs.setStringList('trips', tripsJson);
    } catch (e) {
      debugPrint('Erro ao salvar viagens: $e');
    }
  }

  Future<Trip?> createTrip({
    required String name,
    required String originName,
    required double originLat,
    required double originLng,
    required String destinationName,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final trip = Trip(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      originName: originName,
      originLat: originLat,
      originLng: originLng,
      destinationName: destinationName,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      startTime: DateTime.now(),
    );

    _trips.insert(0, trip);
    _activeTrip = trip;
    await _saveTrips();

    notifyListeners();
    return trip;
  }

  Future<void> completeTrip(int tripId, {double? distance}) async {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;

    final updatedTrip = _trips[index].copyWith(
      completed: true,
      endTime: DateTime.now(),
      distance: distance,
    );

    _trips[index] = updatedTrip;
    
    if (_activeTrip?.id == tripId) {
      _activeTrip = null;
    }

    await _saveTrips();
    notifyListeners();
  }

  void setActiveTrip(Trip? trip) {
    _activeTrip = trip;
    notifyListeners();
  }

  Future<void> deleteTrip(int tripId) async {
    _trips.removeWhere((t) => t.id == tripId);
    
    if (_activeTrip?.id == tripId) {
      _activeTrip = null;
    }

    await _saveTrips();
    notifyListeners();
  }

  Future<void> addExpense({
    required int tripId,
    required String description,
    required double amount,
    required ExpenseCategory category,
  }) async {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;

    final expense = TripExpense(
      id: DateTime.now().millisecondsSinceEpoch,
      tripId: tripId,
      description: description,
      amount: amount,
      category: category,
      date: DateTime.now(),
    );

    final updatedExpenses = [..._trips[index].expenses, expense];
    _trips[index] = _trips[index].copyWith(expenses: updatedExpenses);

    await _saveTrips();
    notifyListeners();
  }

  Future<void> deleteExpense(int tripId, int expenseId) async {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;

    final updatedExpenses = _trips[index].expenses.where((e) => e.id != expenseId).toList();
    _trips[index] = _trips[index].copyWith(expenses: updatedExpenses);

    await _saveTrips();
    notifyListeners();
  }

  Trip? getTripById(int id) {
    try {
      return _trips.firstWhere((t) => t.id == id);
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
}
