import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'PracticeDetailPage.dart';
import 'PracticeComparePage.dart';

class PracticeHistoryPage extends StatefulWidget {
  final String userId;

  const PracticeHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<PracticeHistoryPage> createState() => _PracticeHistoryPageState();
}

class _PracticeHistoryPageState extends State<PracticeHistoryPage> {
  DateTime? _selectedDate;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final practicesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // THIS REMOVES THE BACK BUTTON
        title: const Text('Practice History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null
                        ? 'Select Date'
                        : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'),
                    onPressed: () => _pickDate(context),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear date filter',
                    onPressed: _clearDate,
                  )
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: practicesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Filter by selected date if any
          final filteredDocs = _selectedDate == null
              ? docs
              : docs.where((doc) {
                  final ts = doc['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  final date = DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch);
                  return date.year == _selectedDate!.year &&
                      date.month == _selectedDate!.month &&
                      date.day == _selectedDate!.day;
                }).toList();

          if (filteredDocs.isEmpty) return const Center(child: Text('No practice sessions found.'));

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final practice = filteredDocs[index];
              final lapCount = practice['lapCount'] ?? 0;
              final lapDistance = practice['lapDistance'] ?? 0.0;
              final timestamp = practice['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
                  : null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text('Practice #${index + 1}'),
                  subtitle: Text(
                      'Laps: $lapCount | Distance: ${lapDistance.toStringAsFixed(2)} m\nDate: ${date != null ? date.toLocal().toString().split(' ')[0] : 'Unknown'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.compare),
                        tooltip: 'Compare',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PracticeComparePage(
                                userId: widget.userId,
                                firstPracticeId: practice.id,
                              ),
                            ),
                          );
                        },
                      ),
                      const Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PracticeDetailPage(
                          userId: widget.userId,
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
      ),
    );
  }
}
