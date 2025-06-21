import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'sprinter_drawer.dart';
import 'practice_page.dart';

class SprinterDashboard extends StatefulWidget {
  final String sprinterId;

  const SprinterDashboard({Key? key, required this.sprinterId}) : super(key: key);

  @override
  _SprinterDashboardState createState() => _SprinterDashboardState();
}

class _SprinterDashboardState extends State<SprinterDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<DocumentSnapshot> _sprinterFuture;
  String _selectedPage = 'Dashboard';

  @override
  void initState() {
    super.initState();
    _sprinterFuture = _firestore.collection('sprinters').doc(widget.sprinterId).get();
  }

  void _onDrawerSelection(String page) {
    setState(() {
      _selectedPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Speedify'),
        backgroundColor: blueColor,
      ),
      drawer: SprinterDrawer(
        selected: _selectedPage,
        onSelect: _onDrawerSelection,
        sprinterId: widget.sprinterId,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _sprinterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: blueColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Sprinter not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          switch (_selectedPage) {
            case 'Dashboard':
              return _buildDashboard(data, blueColor);
            case 'New Practice':
              return PracticePage(userId: widget.sprinterId);
            case 'Practice History':
              return Center(child: Text('Practice History Coming Soon'));
            default:
              return Center(child: Text('Page not found'));
          }
        },
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> data, Color blueColor) {
    return Container(
      color: Color(0xFFBBDEFB),
      padding: EdgeInsets.all(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: blueColor,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                data['name'] ?? 'No Name',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: blueColor),
              ),
              SizedBox(height: 10),
              Text(
                data['email'] ?? 'No Email',
                style: TextStyle(fontSize: 18, color: blueColor.withOpacity(0.7)),
              ),
              SizedBox(height: 20),
              Text('Welcome to your dashboard!', style: TextStyle(fontSize: 20, color: blueColor)),
            ],
          ),
        ),
      ),
    );
  }
}
