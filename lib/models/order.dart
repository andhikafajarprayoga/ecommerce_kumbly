class Order {
  final String id;
  final String buyerId;
  final String status;
  final double totalAmount;
  final String shippingAddress;
  final DateTime createdAt;
  final int? paymentMethodId;
  final String? merchantId;
  final String? paymentGroupId;
  final double shippingCost;
  final String? courierHandoverPhoto;

  Order({
    required this.id,
    required this.buyerId,
    required this.status,
    required this.totalAmount,
    required this.shippingAddress,
    required this.createdAt,
    this.paymentMethodId,
    this.merchantId,
    this.paymentGroupId,
    required this.shippingCost,
    this.courierHandoverPhoto,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      buyerId: json['buyer_id'],
      status: json['status'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      shippingAddress: json['shipping_address'],
      createdAt: DateTime.parse(json['created_at']),
      paymentMethodId: json['payment_method_id'],
      merchantId: json['merchant_id'],
      paymentGroupId: json['payment_group_id'],
      shippingCost: (json['shipping_cost'] as num).toDouble(),
      courierHandoverPhoto: json['courier_handover_photo'],
    );
  }
}
