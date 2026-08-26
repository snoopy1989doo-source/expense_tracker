import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/savings_goal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/savings_goal_provider.dart';

class CoupleSavingsWidget extends ConsumerStatefulWidget {
  const CoupleSavingsWidget({super.key});

  @override
  ConsumerState<CoupleSavingsWidget> createState() => _CoupleSavingsWidgetState();
}

class _CoupleSavingsWidgetState extends ConsumerState<CoupleSavingsWidget> {
  final List<SavingsGoal> _localGoals = [
    SavingsGoal(
      id: 'default_1',
      title: 'ทริปเที่ยวญี่ปุ่น 🇯🇵',
      targetAmount: 50000,
      currentAmount: 18500,
      emoji: '✈️',
      createdAt: DateTime.now(),
      contributions: [
        SavingsContribution(userId: 'u1', userName: 'ต๋องแต่ง', amount: 12000, date: DateTime.now()),
        SavingsContribution(userId: 'u2', userName: 'แฟน', amount: 6500, date: DateTime.now()),
      ],
    ),
  ];

  void _createGoalDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final emojiController = TextEditingController(text: '🐷');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🐷 สร้างเป้าหมายออมเงินคู่รัก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'ชื่อเป้าหมาย (เช่น ทริปท่องเที่ยว, ซื้อคอนโด)',
                hintText: 'กรอกชื่อเป้าหมายความฝันของคู่คุณ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ยอดเงินเป้าหมาย (฿)',
                hintText: 'เช่น 50000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji ประจำเป้าหมาย (เช่น ✈️, 🏠, 💒, 🐷)',
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
            onPressed: () async {
              final title = titleController.text.trim();
              final target = double.tryParse(targetController.text.trim()) ?? 0;
              final emoji = emojiController.text.trim().isEmpty ? '🐷' : emojiController.text.trim();

              if (title.isNotEmpty && target > 0) {
                final newGoal = SavingsGoal(
                  id: '',
                  title: title,
                  targetAmount: target,
                  currentAmount: 0,
                  emoji: emoji,
                  createdAt: DateTime.now(),
                );

                final roomId = ref.read(coupleRoomIdProvider);
                if (roomId != null) {
                  await ref.read(savingsGoalRepositoryProvider).createSavingsGoal(roomId, newGoal);
                } else {
                  setState(() {
                    _localGoals.add(newGoal);
                  });
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✨ สร้างเป้าหมาย "$emoji $title" สำเร็จ!')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('สร้างเป้าหมาย'),
          ),
        ],
      ),
    );
  }

  void _addContributionDialog(SavingsGoal goal) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('💵 หยอดกระปุก: ${goal.emoji} ${goal.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'จำนวนเงินที่ออมเข้ากระปุกวันนี้ (฿)',
                hintText: 'เช่น 500',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'บันทึกความรู้สึก / โน้ต (ไม่ระบุก็ได้)',
                hintText: 'เช่น หักค่าน้ำหวานสะสมออมเงิน',
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
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              final note = noteController.text.trim();
              final userProfile = ref.read(userProfileProvider).value;
              final authState = ref.read(authStateProvider).value;
              final userName = userProfile?.nickname ?? 'ผู้ใช้';
              final userId = authState ?? 'guest';

              if (amount > 0) {
                final contribution = SavingsContribution(
                  userId: userId,
                  userName: userName,
                  amount: amount,
                  date: DateTime.now(),
                  note: note.isNotEmpty ? note : null,
                );

                final roomId = ref.read(coupleRoomIdProvider);
                if (roomId != null) {
                  await ref.read(savingsGoalRepositoryProvider).addContribution(roomId, goal.id, contribution);
                } else {
                  setState(() {
                    final idx = _localGoals.indexWhere((g) => g.id == goal.id);
                    if (idx != -1) {
                      final old = _localGoals[idx];
                      _localGoals[idx] = old.copyWith(
                        currentAmount: old.currentAmount + amount,
                        contributions: [...old.contributions, contribution],
                      );
                    }
                  });
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🎉 $userName หยอดกระปุกออมเงิน +${CurrencyFormatter.format(amount)} สำเร็จ!')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('ออมเงินเข้ากระปุก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);
    final firestoreGoals = goalsAsync.value ?? [];

    final activeGoals = firestoreGoals.isNotEmpty ? firestoreGoals : _localGoals;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🐷', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'กระปุกออมสินเป้าหมายคู่รัก',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  tooltip: 'สร้างเป้าหมายออมเงินใหม่',
                  onPressed: _createGoalDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (activeGoals.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Text('ยังไม่มีเป้าหมายออมเงินคู่รัก', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _createGoalDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('สร้างเป้าหมายออมเงินร่วมกัน ✨'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: activeGoals.map((goal) {
                  final pct = goal.progressPercentage;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(goal.emoji, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 8),
                                Text(
                                  goal.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 10,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ออมแล้ว: ${CurrencyFormatter.format(goal.currentAmount)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.income),
                            ),
                            Text(
                              'เป้าหมาย: ${CurrencyFormatter.format(goal.targetAmount)}',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Contribution breakdown & Add button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: goal.contributions.take(3).map((c) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: Chip(
                                        padding: EdgeInsets.zero,
                                        labelStyle: const TextStyle(fontSize: 10),
                                        avatar: const Icon(Icons.person, size: 12, color: AppColors.primary),
                                        label: Text('${c.userName}: ${CurrencyFormatter.format(c.amount)}'),
                                        backgroundColor: theme.colorScheme.surface,
                                        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _addContributionDialog(goal),
                              icon: const Icon(Icons.savings, size: 14),
                              label: const Text('หยอดกระปุก 💕', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
