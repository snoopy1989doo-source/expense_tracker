import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../screens/transaction/add_edit_transaction_screen.dart';

class FoodDecisionWheelDialog extends StatefulWidget {
  const FoodDecisionWheelDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FoodDecisionWheelDialog(),
    );
  }

  @override
  State<FoodDecisionWheelDialog> createState() => _FoodDecisionWheelDialogState();
}

class _FoodDecisionWheelDialogState extends State<FoodDecisionWheelDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _targetAngle = 0;
  String? _selectedFood;
  bool _isSpinning = false;

  final List<Map<String, String>> _foodMenu = [
    {'name': 'ชาบู / หมูกระทะ', 'emoji': '🍲'},
    {'name': 'ส้มตำ / ยำแซ่บ', 'emoji': '🥗'},
    {'name': 'ข้าวมันไก่ / ข้าวหมูแดง', 'emoji': '🍗'},
    {'name': 'สเต๊ก / เบอร์เกอร์', 'emoji': '🥩'},
    {'name': 'ก๋วยเตี๋ยว / บะหมี่', 'emoji': '🍜'},
    {'name': 'สปาเก็ตตี้ / อาหารอิตาเลียน', 'emoji': '🍝'},
    {'name': 'อาหารตามสั่ง / ข้าวไข่เจียว', 'emoji': '🍳'},
    {'name': 'ชาไข่มุก / ของหวาน', 'emoji': '🧋'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSpinning = false;
        });
      }
    });
  }

  void _addCustomFoodDialog() {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '🍱');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('➕ เพิ่มเมนูอาหารโปรดของคุณ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อเมนูอาหาร (เช่น สุกี้จินดา, กะเพราไข่ดาว)',
                hintText: 'กรอกชื่อเมนูโปรดของคุณกับแฟน',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji ประจำเมนู (เช่น 🍱, 🍣, 🍕)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final emoji = emojiController.text.trim().isEmpty ? '🍱' : emojiController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _foodMenu.add({'name': name, 'emoji': emoji});
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✨ เพิ่มเมนู "$emoji $name" เข้าวงล้อสำเร็จ!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('บันทึกเมนู'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_isSpinning) return;

    final random = Random();
    final chosenIndex = random.nextInt(_foodMenu.length);
    final food = _foodMenu[chosenIndex];

    // Calculate turns (at least 4 full spins + angle offset)
    final double fullTurns = 4 * 2 * pi;
    final double sectorAngle = (2 * pi) / _foodMenu.length;
    final double targetOffset = (fullTurns + (chosenIndex * sectorAngle));

    setState(() {
      _isSpinning = true;
      _targetAngle = targetOffset;
      _selectedFood = '${food['emoji']} ${food['name']}';
    });

    _controller.reset();
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.casino, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เย็นนี้กินอะไรดี? 🎰',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'วงล้อสุ่มมื้ออาหารแก้ปัญหายอดฮิตคู่รัก',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Animated Wheel Display
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final angle = _animation.value * _targetAngle;
                return Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Colors.pink.shade300, Colors.purple.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.restaurant, size: 60, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Result Text
            if (_selectedFood != null && !_isSpinning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text('🎉 เย็นนี้กินนี่เลย!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFood!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                    ),
                  ],
                ),
              )
            else if (_isSpinning)
              const Text('🎰 กำลังหมุนสุ่มเมนู...', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))
            else
              const Text('กดปุ่มด้านล่างเพื่อหมุนสุ่มเมนูมื้อเย็น', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSpinning ? null : _spinWheel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_selectedFood == null ? '🎰 หมุนสุ่มเมนู' : '🔄 หมุนใหม่อีกครั้ง'),
                  ),
                ),
                if (_selectedFood != null && !_isSpinning) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddEditTransactionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('📝 จดบันทึกมื้อนี้', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _isSpinning ? null : _addCustomFoodDialog,
              icon: const Icon(Icons.add, size: 16),
              label: Text('➕ เพิ่มเมนูโปรดของคุณ (${_foodMenu.length} เมนูในวงล้อ)', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
