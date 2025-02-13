import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import '../../../controllers/account_deletion_controller.dart';
import '../../../models/account_deletion_request.dart';

class AccountDeletionScreen extends StatelessWidget {
  final AccountDeletionController controller =
      Get.put(AccountDeletionController());

  AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permintaan Hapus Akun',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = controller.filteredRequests;
              if (requests.isEmpty) {
                return const Center(
                  child: Text('Tidak ada permintaan penghapusan akun'),
                );
              }

              return ListView.builder(
                itemCount: requests.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _showDetailDialog(request),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.userName ??
                                            'Nama tidak tersedia',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusChip(request.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Alasan: ${request.reason}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Diajukan: ${DateFormat('dd MMM yyyy, HH:mm').format(request.requestedAt)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) => controller.searchQuery.value = value,
        decoration: InputDecoration(
          hintText: 'Cari berdasarkan nama atau email...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showDetailDialog(AccountDeletionRequest request) {
    final TextEditingController notesController =
        TextEditingController(text: request.adminNotes);

    Get.dialog(
      AlertDialog(
        title: const Text('Detail Permintaan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nama: ${request.userName ?? "Tidak tersedia"}'),
              const SizedBox(height: 8),
              Text('Alasan: ${request.reason}'),
              const SizedBox(height: 8),
              Text('Status: ${request.status.toUpperCase()}'),
              Text(
                  'Tanggal Pengajuan: ${DateFormat('dd MMM yyyy, HH:mm').format(request.requestedAt)}'),
              if (request.processedAt != null)
                Text(
                    'Diproses pada: ${DateFormat('dd MMM yyyy, HH:mm').format(request.processedAt!)}'),
              const SizedBox(height: 16),
              if (request.status == 'pending') ...[
                const Text('Catatan Admin:'),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan catatan...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else if (request.adminNotes != null) ...[
                const Text('Catatan Admin:'),
                Text(request.adminNotes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tutup'),
          ),
          if (request.status == 'pending') ...[
            TextButton(
              onPressed: () {
                Get.defaultDialog(
                    title: 'Konfirmasi Penolakan',
                    middleText:
                        'Apakah Anda yakin ingin menolak permintaan ini?',
                    textConfirm: 'Ya',
                    textCancel: 'Tidak',
                    confirmTextColor: Colors.white,
                    onConfirm: () {
                      Get.back();
                      Get.back();
                      controller.processRequest(
                        request.id,
                        'rejected',
                        notesController.text,
                      );
                    });
              },
              child: const Text('Tolak', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Get.defaultDialog(
                    title: 'Konfirmasi Persetujuan',
                    middleText:
                        'Setelah disetujui, akun akan ditandai untuk penghapusan dan akan dihapus oleh admin secara manual dari database.',
                    textConfirm: 'Ya',
                    textCancel: 'Tidak',
                    confirmTextColor: Colors.white,
                    onConfirm: () {
                      Get.back();
                      Get.back();
                      controller.processRequest(
                        request.id,
                        'approved',
                        notesController.text,
                      );
                    });
              },
              child:
                  const Text('Setujui', style: TextStyle(color: Colors.green)),
            ),
          ],
        ],
      ),
    );
  }
}
