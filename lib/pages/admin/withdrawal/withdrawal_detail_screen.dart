import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../controllers/withdrawal_controller.dart';
import '../../../models/withdrawal_request.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class WithdrawalDetailScreen extends StatelessWidget {
  final WithdrawalRequest request;
  final WithdrawalController controller = Get.find<WithdrawalController>();

  WithdrawalDetailScreen({super.key, required this.request});

  // Hitung jumlah yang harus ditransfer
  double get transferAmount => request.amount - request.feeAmount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pencairan',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMerchantInfo(),
            const SizedBox(height: 16),
            _buildAmountSummary(),
            const SizedBox(height: 16),
            _buildBankInfo(),
            const SizedBox(height: 16),
            _buildStatusInfo(),
            const SizedBox(height: 16),
            if (request.status == 'pending') _buildActionButtons(),
            if (request.status == 'approved' &&
                request.transferProofUrl == null)
              _buildUploadProofButton(),
            if (request.transferProofUrl != null) _buildTransferProof(),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Merchant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.store,
                    color: Color.fromARGB(255, 119, 119, 119), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.merchantName ?? 'Nama Toko tidak tersedia',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.numbers,
                    color: Color.fromARGB(255, 85, 85, 85), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ID: ${request.id}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rincian Pencairan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildAmountRow(
              'Jumlah Pencairan',
              request.amount,
              isTotal: false,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            _buildAmountRow(
              'Biaya Admin',
              request.feeAmount,
              isDeduction: true,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(thickness: 2),
            ),
            _buildAmountRow(
              'Total Transfer',
              transferAmount,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount,
      {bool isDeduction = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDeduction ? Colors.red : Colors.black87,
          ),
        ),
        Text(
          '${isDeduction ? "- " : ""}${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(amount)}',
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDeduction ? Colors.red : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    Color statusColor;
    IconData statusIcon;

    switch (request.status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Status: ${request.status.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tanggal Pengajuan: ${DateFormat('dd MMMM yyyy, HH:mm').format(request.createdAt)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Bank',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.bankName ?? 'Bank tidak tersedia',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.credit_card, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                        text: request.accountNumber ?? '',
                      ));
                      Get.snackbar(
                        'Sukses',
                        'Nomor rekening berhasil disalin',
                        duration: const Duration(seconds: 2),
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.accountNumber ??
                                'Nomor rekening tidak tersedia',
                            style: const TextStyle(
                              fontSize: 15,
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Icon(Icons.copy, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.accountHolder ?? 'Nama pemilik tidak tersedia',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final phone = _getPhoneNumber();
                      if (phone != null) {
                        _launchWhatsApp(phone);
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getPhoneNumber() ?? 'Nomor telepon tidak tersedia',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (_getPhoneNumber() != null)
                          const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            size: 20,
                            color: Color(0xFF25D366),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _getPhoneNumber() {
    print(
        "informationMerchant value: ${request.informationMerchant}"); // Debug print raw value

    if (request.informationMerchant == null) return null;

    final phonePattern = RegExp(r'Telepon Toko:\s*(\d+)');
    final match = phonePattern.firstMatch(request.informationMerchant!);

    if (match != null) {
      print(
          "Phone number found: ${match.group(1)}"); // Debug print extracted number
      return match.group(1);
    }
    print("No phone number match found in the text"); // Debug print if no match
    return null;
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showConfirmationDialog('approve'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Setujui', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showConfirmationDialog('reject'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProofButton() {
    return ElevatedButton.icon(
      onPressed: () => _uploadTransferProof(),
      icon: const Icon(Icons.upload_file),
      label: const Text('Upload Bukti Transfer'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTransferProof() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bukti Transfer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Image.network(
              request.transferProofUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(String action) {
    Get.dialog(
      AlertDialog(
        title:
            Text(action == 'approve' ? 'Setujui Pencairan' : 'Tolak Pencairan'),
        content: Text(
          action == 'approve'
              ? 'Anda yakin ingin menyetujui pencairan ini?'
              : 'Anda yakin ingin menolak pencairan ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.updateWithdrawalStatus(
                request.id,
                action == 'approve' ? 'approved' : 'rejected',
              );
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadTransferProof() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      controller.uploadTransferProof(request.id, image);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    String whatsappUrl =
        "https://wa.me/${phone.replaceAll(RegExp(r'[^\d+]'), '')}";
    try {
      await launchUrl(Uri.parse(whatsappUrl));
    } catch (e) {
      Get.snackbar(
        'Error',
        'Tidak dapat membuka WhatsApp',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
