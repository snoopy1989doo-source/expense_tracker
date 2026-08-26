import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_finance_service.dart';
import '../../core/constants/app_colors.dart';

class AIChatDialog extends ConsumerStatefulWidget {
  const AIChatDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AIChatDialog(),
    );
  }

  @override
  ConsumerState<AIChatDialog> createState() => _AIChatDialogState();
}

class _AIChatDialogState extends ConsumerState<AIChatDialog> {
  final _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    // Initial welcome message
    _messages.add({
      'sender': 'ai',
      'text': '🤖 **สวัสดีครับ! ผมคือ AI ที่ปรึกษาการเงินคู่รัก Kapookluxx** 💕\n\n'
          'มีอะไรให้ผมช่วยสรุปหรือวิเคราะห์ข้อมูลการเงินของคู่คุณในวันนี้ไหมครับ?'
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMsg = text.trim();
    _textController.clear();

    setState(() {
      _messages.add({'sender': 'user', 'text': userMsg});
    });

    final transactions = ref.read(rawTransactionsProvider);
    final categories = ref.read(mainCategoriesProvider);
    final userProfile = ref.read(userProfileProvider).value;

    final aiReply = AIFinanceService.answerUserQuery(
      query: userMsg,
      transactions: transactions,
      categories: categories,
      currentUserName: userProfile?.nickname,
    );

    setState(() {
      _messages.add({'sender': 'ai', 'text': aiReply});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottomInsets),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI ที่ปรึกษาการเงินคู่รัก',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'ถาม-ตอบข้อมูลการเงิน และวิเคราะห์งบประหยัดคู่รัก',
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
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.primary
                          : (theme.brightness == Brightness.light ? Colors.pink.shade50 : const Color(0xFF2C2C2C)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isUser ? Colors.white : theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Suggestion Chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ActionChip(
                  label: const Text('💰 เดือนนี้เราใช้เงินเท่าไหร่?', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('เดือนนี้เราใช้เงินเท่าไหร่'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('👫 ใครเป็นคนจ่ายเยอะกว่า?', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('ใครเป็นคนจ่ายเงินมากกว่ากันในเดือนนี้'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('🍚 หมวดอาหารใช้ไปเท่าไหร่?', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('ค่าอาหารเดือนนี้เท่าไหร่'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Input Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ถาม AI เช่น สรุปรายจ่ายเดือนนี้...',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
