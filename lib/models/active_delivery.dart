class ActiveDelivery {
  final String id;
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
    final merchant = json['merchant'] as Map<String, dynamic>?;

    return ActiveDelivery(
      id: json['id'],
      buyerId: json['buyer_id'],
      buyerName: json['buyer']?['full_name'],
      merchantId: json['merchant_id'] ?? '',
      merchantName: merchant?['store_name'],
      status: json['status'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      shippingAddress: json['shipping_address'],
      shippingCost: (json['shipping_cost'] as num).toDouble(),
      courierHandoverPhoto: json['courier_handover_photo'],
      createdAt: DateTime.parse(json['created_at']),
      merchantAddress: merchant?['store_address'],
      merchantPhone: merchant?['store_phone'],
    );
  }
}
