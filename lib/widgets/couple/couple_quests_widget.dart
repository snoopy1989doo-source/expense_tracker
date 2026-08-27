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
                  child: activeQuests.isEmpty
                      ? const Center(
                          child: Text('ยังไม่มีภารกิจคู่รัก กดปุ่มด้านล่างเพื่อเพิ่มภารกิจใหม่ 💕', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        )
                      : ListView.builder(
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
                                trailing: Row(
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
                                          if (isDefault) {
                                            await ref.read(coupleRepositoryProvider).addDeletedDefaultQuest(roomId, q['title']!);
                                          } else {
                                            await ref.read(coupleRepositoryProvider).removeCustomQuestFromRoom(roomId, q);
                                          }
                                        }
                                        setState(() {
                                          _localCustomQuests.removeWhere((item) => item['title'] == q['title']);
                                          _defaultQuests.removeWhere((item) => item['title'] == q['title']);
                                        });
                                        setSheetState(() {});
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('🗑️ ลบภารกิจ "${q['title']}" สำเร็จ')),
                                          );
                                        }
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
    final isDefault = _defaultQuests.any((d) => d['title'] == oldQuest['title']);
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
                  if (isDefault) {
                    await ref.read(coupleRepositoryProvider).addDeletedDefaultQuest(roomId, oldQuest['title']!);
                  } else {
                    await ref.read(coupleRepositoryProvider).removeCustomQuestFromRoom(roomId, oldQuest);
                  }
                  await ref.read(coupleRepositoryProvider).addCustomQuestToRoom(roomId, newItem);
                }
                setState(() {
                  _defaultQuests.removeWhere((item) => item['title'] == oldQuest['title']);
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

  int _extraFortuneOffset = 0;

  void _showFortuneDetailsDialog({
    required String dayName,
    required int loveScore,
    required int moneyScore,
    required int happinessScore,
    required String quote,
    required String luckyColor,
    required String luckyNumber,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final stars = (moneyScore / 20).clamp(1, 5).toInt();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🔮', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เซียมซีดวงการเงินคู่รัก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('ประจำ$dayName (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 24,
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // 3 Scores Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('💖 ความรัก', style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('$loveScore/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('💰 การเงิน', style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('$moneyScore/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.income)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('😊 ความสุข', style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('$happinessScore/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Advice Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📜 คำทำนาย & เคล็ดลับการเงินคู่เรา:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
                      const SizedBox(height: 6),
                      Text(quote, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.brown)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Lucky Elements
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            const Text('🎨 สีมงคลวันนี้', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(luckyColor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            const Text('🔢 เลขนำโชค', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(luckyNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _extraFortuneOffset += 7;
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🥠 สุ่มเซียมซีการเงินใบใหม่เรียบร้อยแล้ว ✨')),
                  );
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('🥠 สุ่มเซียมซีใหม่'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('รับคำทำนาย 💕'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coupleRoom = ref.watch(coupleRoomProvider).value;
    final deletedTitles = coupleRoom?.deletedDefaultQuests ?? [];

    final Map<String, Map<String, String>> uniqueQuests = {};
    for (var q in _defaultQuests) {
      if (!deletedTitles.contains(q['title'])) {
        uniqueQuests[q['title']!] = q;
      }
    }
    for (var q in _localCustomQuests) {
      if (!deletedTitles.contains(q['title'])) {
        uniqueQuests[q['title']!] = q;
      }
    }
    if (coupleRoom != null) {
      for (var q in coupleRoom.customQuests) {
        if (!deletedTitles.contains(q['title'])) {
          uniqueQuests[q['title']!] = q;
        }
      }
    }

    final activeQuests = uniqueQuests.values.toList();
    final now = DateTime.now();

    // Thai day names
    final dayNames = ['วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์'];
    final currentDayName = dayNames[(now.weekday - 1) % 7];

    // Pick quest matched by weekday
    final weekdayIndex = (now.weekday - 1) % (activeQuests.isNotEmpty ? activeQuests.length : 1);
    final currentQuest = activeQuests.isNotEmpty
        ? activeQuests[weekdayIndex]
        : {'title': '💕 เพิ่มภารกิจความรักคู่เรา', 'desc': 'กดปุ่มด้านล่างเพื่อเพิ่มภารกิจประจำวันกับแฟน'};

    // Dynamic Daily Deterministic Seed (changes every day!)
    final roomCode = coupleRoom?.inviteCode ?? 'KAPOOK';
    final roomHash = roomCode.codeUnits.fold(0, (sum, c) => sum + c);
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final seed = (now.year * 1000 + dayOfYear * 47 + roomHash * 23 + _extraFortuneOffset);

    // Dynamic Daily Scores
    final loveScore = 80 + (seed * 7 + 13) % 20; // 80 - 99
    final moneyScore = 65 + (seed * 11 + 29) % 35; // 65 - 99
    final happinessScore = 82 + (seed * 13 + 17) % 18; // 82 - 99

    // Curated Financial & Love Tips
    final List<String> dailyQuotes = [
      '✨ วันนี้ดวงการเงินสดใส มีเกณฑ์ได้รับส่วนลดพิเศษหรือโชคลาภเล็กๆ!',
      '🧋 ระวังเงินรั่วไหลกับของหวาน/ชานมช่วงบ่าย ดื่มน้ำเปล่าเติมความสดชื่นแทนนะ',
      '🍲 มื้อนี้เหมาะแก่การทำอาหารกินเองที่บ้าน อร่อย อบอุ่น และเซฟงบสุดๆ',
      '💳 ก่อนกดช้อปปิ้งออนไลน์คืนนี้ ชวนแฟนคุยก่อนสัก 5 นาที ช่วยคุมงบได้ดีเยี่ยม',
      '🌟 วันนี้ดวงเก็บเงินเฮงมาก เหมาะแก่การหยอดกระปุกออมสินคู่รัก!',
      '🚗 เดินทางราบรื่น วางแผนเส้นทางดีช่วยประหยัดค่าน้ำมันได้เยอะ',
      '🎁 มีเกณฑ์ได้ของถูกใจในราคาคุ้มค่า ตาดีได้ของลดราคาปังๆ',
      '💖 ความรักหนุนดวงการเงิน ยิ่งช่วยกันวางแผน ยิ่งรวยและมีความสุข',
      '☕ ลองลดกาแฟแก้วแพง แล้วเติมความหวานด้วยคำชมแฟนดูนะคร้าบ',
      '🎉 วันนี้การเงินคล่องตัว คุมงบได้ตามเป้าหมายแบบไร้กังวล!',
      '🧾 บันทึกรายจ่ายวันนี้ให้ครบ จะช่วยให้เห็นเงินเก็บก้อนโตสิ้นเดือน',
      '🍱 อาหารมื้อเย็นวันนี้สั่งแบบประหยัดหรือกินที่เดิม อิ่มคุ้มสบายกระเป๋า',
    ];

    final quoteIndex = (seed * 3 + 7) % dailyQuotes.length;
    final todayQuote = dailyQuotes[quoteIndex];

    final luckyColors = [
      'สีเขียวเหนี่ยวทรัพย์ 🍀',
      'สีชมพูเสริมรักหวาน 💖',
      'สีฟ้าเรียกทรัพย์ 🩵',
      'สีส้มพลังบวก 🧡',
      'สีม่วงมหาเสน่ห์ 💜',
      'สีเหลืองทองโชคดี 💛',
    ];
    final luckyColor = luckyColors[(seed * 5 + 3) % luckyColors.length];
    final luckyNumber = ((seed * 7 + 11) % 90 + 10).toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Fortune Scores Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '🔮 ดวงการเงิน ($currentDayName)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showFortuneDetailsDialog(
                    dayName: currentDayName,
                    loveScore: loveScore,
                    moneyScore: moneyScore,
                    happinessScore: happinessScore,
                    quote: todayQuote,
                    luckyColor: luckyColor,
                    luckyNumber: luckyNumber,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔮 ดูคำทำนาย', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scores Row (Clickable to open detailed fortune)
            InkWell(
              onTap: () => _showFortuneDetailsDialog(
                dayName: currentDayName,
                loveScore: loveScore,
                moneyScore: moneyScore,
                happinessScore: happinessScore,
                quote: todayQuote,
                luckyColor: luckyColor,
                luckyNumber: luckyNumber,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('💖 ความรัก', style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('$loveScore', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('💰 ดวงการเงิน', style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('$moneyScore', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.income)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('😊 ความสุข', style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('$happinessScore', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Daily Tip Ticker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              todayQuote,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
