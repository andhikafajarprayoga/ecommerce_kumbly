import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class HotelBookingScreen extends StatefulWidget {
  final Map<String, dynamic> hotel;
  final Map<String, dynamic> roomType;

  const HotelBookingScreen({
    Key? key,
    required this.hotel,
    required this.roomType,
  }) : super(key: key);

  @override
  _HotelBookingScreenState createState() => _HotelBookingScreenState();
}

class _HotelBookingScreenState extends State<HotelBookingScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedCheckIn;
  DateTime? _selectedCheckOut;
  int _totalNights = 0;
  double _totalPrice = 0;

  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  final _specialRequestController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCheckIn = DateTime.now();
    _selectedCheckOut = DateTime.now().add(Duration(days: 1));
    _calculateTotal();
  }

  void _calculateTotal() {
    if (_selectedCheckIn != null && _selectedCheckOut != null) {
      _totalNights = _selectedCheckOut!.difference(_selectedCheckIn!).inDays;
      _totalPrice =
          (_totalNights * widget.roomType['price_per_night']).toDouble();
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        Get.snackbar(
          'Error',
          'Silakan login terlebih dahulu',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      await supabase.from('hotel_bookings').insert({
        'hotel_id': widget.hotel['id'],
        'user_id': userId,
        'room_type': widget.roomType['type'],
        'check_in': _selectedCheckIn!.toIso8601String(),
        'check_out': _selectedCheckOut!.toIso8601String(),
        'total_nights': _totalNights,
        'total_price': _totalPrice,
        'guest_name': _guestNameController.text,
        'guest_phone': _guestPhoneController.text,
        'special_requests': _specialRequestController.text,
        'status': 'pending'
      });

      Get.snackbar(
        'Sukses',
        'Booking berhasil dibuat',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal membuat booking: $e',
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
        title: Text('Booking Hotel'),
        backgroundColor: AppTheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Hotel & Room Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hotel['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tipe Kamar: ${widget.roomType['type']}',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Harga per malam: ${NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(widget.roomType['price_per_night'])}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Calendar
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Tanggal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(Duration(days: 365)),
                      focusedDay: _selectedCheckIn ?? DateTime.now(),
                      selectedDayPredicate: (day) {
                        if (_selectedCheckIn == null ||
                            _selectedCheckOut == null) return false;
                        return day.isAtSameMomentAs(_selectedCheckIn!) ||
                            day.isAtSameMomentAs(_selectedCheckOut!);
                      },
                      rangeStartDay: _selectedCheckIn,
                      rangeEndDay: _selectedCheckOut,
                      calendarFormat: CalendarFormat.month,
                      rangeSelectionMode: RangeSelectionMode.enforced,
                      onRangeSelected: (start, end, focusedDay) {
                        setState(() {
                          _selectedCheckIn = start;
                          _selectedCheckOut = end;
                          if (start != null && end != null) {
                            _calculateTotal();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Guest Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Tamu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _guestNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _guestPhoneController,
                      decoration: InputDecoration(
                        labelText: 'Nomor Telepon',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nomor telepon tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _specialRequestController,
                      decoration: InputDecoration(
                        labelText: 'Permintaan Khusus (Opsional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Total
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rincian Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Malam'),
                        Text('$_totalNights malam'),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Pembayaran'),
                        Text(
                          NumberFormat.currency(
                            locale: 'id',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(_totalPrice),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Booking Sekarang',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
