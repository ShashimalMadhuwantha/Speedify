import 'package:flutter/material.dart';

class SprinterDrawer extends StatelessWidget {
  final String selected;
  final Function(String) onSelect;
  final String sprinterId;

  const SprinterDrawer({
    Key? key,
    required this.selected,
    required this.onSelect,
    required this.sprinterId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);
    final textStyle = TextStyle(fontSize: 16);

    Widget drawerItem(String title, IconData icon) {
      bool isSelected = selected == title;
      return ListTile(
        selected: isSelected,
        selectedTileColor: blueColor.withOpacity(0.15),
        leading: Icon(icon, color: isSelected ? blueColor : Colors.black54),
        title: Text(
          title,
          style: textStyle.copyWith(
            color: isSelected ? blueColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context); // close the drawer
          onSelect(title);
        },
      );
    }

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: blueColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35, color: blueColor),
                  ),
                  SizedBox(height: 10),
                  Text('Sprinter', style: TextStyle(color: Colors.white, fontSize: 20)),
                  Text(sprinterId, style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            drawerItem('Dashboard', Icons.dashboard),
            drawerItem('Practice History', Icons.history),
            drawerItem('New Practice', Icons.add_circle_outline),
            Spacer(),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context); // return to login
              },
            ),
          ],
        ),
      ),
    );
  }
}
