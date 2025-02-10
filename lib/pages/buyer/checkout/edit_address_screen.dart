import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class EditAddressScreen extends StatefulWidget {
  final String initialAddress;
  final Function(Map<String, dynamic>) onSave;

  EditAddressScreen({required this.initialAddress, required this.onSave});

  @override
  _EditAddressScreenState createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  LatLng selectedLocation = LatLng(-6.200000, 106.816666);
  final mapController = MapController();
  String selectedAddress = '';
  bool isLoading = false;
  TextEditingController searchController = TextEditingController();
  Map<String, String> addressDetails = {
    "city": "",
    "street": "",
    "village": "",
    "district": "",
    "latitude": "",
    "province": "",
    "longitude": "",
    "postal_code": ""
  };

  @override
  void initState() {
    super.initState();
    // Set alamat awal dan cari lokasinya
    selectedAddress = widget.initialAddress;
    if (widget.initialAddress.isNotEmpty) {
      searchLocation(widget.initialAddress);
    }
  }

  Future<void> getCurrentLocation() async {
    setState(() => isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      LatLng currentLocation = LatLng(position.latitude, position.longitude);
      setState(() => selectedLocation = currentLocation);
      mapController.move(currentLocation, 16.0);
      await getAddressFromLatLng(currentLocation);
    } catch (e) {
      print('Error getting current location: $e');
      Get.snackbar(
        'Error',
        'Tidak dapat mengakses lokasi terkini',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> getAddressFromLatLng(LatLng position) async {
    setState(() => isLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        addressDetails = {
          "city": place.subAdministrativeArea ?? "",
          "street": place.street ?? "",
          "village": place.subLocality ?? "",
          "district": place.locality ?? "",
          "latitude": position.latitude.toString(),
          "province": place.administrativeArea ?? "",
          "longitude": position.longitude.toString(),
          "postal_code": place.postalCode ?? ""
        };

        selectedAddress =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.subAdministrativeArea}';
        setState(() {});
      }
    } catch (e) {
      print('Error getting address: $e');
      selectedAddress = 'Gagal mendapatkan alamat';
    }
    setState(() => isLoading = false);
  }

  Future<void> searchLocation(String query) async {
    setState(() => isLoading = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        LatLng newLocation = LatLng(location.latitude, location.longitude);
        setState(() => selectedLocation = newLocation);
        mapController.move(newLocation, 16.0);
        await getAddressFromLatLng(newLocation);
        searchController.text = query; // Set teks pencarian
      }
    } catch (e) {
      print('Error searching location: $e');
      Get.snackbar(
        'Error',
        'Lokasi tidak ditemukan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Lokasi Alamat',
            style: TextStyle(color: Colors.black, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari alamat...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                fillColor: Colors.grey[50],
                filled: true,
              ),
              onSubmitted: (value) => searchLocation(value),
            ),
          ),
          // Tambahkan tombol untuk mendapatkan lokasi terkini
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: ElevatedButton.icon(
              onPressed: getCurrentLocation,
              icon: Icon(Icons.my_location, color: Colors.white),
              label: Text('Gunakan Lokasi Saat Ini',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: selectedLocation,
                    initialZoom: 16.0,
                    onTap: (tapPosition, latLng) {
                      setState(() => selectedLocation = latLng);
                      getAddressFromLatLng(latLng);
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
                          width: 40.0,
                          height: 40.0,
                          point: selectedLocation,
                          child: Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                // Zoom controls
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            double currentZoom = mapController.camera.zoom;
                            mapController.move(
                                selectedLocation, currentZoom + 1);
                          },
                        ),
                        Divider(height: 1),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            double currentZoom = mapController.camera.zoom;
                            mapController.move(
                                selectedLocation, currentZoom - 1);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (isLoading)
                  Container(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Alamat Terpilih',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  selectedAddress.isEmpty
                      ? 'Pilih lokasi di peta'
                      : selectedAddress,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedAddress.isEmpty
                        ? null
                        : () {
                            widget.onSave(addressDetails);
                            Get.back(result: addressDetails);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Gunakan Alamat Ini',
                        style: TextStyle(color: Colors.white)),
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
