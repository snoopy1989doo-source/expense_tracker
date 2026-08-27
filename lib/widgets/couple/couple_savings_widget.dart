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
  bool _showCompletedSection = true;
  final List<SavingsGoal> _localGoals = [];

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

  void _editGoalDialog(SavingsGoal goal) {
    final titleController = TextEditingController(text: goal.title);
    final targetController = TextEditingController(text: goal.targetAmount.toStringAsFixed(0));
    final emojiController = TextEditingController(text: goal.emoji);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✏️ แก้ไขเป้าหมายออมเงิน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'ชื่อเป้าหมาย'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ยอดเงินเป้าหมาย (฿)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(labelText: 'Emoji'),
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
              final newTitle = titleController.text.trim();
              final newTarget = double.tryParse(targetController.text.trim()) ?? goal.targetAmount;
              final newEmoji = emojiController.text.trim().isEmpty ? '🐷' : emojiController.text.trim();

              if (newTitle.isNotEmpty) {
                final roomId = ref.read(coupleRoomIdProvider);
                if (roomId != null) {
                  final updatedGoal = goal.copyWith(
                    title: newTitle,
                    targetAmount: newTarget,
                    emoji: newEmoji,
                  );
                  // Update document in Firestore
                  await ref.read(savingsGoalRepositoryProvider).deleteSavingsGoal(roomId, goal.id);
                  await ref.read(savingsGoalRepositoryProvider).createSavingsGoal(roomId, updatedGoal);
                } else {
                  setState(() {
                    final idx = _localGoals.indexWhere((g) => g.id == goal.id);
                    if (idx != -1) {
                      _localGoals[idx] = _localGoals[idx].copyWith(
                        title: newTitle,
                        targetAmount: newTarget,
                        emoji: newEmoji,
                      );
                    }
                  });
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✨ แก้ไขเป้าหมาย "$newEmoji $newTitle" สำเร็จ!')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('บันทึกการแก้ไข'),
          ),
        ],
      ),
    );
  }

  void _deleteGoal(SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🗑️ ยืนยันการลบเป้าหมาย', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('คุณแน่ใจว่าต้องการลบเป้าหมาย "${goal.emoji} ${goal.title}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final roomId = ref.read(coupleRoomIdProvider);
              if (roomId != null && goal.id.isNotEmpty) {
                await ref.read(savingsGoalRepositoryProvider).deleteSavingsGoal(roomId, goal.id);
              }
              setState(() {
                _localGoals.removeWhere((g) => g.id == goal.id || (g.title == goal.title && g.targetAmount == goal.targetAmount));
              });

              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🗑️ ลบเป้าหมาย "${goal.title}" เรียบร้อยแล้ว')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            child: const Text('ลบเป้าหมาย'),
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
                  final isCompletedNow = (goal.currentAmount + amount) >= goal.targetAmount;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isCompletedNow
                            ? '🏆🎉 ฉลองงง! $userName ช่วยออมเงินทะลุเป้าหมาย 100% แล้ว! 💕'
                            : '🎉 $userName หยอดกระปุกออมเงิน +${CurrencyFormatter.format(amount)} สำเร็จ!',
                      ),
                      backgroundColor: isCompletedNow ? Colors.green : null,
                    ),
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
    final roomId = ref.watch(coupleRoomIdProvider);

    final allGoals = roomId != null ? firestoreGoals : _localGoals;
    final activeGoals = allGoals.where((g) => !g.isCompleted).toList();
    final completedGoals = allGoals.where((g) => g.isCompleted).toList();

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

            if (allGoals.isEmpty)
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
            else ...[
              // Active Goals List
              Column(
                children: activeGoals.map((goal) => _buildGoalCard(goal, theme, isCompleted: false)).toList(),
              ),

              // Completed Goals (Hall of Fame) Section 🎉
              if (completedGoals.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showCompletedSection = !_showCompletedSection;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              'หอเกียรติยศเป้าหมายออมสำเร็จ (${completedGoals.length} เป้าหมาย)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                        Icon(
                          _showCompletedSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.amber.shade900,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showCompletedSection) ...[
                  const SizedBox(height: 8),
                  Column(
                    children: completedGoals.map((goal) => _buildGoalCard(goal, theme, isCompleted: true)).toList(),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoal goal, ThemeData theme, {required bool isCompleted}) {
    final pct = goal.progressPercentage;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : theme.colorScheme.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.green.shade300 : theme.colorScheme.primary.withOpacity(0.2),
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isCompleted ? Colors.green.shade900 : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('✨ ออมสำเร็จ 100%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Action Popup menu for Edit & Delete ✏️ 🗑️
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editGoalDialog(goal);
                  } else if (value == 'delete') {
                    _deleteGoal(goal);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('แก้ไขเป้าหมาย ✏️', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: AppColors.expense),
                        SizedBox(width: 8),
                        Text('ลบเป้าหมาย 🗑️', style: TextStyle(fontSize: 12, color: AppColors.expense)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 10,
              backgroundColor: isCompleted ? Colors.green.shade100 : theme.colorScheme.primary.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ออมแล้ว: ${CurrencyFormatter.format(goal.currentAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.green.shade800 : AppColors.income,
                ),
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
              if (!isCompleted)
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
  }
}
