import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'PracticeDetailPage.dart'; // Import the detail page here

class PracticeHistoryPage extends StatelessWidget {
  final String userId;

  const PracticeHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final practicesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('practices')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: practicesRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text('No practice sessions found.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final practice = docs[index];
            final lapCount = practice['lapCount'] ?? 0;
            final lapDistance = practice['lapDistance'] ?? 0.0;
            final timestamp = practice['timestamp'] as Timestamp?;
            final date = timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
                : null;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                title: Text('Practice #${index + 1}'),
                subtitle: Text(
                    'Laps: $lapCount | Distance: ${lapDistance.toStringAsFixed(2)} m\nDate: ${date != null ? date.toLocal().toString().split(' ')[0] : 'Unknown'}'),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PracticeDetailPage(
                        userId: userId,
                        practiceId: practice.id,
                        lapCount: lapCount,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
