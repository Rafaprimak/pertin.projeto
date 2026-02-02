class Trip {
  final int? id;
  final String name;
  final String originName;
  final double originLat;
  final double originLng;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final DateTime startTime;
  final DateTime? endTime;
  final bool completed;
  final double? distance;
  final List<TripExpense> expenses;

  Trip({
    this.id,
    required this.name,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.startTime,
    this.endTime,
    this.completed = false,
    this.distance,
    this.expenses = const [],
  });

  double get totalExpenses {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Trip copyWith({
    int? id,
    String? name,
    String? originName,
    double? originLat,
    double? originLng,
    String? destinationName,
    double? destinationLat,
    double? destinationLng,
    DateTime? startTime,
    DateTime? endTime,
    bool? completed,
    double? distance,
    List<TripExpense>? expenses,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      originName: originName ?? this.originName,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationName: destinationName ?? this.destinationName,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      completed: completed ?? this.completed,
      distance: distance ?? this.distance,
      expenses: expenses ?? this.expenses,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'originName': originName,
      'originLat': originLat,
      'originLng': originLng,
      'destinationName': destinationName,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'completed': completed ? 1 : 0,
      'distance': distance,
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map, {List<TripExpense>? expenses}) {
    List<TripExpense> expensesList = expenses ?? [];
    if (map['expenses'] != null && expenses == null) {
      expensesList = (map['expenses'] as List)
          .map((e) => TripExpense.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    
    return Trip(
      id: map['id'],
      name: map['name'] ?? '',
      originName: map['originName'] ?? '',
      originLat: (map['originLat'] ?? 0).toDouble(),
      originLng: (map['originLng'] ?? 0).toDouble(),
      destinationName: map['destinationName'] ?? '',
      destinationLat: (map['destinationLat'] ?? 0).toDouble(),
      destinationLng: (map['destinationLng'] ?? 0).toDouble(),
      startTime: map['startTime'] != null 
          ? DateTime.parse(map['startTime']) 
          : DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      completed: map['completed'] == 1 || map['completed'] == true,
      distance: map['distance']?.toDouble(),
      expenses: expensesList,
    );
  }
}

class TripExpense {
  final int? id;
  final int tripId;
  final String description;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;

  TripExpense({
    this.id,
    required this.tripId,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'description': description,
      'amount': amount,
      'category': category.name,
      'date': date.toIso8601String(),
    };
  }

  factory TripExpense.fromMap(Map<String, dynamic> map) {
    return TripExpense(
      id: map['id'],
      tripId: map['tripId'] ?? 0,
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ExpenseCategory.outros,
      ),
      date: map['date'] != null 
          ? DateTime.parse(map['date']) 
          : DateTime.now(),
    );
  }
}

enum ExpenseCategory {
  passagem,
  alimentacao,
  hospedagem,
  transporte,
  entretenimento,
  outros,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get displayName {
    switch (this) {
      case ExpenseCategory.passagem:
        return 'Passagem';
      case ExpenseCategory.alimentacao:
        return 'Alimentação';
      case ExpenseCategory.hospedagem:
        return 'Hospedagem';
      case ExpenseCategory.transporte:
        return 'Transporte';
      case ExpenseCategory.entretenimento:
        return 'Entretenimento';
      case ExpenseCategory.outros:
        return 'Outros';
    }
  }

  String get icon {
    switch (this) {
      case ExpenseCategory.passagem:
        return '🎫';
      case ExpenseCategory.alimentacao:
        return '🍔';
      case ExpenseCategory.hospedagem:
        return '🏨';
      case ExpenseCategory.transporte:
        return '🚕';
      case ExpenseCategory.entretenimento:
        return '🎮';
      case ExpenseCategory.outros:
        return '📦';
    }
  }
}
