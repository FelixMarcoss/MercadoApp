class Purchase {
  final int? id;
  final String date;
  final double totalValue;
  final String url;
  final bool isAvulsa;
  final bool isPublic;

  Purchase({
    this.id,
    required this.date,
    required this.totalValue,
    required this.url,
    this.isAvulsa = false,
    this.isPublic = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'total_value': totalValue,
      'url': url,
      'avulsa': isAvulsa ? 1 : 0,
      'is_public': isPublic ? 1 : 0,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'],
      date: map['date'],
      totalValue: map['total_value'],
      url: map['url'],
      isAvulsa: map['avulsa'] == 1,
      isPublic: map['is_public'] == 1,
    );
  }
}
