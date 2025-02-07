import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2; // Tambahkan alias
import 'hotel_management_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddEditHotelScreen extends StatefulWidget {
  final Map<String, dynamic>? hotel;

  const AddEditHotelScreen({Key? key, this.hotel}) : super(key: key);

  @override
  _AddEditHotelScreenState createState() => _AddEditHotelScreenState();
}

class _AddEditHotelScreenState extends State<AddEditHotelScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _facilitiesController = TextEditingController();

  List<String> _imageUrls = [];
  List<File> _newImages = [];
  bool _isLoading = false;

  // Tambahkan controller untuk koordinat
  double? _latitude;
  double? _longitude;
  String _selectedAddress = '';

  String _formatAddress(Map<String, dynamic> address) {
    try {
      return address['full_address'] ?? 'Alamat tidak tersedia';
    } catch (e) {
      print('Error formatting address: $e');
      return 'Alamat tidak tersedia';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.hotel != null) {
      _nameController.text = widget.hotel!['name'];
      _descriptionController.text = widget.hotel!['description'] ?? '';

      // Perbaiki cara mengakses alamat
      if (widget.hotel!['address'] is Map) {
        final address = widget.hotel!['address'] as Map<String, dynamic>;
        _selectedAddress = address['full_address'] ?? '';
        _addressController.text = _selectedAddress;
      }

      _facilitiesController.text = widget.hotel!['facilities'] != null
          ? (widget.hotel!['facilities'] as List).join(', ')
          : '';
      _imageUrls = List<String>.from(widget.hotel!['image_url'] ?? []);
      _latitude = widget.hotel!['latitude']?.toDouble();
      _longitude = widget.hotel!['longitude']?.toDouble();
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _latitude = _latitude ?? position.latitude;
          _longitude = _longitude ?? position.longitude;
        });
        if (_selectedAddress.isEmpty) {
          _getAddressFromLatLng();
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _getAddressFromLatLng() async {
    try {
      if (_latitude != null && _longitude != null) {
        setState(() => _isLoading = true);

        List<Placemark> placemarks = await placemarkFromCoordinates(
          _latitude!,
          _longitude!,
        ).timeout(
          Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Waktu pengambilan alamat habis');
          },
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _selectedAddress = [
              if (place.street?.isNotEmpty == true) place.street,
              if (place.subLocality?.isNotEmpty == true) place.subLocality,
              if (place.locality?.isNotEmpty == true) place.locality,
              if (place.subAdministrativeArea?.isNotEmpty == true)
                place.subAdministrativeArea,
              if (place.administrativeArea?.isNotEmpty == true)
                place.administrativeArea,
              if (place.postalCode?.isNotEmpty == true) place.postalCode,
            ].where((e) => e != null).join(', ');

            _addressController.text = _selectedAddress;
          });
        }
      }
    } on TimeoutException catch (_) {
      Get.snackbar(
        'Peringatan',
        'Waktu pengambilan alamat habis. Silakan coba lagi.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error getting address: $e');
      Get.snackbar(
        'Error',
        'Gagal mendapatkan alamat. Silakan coba lagi.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMapPicker() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final latlong2.LatLng? result = await Get.to(
        () => MapPicker(
          initialLocation: _latitude != null && _longitude != null
              ? latlong2.LatLng(_latitude!, _longitude!)
              : null,
        ),
      );

      if (result != null) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
        });
        await _getAddressFromLatLng();
      }
    } catch (e) {
      print('Error showing map: $e');
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.map((image) => File(image.path)));
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> uploadedUrls = [];

    for (File image in _newImages) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
      final response =
          await supabase.storage.from('hotel_images').upload(fileName, image);

      if (response.isNotEmpty) {
        final url =
            supabase.storage.from('hotel_images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  Future<void> _saveHotel() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      Get.snackbar(
        'Error',
        'Silakan pilih lokasi hotel pada peta terlebih dahulu',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final List<String> newImageUrls = await _uploadImages();
      final allImageUrls = [..._imageUrls, ...newImageUrls];

      final hotelData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'address': {
          'full_address': _selectedAddress,
        },
        'latitude': _latitude,
        'longitude': _longitude,
        'facilities': _facilitiesController.text
            .split(',')
            .where((facility) => facility.trim().isNotEmpty)
            .map((e) => e.trim())
            .toList(),
        'image_url': allImageUrls,
        'merchant_id': supabase.auth.currentUser!.id,
      };

      if (widget.hotel == null) {
        await supabase.from('hotels').insert(hotelData);
        Get.snackbar(
          'Sukses',
          'Hotel berhasil ditambahkan',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        await supabase
            .from('hotels')
            .update(hotelData)
            .eq('id', widget.hotel!['id']);
        Get.snackbar(
          'Sukses',
          'Hotel berhasil diupdate',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }

      // Kembali ke HotelManagementScreen
      Get.offAll(() => HotelManagementScreen());
    } catch (e) {
      print('Error saving hotel: $e');
      Get.snackbar(
        'Error',
        'Gagal menyimpan hotel: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hotel == null ? 'Tambah Hotel' : 'Edit Hotel',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Hotel',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama hotel tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Alamat',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.map),
                  onPressed: _showMapPicker,
                ),
              ),
              maxLines: 2,
              readOnly: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Alamat tidak boleh kosong';
                }
                return null;
              },
            ),

            if (_latitude != null && _longitude != null) ...[
              SizedBox(height: 8),
              Text(
                'Koordinat: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                style: TextStyle(color: Colors.grey),
              ),
            ],

            SizedBox(height: 16),

            TextFormField(
              controller: _facilitiesController,
              decoration: InputDecoration(
                labelText: 'Fasilitas (pisahkan dengan koma)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Image Preview
            if (_imageUrls.isNotEmpty || _newImages.isNotEmpty) ...[
              Text('Preview Gambar:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._imageUrls.map((url) => Padding(
                          padding: EdgeInsets.only(right: 8),
                          child:
                              Image.network(url, width: 100, fit: BoxFit.cover),
                        )),
                    ..._newImages.map((file) => Padding(
                          padding: EdgeInsets.only(right: 8),
                          child:
                              Image.file(file, width: 100, fit: BoxFit.cover),
                        )),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: Icon(Icons.add_photo_alternate),
              label: Text('Tambah Gambar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
            ),
            SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHotel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.hotel == null ? 'Tambah Hotel' : 'Update Hotel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tambahkan class MapPicker
class MapPicker extends StatefulWidget {
  final latlong2.LatLng? initialLocation;

  const MapPicker({Key? key, this.initialLocation}) : super(key: key);

  @override
  _MapPickerState createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  latlong2.LatLng? _selectedLocation;
  MapController mapController = MapController();
  final searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;

  Future<void> searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    try {
      final response = await http
          .get(Uri.parse(
              'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&countrycodes=id'))
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          searchResults = data
              .map<Map<String, dynamic>>((item) => {
                    'display_name': item['display_name'],
                    'lat': double.parse(item['lat']),
                    'lon': double.parse(item['lon']),
                  })
              .toList();
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mencari lokasi: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isSearching = false);
    }
  }

  void _moveToLocation(double lat, double lon) {
    final newLocation = latlong2.LatLng(lat, lon);
    setState(() => _selectedLocation = newLocation);
    mapController.move(newLocation, 15.0);
    // Clear search results after selection
    setState(() {
      searchResults = [];
      searchController.clear();
    });
  }

  void _moveToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );

        Position position = await Geolocator.getCurrentPosition();
        Get.back(); // Tutup loading

        final newLocation =
            latlong2.LatLng(position.latitude, position.longitude);
        setState(() => _selectedLocation = newLocation);

        mapController.move(newLocation, 15.0);
      }
    } catch (e) {
      Get.back(); // Tutup loading jika error
      Get.snackbar(
        'Error',
        'Gagal mendapatkan lokasi: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _zoomIn() {
    final currentZoom = mapController.camera.zoom;
    mapController.move(mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = mapController.camera.zoom;
    mapController.move(mapController.camera.center, currentZoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Lokasi'),
        backgroundColor: AppTheme.primary,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () => Get.back(result: _selectedLocation),
              child: Text('Pilih', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation ??
                  latlong2.LatLng(-6.200000, 106.816666),
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() => _selectedLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 80,
                      height: 80,
                      child: Icon(
                        Icons.location_pin,
                        color: AppTheme.primary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 80, // Give space for zoom controls
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari lokasi...',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      suffixIcon: isSearching
                          ? Container(
                              width: 20,
                              height: 20,
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            )
                          : searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() => searchResults = []);
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    onChanged: (value) {
                      if (value.length >= 3) {
                        searchLocation(value);
                      } else {
                        setState(() => searchResults = []);
                      }
                    },
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final result = searchResults[index];
                        return ListTile(
                          title: Text(
                            result['display_name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _moveToLocation(
                              result['lat'],
                              result['lon'],
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Zoom controls
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: _zoomIn,
                        color: AppTheme.primary,
                      ),
                      Container(
                        height: 1,
                        width: 24,
                        color: Colors.grey[300],
                      ),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: _zoomOut,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Location button
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _moveToCurrentLocation,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
