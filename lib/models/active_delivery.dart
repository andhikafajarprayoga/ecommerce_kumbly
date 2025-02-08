class ActiveDelivery {
  final String id;
  final String? courierId;
  final String buyerId;
  final String? buyerName;
  final String merchantId;
  final String? merchantName;
  final String status;
  final double totalAmount;
  final String shippingAddress;
  final double shippingCost;
  final String? courierHandoverPhoto;
  final DateTime createdAt;
  final String? merchantAddress;
  final String? merchantPhone;

  ActiveDelivery({
    required this.id,
    this.courierId,
    required this.buyerId,
    this.buyerName,
    required this.merchantId,
    this.merchantName,
    required this.status,
    required this.totalAmount,
    required this.shippingAddress,
    required this.shippingCost,
    this.courierHandoverPhoto,
    required this.createdAt,
    this.merchantAddress,
    this.merchantPhone,
  });

  factory ActiveDelivery.fromJson(Map<String, dynamic> json) {
    print('=== PARSING JSON ===');
    print('ID: ${json['id']}');
    print('Courier ID Raw: ${json['courier_id']}');
    print('Courier ID Type: ${json['courier_id']?.runtimeType}');

    final merchant = json['merchant'] ?? {};
    final buyer = json['buyer'] as Map<String, dynamic>?;

    return ActiveDelivery(
      id: json['id'],
      courierId: json['courier_id']?.toString(),
      buyerId: json['buyer_id'],
      buyerName: buyer?['full_name'],
      merchantId: json['merchant_id'] ?? '',
      merchantName: merchant['store_name'],
      status: json['status'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      shippingAddress: json['shipping_address'],
      shippingCost: (json['shipping_cost'] as num).toDouble(),
      courierHandoverPhoto: json['courier_handover_photo'],
      createdAt: DateTime.parse(json['created_at']),
      merchantAddress: merchant['store_address'],
      merchantPhone: merchant['store_phone'],
    );
  }
}
