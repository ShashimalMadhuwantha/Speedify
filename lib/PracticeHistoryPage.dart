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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.blue.shade700,
            onPrimary: Colors.white,
            onSurface: Colors.blue.shade900,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
          ),
        ),
        child: child!,
      ),
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

    final blueColor = Colors.blue.shade700;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // removes back button
        backgroundColor: blueColor,
        title: const Text('Practice History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: blueColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: blueColor.withOpacity(0.25),
                    ),
                    onPressed: () => _pickDate(context),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: blueColor),
                    tooltip: 'Clear date filter',
                    onPressed: _clearDate,
                    splashRadius: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: practicesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

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

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text(
                'No practice sessions found.',
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final practice = filteredDocs[index];
              final lapCount = practice['lapCount'] ?? 0;
              final lapDistance = (practice['lapDistance'] ?? 0).toDouble();
              final timestamp = practice['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
                  : null;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: blueColor.withOpacity(0.2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: blueColor.withOpacity(0.1),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: blueColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.directions_run,
                            color: blueColor,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Practice Session #${index + 1}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Laps: $lapCount   |   Distance: ${lapDistance.toStringAsFixed(2)} m',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date != null
                                    ? 'Date: ${date.toLocal().toString().split(' ')[0]}'
                                    : 'Date: Unknown',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.compare, color: blueColor),
                              tooltip: 'Compare',
                              splashRadius: 26,
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
                            const SizedBox(height: 8),
                            Icon(Icons.arrow_forward_ios, size: 18, color: blueColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
