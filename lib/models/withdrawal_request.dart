class WithdrawalRequest {
  final String id;
  final String merchantId;
  final String? merchantName;
  final String bankAccountId;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final double amount;
  final double feeAmount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? transferProofUrl;

  WithdrawalRequest({
    required this.id,
    required this.merchantId,
    this.merchantName,
    required this.bankAccountId,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    required this.amount,
    required this.feeAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.transferProofUrl,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequest(
      id: json['id'],
      merchantId: json['merchant_id'],
      merchantName: json['merchants']?['store_name'],
      bankAccountId: json['bank_account_id'],
      bankName: json['bank_accounts']?['bank_name'],
      accountNumber: json['bank_accounts']?['account_number'],
      accountHolder: json['bank_accounts']?['account_holder'],
      amount: (json['amount'] as num).toDouble(),
      feeAmount: (json['fee_amount'] as num).toDouble(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.parse(json['created_at']),
      transferProofUrl: json['transfer_proof_url'],
    );
  }
}
