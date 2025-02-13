import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/app_theme.dart';

final supabase = Supabase.instance.client;

class HotelRatingScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const HotelRatingScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<HotelRatingScreen> createState() => _HotelRatingScreenState();
}

class _HotelRatingScreenState extends State<HotelRatingScreen> {
  double _rating = 5;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beri Rating & Ulasan Hotel',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking #${widget.booking['id'].toString().substring(widget.booking['id'].toString().length - 6)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.booking['hotels']['name'] ?? 'Hotel',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Beri rating untuk pengalaman menginap Anda',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: RatingBar.builder(
                        initialRating: _rating,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 40,
                        itemPadding:
                            const EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onRatingUpdate: (rating) {
                          setState(() {
                            _rating = rating;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tulis Ulasan Anda',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Bagaimana pengalaman menginap Anda?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Kirim Rating & Ulasan',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_reviewController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Mohon isi ulasan Anda',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Simpan rating ke database
      await supabase.from('hotel_ratings').insert({
        'booking_id': widget.booking['id'],
        'rating': _rating,
        'review': _reviewController.text.trim(),
        'user_id': supabase.auth.currentUser!.id,
        'hotel_id': widget.booking['hotel_id'],
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update status booking dengan rating
      await supabase
          .from('hotel_bookings')
          .update({'has_rating': true}).eq('id', widget.booking['id']);

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Terima kasih atas rating dan ulasan Anda',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Terjadi kesalahan saat menyimpan rating',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}
