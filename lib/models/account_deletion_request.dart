class AccountDeletionRequest {
  final String id;
  final String userId;
  final String? userName;
  final String reason;
  final String status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccountDeletionRequest({
    required this.id,
    required this.userId,
    this.userName,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    try {
      return AccountDeletionRequest(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        userName: json['user_profile']?['full_name'],
        reason: json['reason'] ?? '',
        status: json['status'] ?? 'pending',
        requestedAt: json['requested_at'] != null
            ? DateTime.parse(json['requested_at'])
            : DateTime.now(),
        processedAt: json['processed_at'] != null
            ? DateTime.parse(json['processed_at'])
            : null,
        processedBy: json['processed_by'],
        adminNotes: json['admin_notes'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      print('Error parsing JSON: $e');
      print('JSON data: $json');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
