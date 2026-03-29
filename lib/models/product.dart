class Product {
  final int? id;
  final int purchaseId;
  final String name;
  final double quantity;
  final String unitType;
  final double unitPrice;
  final double totalPrice;
  final String? date;
  final bool isAvulsa;
  final String? imagePath;

  Product({
    this.id,
    required this.purchaseId,
    required this.name,
    required this.quantity,
    required this.unitType,
    required this.unitPrice,
    required this.totalPrice,
    this.date,
    this.isAvulsa = false,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'name': name, 
      'quantity': quantity,
      'unit_type': unitType,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      // Date is usually fetched via joins, not inserted via product mapping directly
      // but good to include if it's there
      if (date != null) 'date': date,
      if (imagePath != null) 'image_path': imagePath,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      purchaseId: map['purchase_id'],
      name: map['name'],
      quantity: map['quantity'],
      unitType: map['unit_type'],
      unitPrice: map['unit_price'],
      totalPrice: map['total_price'],
      date: map['date'],
      isAvulsa: map['avulsa'] == 1,
      imagePath: map['image_path'],
    );
  }
}
