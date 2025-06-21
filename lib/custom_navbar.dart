import 'package:flutter/material.dart';

class SprinterNavBar extends StatelessWidget {
  final String sprinterId;
  final String selectedPage;
  final Function(String page) onNavSelected;

  const SprinterNavBar({
    Key? key,
    required this.sprinterId,
    required this.selectedPage,
    required this.onNavSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);

    Widget navButton(String title) {
      final bool isSelected = selectedPage == title;
      return TextButton(
        onPressed: () => onNavSelected(title),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? blueColor : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          navButton('Practice History'),
          SizedBox(width: 20),
          navButton('New Practice'),
          Spacer(),
          Text('User ID: $sprinterId',
              style: TextStyle(color: blueColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
