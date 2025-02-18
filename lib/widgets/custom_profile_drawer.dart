import 'package:flutter/material.dart';
import 'package:medknows/pages/profile_screen.dart';

class CustomProfileDrawer extends StatelessWidget {
  final Function onClose;

  const CustomProfileDrawer({
    Key? key,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1, end: 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      builder: (_, double value, child) {
        return Transform.translate(
          offset: Offset(value * 300, 0),
          child: child,
        );
      },
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 200,
          height: double.infinity,
          color: Colors.white,
          child: Stack(
            children: [
              ProfileScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
