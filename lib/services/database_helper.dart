import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pertin/models/trip.dart';
import 'package:pertin/models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static FirebaseFirestore? _firestore;

  DatabaseHelper._init();

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  // Collections
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      firestore.collection('users');
  
  CollectionReference<Map<String, dynamic>> get _tripsCollection =>
      firestore.collection('trips');
  
  CollectionReference<Map<String, dynamic>> get _expensesCollection =>
      firestore.collection('expenses');

  // User operations
  Future<String> insertUser(UserModel user) async {
    final docRef = await _usersCollection.add(user.toMap());
    return docRef.id;
  }

  Future<UserModel?> getUser() async {
    final snapshot = await _usersCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return UserModel.fromMap(data);
    }
    return null;
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await _usersCollection.doc(id).get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return UserModel.fromMap(data);
    }
    return null;
  }

  Future<void> updateUser(UserModel user) async {
    if (user.id != null) {
      await _usersCollection.doc(user.id.toString()).update(user.toMap());
    }
  }

  Future<void> updateUserById(String id, UserModel user) async {
    await _usersCollection.doc(id).update(user.toMap());
  }

  // Trip operations
  Future<String> insertTrip(Trip trip) async {
    final tripData = trip.toMap();
    tripData.remove('expenses'); // Expenses são armazenadas separadamente
    tripData.remove('id');
    final docRef = await _tripsCollection.add(tripData);
    return docRef.id;
  }

  Future<List<Trip>> getAllTrips() async {
    final tripSnapshot = await _tripsCollection
        .orderBy('startTime', descending: true)
        .get();
    
    List<Trip> trips = [];
    for (var doc in tripSnapshot.docs) {
      final tripData = doc.data();
      tripData['id'] = doc.id;
      
      // Buscar expenses da viagem
      final expenseSnapshot = await _expensesCollection
          .where('tripId', isEqualTo: doc.id)
          .get();
      
      final expenses = expenseSnapshot.docs.map((expDoc) {
        final expData = expDoc.data();
        expData['id'] = expDoc.id;
        return TripExpense.fromMap(expData);
      }).toList();
      
      trips.add(Trip.fromMap(tripData, expenses: expenses));
    }
    return trips;
  }

  Future<Trip?> getTrip(String id) async {
    final doc = await _tripsCollection.doc(id).get();
    if (doc.exists) {
      final tripData = doc.data()!;
      tripData['id'] = doc.id;
      
      // Buscar expenses da viagem
      final expenseSnapshot = await _expensesCollection
          .where('tripId', isEqualTo: id)
          .get();
      
      final expenses = expenseSnapshot.docs.map((expDoc) {
        final expData = expDoc.data();
        expData['id'] = expDoc.id;
        return TripExpense.fromMap(expData);
      }).toList();
      
      return Trip.fromMap(tripData, expenses: expenses);
    }
    return null;
  }

  Future<Trip?> getTripByIntId(int id) async {
    // Busca por campo 'id' numérico se existir, ou usa o primeiro resultado
    final snapshot = await _tripsCollection
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return getTrip(snapshot.docs.first.id);
    }
    return null;
  }

  Future<void> updateTrip(Trip trip) async {
    if (trip.id != null) {
      final tripData = trip.toMap();
      tripData.remove('expenses');
      tripData.remove('id');
      await _tripsCollection.doc(trip.id.toString()).update(tripData);
    }
  }

  Future<void> updateTripById(String id, Trip trip) async {
    final tripData = trip.toMap();
    tripData.remove('expenses');
    tripData.remove('id');
    await _tripsCollection.doc(id).update(tripData);
  }

  Future<void> deleteTrip(String id) async {
    // Deletar expenses associadas
    final expenseSnapshot = await _expensesCollection
        .where('tripId', isEqualTo: id)
        .get();
    
    for (var doc in expenseSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Deletar a viagem
    await _tripsCollection.doc(id).delete();
  }

  Future<void> deleteTripByIntId(int id) async {
    final snapshot = await _tripsCollection
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      await deleteTrip(snapshot.docs.first.id);
    }
  }

  // Expense operations
  Future<String> insertExpense(TripExpense expense) async {
    final expenseData = expense.toMap();
    expenseData.remove('id');
    final docRef = await _expensesCollection.add(expenseData);
    return docRef.id;
  }

  Future<List<TripExpense>> getExpensesForTrip(String tripId) async {
    final snapshot = await _expensesCollection
        .where('tripId', isEqualTo: tripId)
        .orderBy('date', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TripExpense.fromMap(data);
    }).toList();
  }

  Future<List<TripExpense>> getExpensesForTripByIntId(int tripId) async {
    final snapshot = await _expensesCollection
        .where('tripId', isEqualTo: tripId)
        .orderBy('date', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TripExpense.fromMap(data);
    }).toList();
  }

  Future<List<TripExpense>> getAllExpenses() async {
    final snapshot = await _expensesCollection
        .orderBy('date', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TripExpense.fromMap(data);
    }).toList();
  }

  Future<void> deleteExpense(String id) async {
    await _expensesCollection.doc(id).delete();
  }

  Future<void> deleteExpenseByIntId(int id) async {
    final snapshot = await _expensesCollection
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
    }
  }

  Future<Map<String, double>> getExpensesByCategory() async {
    final snapshot = await _expensesCollection.get();
    
    Map<String, double> categoryTotals = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final category = data['category'] as String;
      final amount = (data['amount'] as num).toDouble();
      
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }
    return categoryTotals;
  }

  Future<double> getTotalExpenses() async {
    final snapshot = await _expensesCollection.get();
    
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['amount'] as num).toDouble();
    }
    return total;
  }

  // Método para compatibilidade - não é necessário fechar conexão Firestore
  Future<void> close() async {
    // Firebase Firestore gerencia conexões automaticamente
  }
}
