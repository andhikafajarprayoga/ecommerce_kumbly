import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'hotel_booking_detail_screen.dart';

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
  double _adminFee = 0;
  double _appFee = 0;
  double _totalWithAdmin = 0;

  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  final _specialRequestController = TextEditingController();

  bool _isLoading = false;
  int? selectedPaymentMethodId;
  List<Map<String, dynamic>> paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _selectedCheckIn = DateTime.now();
    _selectedCheckOut = DateTime.now().add(Duration(days: 1));
    _calculateTotal();
    fetchPaymentMethods();
    fetchAppFee();
  }

  void _calculateTotal() {
    if (_selectedCheckIn != null && _selectedCheckOut != null) {
      _totalNights = _selectedCheckOut!.difference(_selectedCheckIn!).inDays;
      _totalPrice =
          (_totalNights * widget.roomType['price_per_night']).toDouble();
      _calculateTotalWithAdmin();
    }
  }

  void _calculateTotalWithAdmin() {
    _totalWithAdmin = _totalPrice + _adminFee + _appFee;
  }

  Future<void> fetchPaymentMethods() async {
    try {
      final response = await supabase
          .from('payment_methods')
          .select('*, admin_fees(*)')
          .eq('is_active', true)
          .neq('name', 'COD')
          .order('name');

      setState(() {
        paymentMethods =
            (response as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('Error fetching payment methods: $e');
    }
  }

  Future<void> fetchAppFee() async {
    try {
      final response = await supabase
          .from('admin_fees')
          .select()
          .eq('is_active', true)
          .eq('name', 'Biaya Aplikasi')
          .maybeSingle();

      setState(() {
        _appFee = response != null ? (response['fee'] as num).toDouble() : 0;
        _calculateTotalWithAdmin();
      });
    } catch (e) {
      print('Error fetching app fee: $e');
      setState(() {
        _appFee = 0;
        _calculateTotalWithAdmin();
      });
    }
  }

  void _updateSelectedPaymentMethod(int? value) {
    if (value == null) return;

    setState(() {
      selectedPaymentMethodId = value;
      final selectedMethod =
          paymentMethods.firstWhere((method) => method['id'] == value);

      if (selectedMethod['admin_fees'] != null) {
        _adminFee = (selectedMethod['admin_fees']['fee'] as num).toDouble();
      } else {
        _adminFee = 0;
      }

      _calculateTotalWithAdmin();
    });
  }

  void _showConfirmationDialog() {
    if (selectedPaymentMethodId == null) {
      Get.snackbar(
        'Error',
        'Silakan pilih metode pembayaran',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon dan Title
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hotel_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Konfirmasi Booking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Rincian Booking
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildConfirmationRow(
                      'Hotel',
                      widget.hotel['name'],
                      Icons.business,
                    ),
                    Divider(height: 16),
                    _buildConfirmationRow(
                      'Tipe Kamar',
                      widget.roomType['type'],
                      Icons.hotel,
                    ),
                    Divider(height: 16),
                    _buildConfirmationRow(
                      'Total Pembayaran',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_totalWithAdmin),
                      Icons.payments,
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        await _submitBooking();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Konfirmasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildConfirmationRow(String label, String value, IconData icon,
      {bool isHighlighted = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isHighlighted ? AppTheme.primary : Colors.grey[600],
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isHighlighted ? FontWeight.bold : FontWeight.normal,
                  color: isHighlighted ? AppTheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final response = await supabase
          .from('hotel_bookings')
          .insert({
            'hotel_id': widget.hotel['id'],
            'user_id': supabase.auth.currentUser!.id,
            'room_type': widget.roomType['type'],
            'check_in': _selectedCheckIn!.toIso8601String(),
            'check_out': _selectedCheckOut!.toIso8601String(),
            'total_nights': _totalNights,
            'total_price': _totalPrice,
            'admin_fee': _adminFee,
            'app_fee': _appFee,
            'guest_name': _guestNameController.text,
            'guest_phone': _guestPhoneController.text,
            'special_requests': _specialRequestController.text,
            'payment_method_id': selectedPaymentMethodId,
            'status': 'pending'
          })
          .select()
          .single();

      print('Booking data: ${response.toString()}');

      Get.to(() => HotelBookingDetailScreen(booking: response));
    } catch (e) {
      print('Error submitting booking: $e');
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
        title: Text('Booking Hotel',
            style: TextStyle(
              color: Colors.white,
            )),
        backgroundColor: AppTheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Hotel & Room Info
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hotel['name'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.hotel, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Tipe Kamar: ${widget.roomType['type']}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.money, color: Colors.grey),
                        SizedBox(width: 8),
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

            // Payment Method Selection
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedPaymentMethodId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        hintText: 'Pilih metode pembayaran',
                      ),
                      items: paymentMethods.map((method) {
                        return DropdownMenuItem<int>(
                          value: method['id'],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(method['name']),
                              Text(
                                ' + ${NumberFormat.currency(
                                  locale: 'id',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(method['admin'])}',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _updateSelectedPaymentMethod,
                      validator: (value) =>
                          value == null ? 'Pilih metode pembayaran' : null,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 15),

            // Payment Details
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rincian Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildPaymentRow('Total Malam', '$_totalNights malam'),
                    _buildPaymentRow(
                      'Harga Kamar',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_totalPrice),
                    ),
                    _buildPaymentRow(
                      'Biaya Admin',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_adminFee),
                    ),
                    _buildPaymentRow(
                      'Biaya Aplikasi',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_appFee),
                    ),
                    Divider(thickness: 1),
                    _buildPaymentRow(
                      'Total Pembayaran',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_totalWithAdmin),
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _showConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Booking Sekarang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
