class WaterLogModel {
  final int amount;
  final DateTime createdAt;

  WaterLogModel({required this.amount, required this.createdAt});

  factory WaterLogModel.fromJson(Map<String, dynamic> json) {
    return WaterLogModel(
      amount: (json['amount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'amount': amount, 'createdAt': createdAt.toUtc().toIso8601String()};
  }
}
