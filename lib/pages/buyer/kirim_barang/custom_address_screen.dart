import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../theme/app_theme.dart';

class CustomAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;
  final Function(Map<String, dynamic>) onAddressSaved;

  CustomAddressScreen({
    this.initialAddress,
    required this.onAddressSaved,
  });

  @override
  _CustomAddressScreenState createState() => _CustomAddressScreenState();
}

class _CustomAddressScreenState extends State<CustomAddressScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  LatLng _currentPosition = LatLng(-6.2088, 106.8456); // Default Jakarta
  LatLng _selectedPosition = LatLng(-6.2088, 106.8456);
  String _currentAddress = 'Memuat alamat...';
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showMap = true; // Tambahkan state untuk show/hide map
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    
    if (widget.initialAddress != null) {
      _loadInitialAddress();
    }
  }

  void _loadInitialAddress() {
    final address = widget.initialAddress!;
    if (address['latitude'] != null && address['longitude'] != null) {
      final lat = double.parse(address['latitude'].toString());
      final lng = double.parse(address['longitude'].toString());
      _selectedPosition = LatLng(lat, lng);
      _currentPosition = LatLng(lat, lng);
    }
    
    _streetController.text = address['street'] ?? '';
    _noteController.text = address['note'] ?? '';
    _updateAddress(_selectedPosition);
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    
    try {
      // Cek permission location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        // Dapatkan lokasi current
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          if (widget.initialAddress == null) {
            _selectedPosition = _currentPosition;
          }
        });

        // Update alamat jika tidak ada initial address
        if (widget.initialAddress == null) {
          await _updateAddress(_selectedPosition);
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      // Gunakan lokasi default Jakarta jika gagal
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _updateAddress(LatLng position) async {
    try {
      // Gunakan Nominatim OpenStreetMap untuk reverse geocoding
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'KumblyApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          _currentAddress = data['display_name'] ?? 'Alamat tidak ditemukan';
        });
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
      setState(() {
        _currentAddress = 'Gagal memuat alamat';
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) return;

    setState(() => _isSearching = true);

    try {
      // Gunakan Nominatim untuk search
      final url = 'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=id&limit=5&addressdetails=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'KumblyApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        setState(() {
          _searchResults = results.map((result) => {
            'display_name': result['display_name'],
            'lat': double.parse(result['lat']),
            'lng': double.parse(result['lon']),
            'address': result['address'] ?? {},
          }).toList();
        });
      }
    } catch (e) {
      print('Error searching: $e');
    }

    setState(() => _isSearching = false);
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final newPosition = LatLng(result['lat'], result['lng']);
    
    setState(() {
      _selectedPosition = newPosition;
      _currentAddress = result['display_name'];
      _searchResults.clear();
      _searchController.clear();
    });

    _mapController.move(newPosition, 16.0);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPosition = point;
    });
    _updateAddress(point);
  }

  void _moveToCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final newPosition = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentPosition = newPosition;
        _selectedPosition = newPosition;
      });

      _mapController.move(newPosition, 16.0);
      await _updateAddress(newPosition);
    } catch (e) {
      print('Error getting current location: $e');
      Get.snackbar(
        'Error',
        'Gagal mendapatkan lokasi saat ini',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _saveAddress() {
    if (_streetController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Nama jalan/alamat detail harus diisi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final addressData = {
      'street': _streetController.text.trim(),
      'village': '',
      'district': '',
      'city': '',
      'province': '',
      'postal_code': '',
      'latitude': _selectedPosition.latitude.toString(),
      'longitude': _selectedPosition.longitude.toString(),
      'note': _noteController.text.trim(),
      'full_address': _currentAddress,
      'is_custom': true,
    };

    widget.onAddressSaved(addressData);
    Get.back(result: addressData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Lokasi'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _saveAddress,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari alamat...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _isSearching 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length >= 3) {
                      _searchAddress(value);
                    } else {
                      setState(() => _searchResults.clear());
                    }
                  },
                ),
                // Search results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(
                            result['display_name'],
                            style: TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Tombol show/hide map
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showMap = !_showMap;
                    });
                  },
                  icon: Icon(_showMap ? Icons.visibility_off : Icons.map),
                  label: Text(_showMap ? 'Sembunyikan Peta' : 'Tampilkan Peta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, 36),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),

          // Map (show/hide dan kecilkan tinggi default)
          if (_showMap)
            SizedBox(
              height: 220, // Ukuran peta diperkecil
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPosition,
                      initialZoom: 16.0,
                      onTap: _onMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.kumbly.ecommerce',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPosition,
                            child: Container(
                              child: Icon(
                                Icons.location_pin,
                                color: AppTheme.primary,
                                size: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: AppTheme.primary,
                      onPressed: _moveToCurrentLocation,
                      child: _isLoading 
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.my_location, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Address details form
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Alamat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 12),
                    
                    // Current address display
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        _currentAddress,
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Street/detail address input
                    TextField(
                      controller: _streetController,
                      decoration: InputDecoration(
                        labelText: 'Nama Jalan / Detail Alamat *',
                        hintText: 'Contoh: Jl. Sudirman No. 123',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Note input
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Contoh: Dekat minimarket, rumah cat biru',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saveAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Simpan Alamat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _streetController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
