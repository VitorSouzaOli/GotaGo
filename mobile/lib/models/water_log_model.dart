class WaterLogModel {
  final String id;
  final int amount;
  final DateTime createdAt;

  WaterLogModel({
    required this.id,
    required this.amount,
    required this.createdAt,
  });

  factory WaterLogModel.fromJson(Map<String, dynamic> json) {
    return WaterLogModel(
      id: json['id'] ?? '',
      amount: (json['amount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  WaterLogModel copyWith({int? amount, DateTime? createdAt}) {
    return WaterLogModel(
      id: id,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
