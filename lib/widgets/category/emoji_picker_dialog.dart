import 'package:flutter/material.dart';

class EmojiPickerDialog extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;
  
  static const List<Map<String, dynamic>> _emojiGroups = [
    {
      'title': 'ใช้บ่อย & บ้าน',
      'emojis': ['🏠', '🏡', '🏢', '🛋️', '🔑', '💡', '💧', '⚡', '🧹', '🧺', '🛒', '📦']
    },
    {
      'title': 'การเดินทาง',
      'emojis': ['🚗', '🚙', '🛵', '🚲', '🚇', '🚌', '✈️', '🚕', '⛽', '🛣️', '🔧', '🎟️']
    },
    {
      'title': 'อาหาร & เครื่องดื่ม',
      'emojis': ['🍱', '🍔', '🍕', '🍜', '🍚', '🥩', '🥗', '☕', '🧋', '🍺', '🍷', '🍎']
    },
    {
      'title': 'การเงิน & งาน',
      'emojis': ['💵', '💰', '💳', '📊', '📉', '📈', '🏛️', '💼', '💻', '🖋️', '📎', '🎁']
    },
    {
      'title': 'ช้อปปิ้ง & ไลฟ์สไตล์',
      'emojis': ['🛍️', '👗', '👕', '👟', '🕶️', '💄', '💇', '🧖', '🧴', '🎁', '🎈', '🧸']
    },
    {
      'title': 'บันเทิง & ท่องเที่ยว',
      'emojis': ['🎉', '🍻', '🍷', '🎮', '🎬', '🎧', '🎤', '🎪', '⚽', '🏂', '📸', '🗺️']
    },
    {
      'title': 'สุขภาพ & ประกัน',
      'emojis': ['💊', '🏥', '⚕️', '🩺', '🛡️', '📄', '🏋️', '🧘', '🚲', '🦷', '👓', '💤']
    },
  ];

  const EmojiPickerDialog({super.key, required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'เลือก Emoji',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: ListView.builder(
          itemCount: _emojiGroups.length,
          itemBuilder: (context, index) {
            final group = _emojiGroups[index];
            final title = group['title'] as String;
            final emojis = group['emojis'] as List<String>;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 12.0, bottom: 6.0),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, eIdx) {
                    final emoji = emojis[eIdx];
                    return InkWell(
                      onTap: () {
                        onEmojiSelected(emoji);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static void show(BuildContext context, ValueChanged<String> onEmojiSelected) {
    showDialog(
      context: context,
      builder: (context) => EmojiPickerDialog(onEmojiSelected: onEmojiSelected),
    );
  }
}
