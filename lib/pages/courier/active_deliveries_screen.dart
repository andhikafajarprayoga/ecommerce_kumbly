import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/active_delivery_controller.dart';
import 'package:intl/intl.dart';
import '../../models/active_delivery.dart';

class ActiveDeliveriesScreen extends StatelessWidget {
  final controller = Get.put(ActiveDeliveryController());

  ActiveDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daftar Pengiriman'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Diproses'),
              Tab(text: 'Dikirim'),
              Tab(text: 'Diterima'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
              Tab(text: 'Minta Batal'),
            ],
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              _buildDeliveryList(controller.pendingDeliveries),
              _buildDeliveryList(controller.processingDeliveries),
              _buildDeliveryList(controller.shippingDeliveries),
              _buildDeliveryList(controller.deliveredDeliveries),
              _buildDeliveryList(controller.completedDeliveries),
              _buildDeliveryList(controller.cancelledDeliveries),
              _buildDeliveryList(controller.pendingCancellationDeliveries),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDeliveryList(List<ActiveDelivery> deliveries) {
    if (deliveries.isEmpty) {
      return const Center(
        child: Text('Tidak ada pengiriman'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(
              'Order #${delivery.id.substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pembeli: ${delivery.buyerName ?? "Tidak tersedia"}'),
                Text('Penjual: ${delivery.merchantName ?? "Tidak tersedia"}'),
                Text('Alamat: ${delivery.shippingAddress}'),
                Text(
                    'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(delivery.totalAmount)}'),
                Text('Status: ${delivery.status}'),
              ],
            ),
            trailing: delivery.status == 'shipping'
                ? IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () {
                      // Implementasi upload foto bukti pengiriman
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}
