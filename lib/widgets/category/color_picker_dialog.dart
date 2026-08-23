import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ColorPickerDialog extends StatelessWidget {
  final ValueChanged<Color> onColorSelected;

  const ColorPickerDialog({super.key, required this.onColorSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'เลือกสีหมวดหมู่',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 250,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: AppColors.categoryPalette.length,
          itemBuilder: (context, index) {
            final color = AppColors.categoryPalette[index];
            return InkWell(
              onTap: () {
                onColorSelected(color);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static void show(BuildContext context, ValueChanged<Color> onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(onColorSelected: onColorSelected),
    );
  }
}
