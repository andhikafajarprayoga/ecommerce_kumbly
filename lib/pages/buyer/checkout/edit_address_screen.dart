import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';

class EditAddressScreen extends StatefulWidget {
  final String initialAddress;
  final Function(String) onSave;

  EditAddressScreen({required this.initialAddress, required this.onSave});

  @override
  _EditAddressScreenState createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  LatLng selectedLocation =
      LatLng(-6.200000, 106.816666); // Default lokasi (Jakarta)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi Pengiriman'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: selectedLocation,
                initialZoom: 15.0,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    selectedLocation = latLng;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 50.0,
                      height: 50.0,
                      point: selectedLocation,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                // Simpan alamat yang baru dengan koordinat yang dipilih
                widget.onSave(
                    'Lokasi baru: Lat: ${selectedLocation.latitude}, Lon: ${selectedLocation.longitude}');
                Get.back(); // Kembali ke halaman Checkout
              },
              child: const Text('Simpan Lokasi'),
            ),
          ),
        ],
      ),
    );
  }
}
