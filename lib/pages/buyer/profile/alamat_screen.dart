import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AlamatScreen extends StatefulWidget {
  const AlamatScreen({super.key});

  @override
  State<AlamatScreen> createState() => _AlamatScreenState();
}

class _AlamatScreenState extends State<AlamatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  String? address;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAddress();
  }

  Future<void> fetchAddress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('users')
          .select('address')
          .eq('id', userId)
          .single();

      setState(() {
        address = response['address'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar('Error', 'Gagal mengambil alamat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Saya')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alamat Anda:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: address),
                      readOnly: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    // Jika alamat belum ada, tampilkan tombol Tambah Alamat
                    if (address == null || address!.isEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Get.to(() => EditAddressScreen(
                                  initialAddress: '',
                                  onSave: (newAddress) {
                                    setState(() {
                                      address = newAddress;
                                    });
                                  },
                                ));
                          },
                          child: const Text('Tambah Alamat'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Get.to(() => EditAddressScreen(
                                  initialAddress: address!,
                                  onSave: (newAddress) {
                                    setState(() {
                                      address = newAddress;
                                    });
                                  },
                                ));
                          },
                          child: const Text('Edit Alamat'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Halaman Edit/Tambah Alamat dengan Peta
class EditAddressScreen extends StatefulWidget {
  final String initialAddress;
  final Function(String) onSave;

  const EditAddressScreen({
    super.key,
    required this.initialAddress,
    required this.onSave,
  });

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  late TextEditingController addressController;
  TextEditingController searchController = TextEditingController();
  LatLng selectedLocation = LatLng(-6.200000, 106.816666); // Default Jakarta
  double zoomLevel = 15.0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    addressController = TextEditingController(text: widget.initialAddress);
    if (widget.initialAddress.isEmpty) {
      fetchAddressFromCoordinates(selectedLocation);
    }
  }

  Future<void> fetchAddressFromCoordinates(LatLng latLng) async {
    setState(() {
      isLoading = true;
    });

    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'] ?? 'Alamat tidak ditemukan';

        setState(() {
          addressController.text = address;
        });
      }
    } catch (e) {
      Get.snackbar("Error", "Gagal mengambil nama jalan: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> searchAddress(String query) async {
    setState(() {
      isLoading = true;
    });

    final url =
        "https://nominatim.openstreetmap.org/search?format=json&q=$query";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final address = data[0]['display_name'];

          setState(() {
            selectedLocation = LatLng(lat, lon);
            addressController.text = address;
            zoomLevel = 16.0; // Zoom lebih dekat setelah mencari alamat
          });
        } else {
          Get.snackbar("Error", "Alamat tidak ditemukan.");
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Gagal mencari alamat: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveAddress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final newAddress = addressController.text;

      await supabase
          .from('users')
          .update({'address': newAddress}).eq('id', userId);

      widget.onSave(newAddress);
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Gagal menyimpan alamat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Lokasi Alamat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: "Cari alamat...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (searchController.text.isNotEmpty) {
                      searchAddress(searchController.text);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: selectedLocation,
                    initialZoom: zoomLevel,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        selectedLocation = latLng;
                      });
                      fetchAddressFromCoordinates(latLng);
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

                // Tombol Zoom In & Out
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoom_in",
                        onPressed: () {
                          setState(() {
                            zoomLevel += 1;
                          });
                        },
                        child: const Icon(Icons.zoom_in),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoom_out",
                        onPressed: () {
                          setState(() {
                            zoomLevel -= 1;
                          });
                        },
                        child: const Icon(Icons.zoom_out),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: addressController,
                  readOnly: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Alamat Terpilih',
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saveAddress,
                    child: const Text('Simpan Alamat'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
