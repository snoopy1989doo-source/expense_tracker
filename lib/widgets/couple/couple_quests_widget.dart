import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CoupleQuestsWidget extends StatefulWidget {
  const CoupleQuestsWidget({super.key});

  @override
  State<CoupleQuestsWidget> createState() => _CoupleQuestsWidgetState();
}

class _CoupleQuestsWidgetState extends State<CoupleQuestsWidget> {
  bool _isQuestCompleted = false;

  final List<Map<String, String>> _quests = const [
    {
      'title': '☕ ภารกิจวันนี้: เลี้ยงกาแฟ/เครื่องดื่มแฟน 1 แก้ว',
      'desc': 'เพิ่มความหวานให้กันในวันทำงาน (+10 คะแนนความรัก)',
      'reward': '💖 +10 คะแนนความรัก',
    },
    {
      'title': '🍱 ภารกิจวันนี้: ทำมื้อเย็นกินด้วยกันที่บ้าน',
      'desc': 'ประหยัดงบค่านอกบ้าน แถมได้ใช้เวลาคุณภาพร่วมกัน (+15 คะแนนการเงิน)',
      'reward': '💰 +15 คะแนนการเงิน',
    },
    {
      'title': '🍦 ภารกิจวันนี้: พาแฟนไปกินของอร่อยงบไม่เกิน ฿150',
      'desc': 'ความสุขเล็กๆ ในงบประหยัด (+10 คะแนนความสุข)',
      'reward': '😊 +10 คะแนนความสุข',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayIndex = DateTime.now().day % _quests.length;
    final currentQuest = _quests[dayIndex];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Fortune Scores Header
            Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '🔮 ดวงการเงิน & ภารกิจคู่เรารายวัน',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scores Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('💖 ความรัก', style: TextStyle(fontSize: 11)),
                      SizedBox(height: 4),
                      Text('88', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('💰 ดวงการเงิน', style: TextStyle(fontSize: 11)),
                      SizedBox(height: 4),
                      Text('82', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.income)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('😊 ความสุข', style: TextStyle(fontSize: 11)),
                      SizedBox(height: 4),
                      Text('95', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quest Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isQuestCompleted
                    ? Colors.green.shade50
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: _isQuestCompleted ? Colors.green : theme.colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentQuest['title']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isQuestCompleted ? Colors.green.shade800 : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentQuest['desc']!,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isQuestCompleted = !_isQuestCompleted;
                      });
                      if (_isQuestCompleted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 ทำภารกิจสำเร็จ! เพิ่มคะแนนคู่รัก +15 💕'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isQuestCompleted ? Colors.green : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: Text(_isQuestCompleted ? 'สำเร็จแล้ว! ✨' : 'ทำภารกิจ 💕', style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
