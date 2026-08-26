import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/couple_provider.dart';

class CoupleQuestsWidget extends ConsumerStatefulWidget {
  const CoupleQuestsWidget({super.key});

  @override
  ConsumerState<CoupleQuestsWidget> createState() => _CoupleQuestsWidgetState();
}

class _CoupleQuestsWidgetState extends ConsumerState<CoupleQuestsWidget> {
  bool _isQuestCompleted = false;

  final List<Map<String, String>> _defaultQuests = [
    {
      'title': '☕ ภารกิจจันทร์: เลี้ยงกาแฟ/เครื่องดื่มแฟน 1 แก้ว',
      'desc': 'เพิ่มความหวานวันทำงาน (+10 คะแนนความรัก)',
      'reward': '💖 +10 คะแนนความรัก',
    },
    {
      'title': '🍱 ภารกิจอังคาร: ทำมื้อเย็นกินด้วยกันที่บ้าน',
      'desc': 'ช่วยกันประหยัดค่านอกบ้าน (+15 คะแนนการเงิน)',
      'reward': '💰 +15 คะแนนการเงิน',
    },
    {
      'title': '🍦 ภารกิจพุธ: พาแฟนไปกินของอร่อยงบไม่เกิน ฿150',
      'desc': 'ความสุขเล็กๆ ในงบประหยัด (+10 คะแนนความสุข)',
      'reward': '😊 +10 คะแนนความสุข',
    },
    {
      'title': '🍿 ภารกิจพฤหัสบดี: ดูหนังเรื่องโปรดด้วยกันที่บ้าน',
      'desc': 'ผ่อนคลายความเหนื่อยล้าด้วยกัน (+15 คะแนนความรัก)',
      'reward': '💖 +15 คะแนนความรัก',
    },
    {
      'title': '🛍️ ภารกิจศุกร์: ช่วยกันเช็กยอดเงินคงเหลือปลายสัปดาห์',
      'desc': 'วางแผนการเงินและออมเงินร่วมกัน (+20 คะแนนการเงิน)',
      'reward': '💰 +20 คะแนนการเงิน',
    },
    {
      'title': '🚴 ภารกิจเสาร์: ออกกำลังกาย/เดินเล่นสวนสาธารณะคู่กัน',
      'desc': 'สุขภาพดี & ใช้เวลาคุณภาพ (+15 คะแนนความสุข)',
      'reward': '😊 +15 คะแนนความสุข',
    },
    {
      'title': '🧹 ภารกิจอาทิตย์: ช่วยกันทำความสะอาดห้อง/จัดบ้าน',
      'desc': 'สร้างสภาพแวดล้อมอบอุ่นในบ้าน (+15 คะแนนความรัก)',
      'reward': '💖 +15 คะแนนความรัก',
    },
  ];

  final List<Map<String, String>> _localCustomQuests = [];

  void _addCustomQuestDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('➕ เพิ่มภารกิจคู่รักของคุณเอง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'ชื่อภารกิจคู่รัก (เช่น 💕 กอดกัน 10 วินาที)',
                hintText: 'กรอกภารกิจน่ารักๆ สำหรับคุณกับแฟน',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย / รางวัล (เช่น +20 คะแนนความหวาน)',
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
              final desc = descController.text.trim();
              if (title.isNotEmpty) {
                final questItem = {
                  'title': '💕 $title',
                  'desc': desc.isNotEmpty ? desc : 'ภารกิจพิเศษประจำคู่เรา (+15 คะแนนความรัก)',
                  'reward': '💖 +15 คะแนนความรัก',
                };
                final roomId = ref.read(coupleRoomIdProvider);
                if (roomId != null) {
                  await ref.read(coupleRepositoryProvider).addCustomQuestToRoom(roomId, questItem);
                }
                setState(() {
                  _localCustomQuests.add(questItem);
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✨ เพิ่มภารกิจ "$title" เข้า Firebase เรียบร้อยแล้ว!')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('บันทึกภารกิจ'),
          ),
        ],
      ),
    );
  }

  void _manageQuestsBottomSheet(List<Map<String, String>> activeQuests) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final coupleRoom = ref.watch(coupleRoomProvider).value;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: AppColors.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '📋 จัดการ & ตรวจสอบภารกิจคู่รักทั้งหมด',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeQuests.length,
                    itemBuilder: (context, index) {
                      final q = activeQuests[index];
                      final isDefault = _defaultQuests.any((d) => d['title'] == q['title']);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(q['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            q['desc'] ?? '',
                            style: TextStyle(fontSize: 11, color: isDefault ? Colors.grey : AppColors.primary),
                          ),
                          trailing: isDefault
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                      onPressed: () {
                                        _editQuestDialog(q, coupleRoom?.id);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: AppColors.expense, size: 20),
                                      onPressed: () async {
                                        final roomId = ref.read(coupleRoomIdProvider);
                                        if (roomId != null) {
                                          await ref.read(coupleRepositoryProvider).removeCustomQuestFromRoom(roomId, q);
                                        }
                                        setState(() {
                                          _localCustomQuests.removeWhere((item) => item['title'] == q['title']);
                                        });
                                        setSheetState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('🗑️ ลบภารกิจ "${q['title']}" สำเร็จ')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _addCustomQuestDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('➕ เพิ่มภารกิจใหม่'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _editQuestDialog(Map<String, String> oldQuest, String? roomId) {
    final titleController = TextEditingController(text: oldQuest['title']?.replaceAll('💕 ', ''));
    final descController = TextEditingController(text: oldQuest['desc']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✏️ แก้ไขภารกิจคู่รัก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'ชื่อภารกิจคู่รัก'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'คำอธิบาย / รางวัล'),
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
              final newDesc = descController.text.trim();

              if (newTitle.isNotEmpty) {
                final newItem = {
                  'title': '💕 $newTitle',
                  'desc': newDesc.isNotEmpty ? newDesc : 'ภารกิจพิเศษประจำคู่เรา (+15 คะแนนความรัก)',
                  'reward': '💖 +15 คะแนนความรัก',
                };
                if (roomId != null) {
                  await ref.read(coupleRepositoryProvider).removeCustomQuestFromRoom(roomId, oldQuest);
                  await ref.read(coupleRepositoryProvider).addCustomQuestToRoom(roomId, newItem);
                }
                setState(() {
                  _localCustomQuests.removeWhere((item) => item['title'] == oldQuest['title']);
                  _localCustomQuests.add(newItem);
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✨ แก้ไขภารกิจเป็น "$newTitle" สำเร็จ!')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coupleRoom = ref.watch(coupleRoomProvider).value;

    final Map<String, Map<String, String>> uniqueQuests = {};
    for (var q in _defaultQuests) {
      uniqueQuests[q['title']!] = q;
    }
    for (var q in _localCustomQuests) {
      uniqueQuests[q['title']!] = q;
    }
    if (coupleRoom != null) {
      for (var q in coupleRoom.customQuests) {
        uniqueQuests[q['title']!] = q;
      }
    }

    final activeQuests = uniqueQuests.values.toList();
    final dayIndex = DateTime.now().day % activeQuests.length;
    final currentQuest = activeQuests[dayIndex];

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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addCustomQuestDialog,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('➕ เพิ่มภารกิจ', style: TextStyle(fontSize: 11)),
                ),
                TextButton.icon(
                  onPressed: () => _manageQuestsBottomSheet(activeQuests),
                  icon: const Icon(Icons.list_alt, size: 14),
                  label: Text('📋 ดู/แก้ไข/ลบภารกิจ (${activeQuests.length})', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
