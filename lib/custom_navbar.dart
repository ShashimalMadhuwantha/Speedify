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
    final blueColor = const Color(0xFF1565C0);
    final unselectedTextColor = Colors.grey[700];

    Widget navButton(String title) {
      final bool isSelected = selectedPage == title;
      return TextButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color?>(
            (states) {
              if (isSelected) return blueColor;
              if (states.contains(MaterialState.hovered)) {
                return blueColor.withOpacity(0.1);
              }
              return null; // transparent background when not selected
            },
          ),
          foregroundColor: MaterialStateProperty.resolveWith<Color>(
            (states) {
              if (isSelected) return Colors.white;
              if (states.contains(MaterialState.hovered)) {
                return blueColor;
              }
              return unselectedTextColor ?? Colors.grey;
            },
          ),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          overlayColor: MaterialStateProperty.all(blueColor.withOpacity(0.2)),
          textStyle: MaterialStateProperty.all(
            TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        onPressed: () => onNavSelected(title),
        child: Text(title),
      );
    }

    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            navButton('Practice History'),
            const SizedBox(width: 16),
            navButton('New Practice'),
            const SizedBox(width: 16),
            navButton('Practice Modes'),
            const Spacer(),
            Text(
              'User ID: $sprinterId',
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
