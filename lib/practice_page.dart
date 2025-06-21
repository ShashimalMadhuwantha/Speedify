import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'live_practice_page.dart'; // Import the live display page

class PracticePage extends StatefulWidget {
  final String userId;

  const PracticePage({Key? key, required this.userId}) : super(key: key);

  @override
  _PracticePageState createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _lapDistanceController = TextEditingController();
  final TextEditingController _lapCountController = TextEditingController();

  bool _loading = false;
  String _error = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _savePractice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      double lapDistance = double.parse(_lapDistanceController.text.trim());
      int lapCount = int.parse(_lapCountController.text.trim());

      DocumentReference practiceRef = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('practices')
          .add({
        'lapDistance': lapDistance,
        'lapCount': lapCount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      for (int i = 1; i <= lapCount; i++) {
        await practiceRef.collection('laps').doc('lap_$i').set({
          'lapNumber': i,
          'time': 0,
          'speed': 0.0,
        });
      }

      // Navigate to live practice page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LivePracticePage(
            userId: widget.userId,
            practiceId: practiceRef.id,
              lapCount: lapCount,
          ),
        ),
      );

      _lapDistanceController.clear();
      _lapCountController.clear();
    } catch (e) {
      setState(() {
        _error = 'Failed to save practice: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _lapDistanceController.dispose();
    _lapCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'New Practice',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: blueColor,
                ),
              ),
              SizedBox(height: 20),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              TextFormField(
                controller: _lapDistanceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Lap Distance (meters)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter lap distance';
                  final number = double.tryParse(value);
                  if (number == null || number <= 0) return 'Enter a valid positive number';
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _lapCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Lap Count',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter lap count';
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) return 'Enter a valid positive integer';
                  return null;
                },
              ),
              SizedBox(height: 30),
              _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(blueColor),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _savePractice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          'Save Practice',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
