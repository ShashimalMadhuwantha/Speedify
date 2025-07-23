import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'live_practice_page.dart';

class Adjustrower extends StatefulWidget {
  final String userId;
  final String practiceId;
  final int lapCount;

  const Adjustrower({
    Key? key,
    required this.userId,
    required this.practiceId,
    required this.lapCount,
  }) : super(key: key);

  @override
  _AdjustrowerState createState() => _AdjustrowerState();
}

class _AdjustrowerState extends State<Adjustrower> with SingleTickerProviderStateMixin {
  final Color blueColor = const Color(0xFF1565C0);
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool _isUpdating = false;
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  Future<void> _setReadyStatusAndNavigate() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await _dbRef.child('status').set('ready');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LivePracticePage(
            userId: widget.userId,
            practiceId: widget.practiceId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe3f2fd), Color(0xFFbbdefb)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  Text(
                    'Adjust the rower for you',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black12,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/889/889105.png',
                    width: 140,
                    height: 140,
                    color: blueColor.withOpacity(0.85),
                    colorBlendMode: BlendMode.modulate,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Get Ready!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  _isUpdating
                      ? CircularProgressIndicator(color: blueColor)
                      : ElevatedButton.icon(
                          onPressed: _setReadyStatusAndNavigate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueColor,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 8,
                            shadowColor: Colors.blueAccent,
                          ),
                          icon: const Icon(Icons.arrow_forward, color: Colors.white),
                          label: const Text(
                            'Start Practice',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
