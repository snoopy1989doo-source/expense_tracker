import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
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
  bool _isLoading = false;
  bool _hasGeminiKey = false;

  @override
  void initState() {
    super.initState();
    // Initial welcome message
    _messages.add({
      'sender': 'ai',
      'text': '🤖 **สวัสดีครับต๋อง & ฝน! ผมคือ AI ที่ปรึกษาการเงินคู่รัก Kapookluxx** 💕\n\n'
          'มีอะไรให้ผมช่วยสรุป วิเคราะห์หมวดย่อย หรือวางแผนงบประมาณคู่รักในวันนี้ไหมครับ?'
    });
    _checkApiKeyStatus();
  }

  Future<void> _checkApiKeyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    if (mounted) {
      setState(() {
        _hasGeminiKey = key.trim().isNotEmpty;
      });
    }
  }

  void _showApiKeyDialog() {
    final keyController = TextEditingController();
    String? testStatus;
    bool isTesting = false;

    SharedPreferences.getInstance().then((prefs) {
      keyController.text = prefs.getString('gemini_api_key') ?? '';
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Google Gemini API Key 🤖', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ใส่ Google Gemini API Key เพื่อให้ AI คุยได้เป็นธรรมชาติ วางแผนชีวิตคู่ และตอบได้ทุกเรื่อง:',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key (AIzaSy...)',
                    hintText: 'วาง API Key ที่นี่',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: isTesting
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.bolt, size: 14),
                      label: Text(isTesting ? 'กำลังทดสอบ...' : '⚡ ทดสอบ Key', style: const TextStyle(fontSize: 11)),
                      onPressed: isTesting
                          ? null
                          : () async {
                              setDialogState(() {
                                isTesting = true;
                                testStatus = null;
                              });
                              final res = await AIFinanceService.testApiKey(keyController.text);
                              setDialogState(() {
                                isTesting = false;
                                testStatus = res['message'] as String?;
                              });
                            },
                    ),
                  ],
                ),
                if (testStatus != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: testStatus!.startsWith('✅') ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      testStatus!,
                      style: TextStyle(
                        fontSize: 11,
                        color: testStatus!.startsWith('✅') ? Colors.green.shade900 : Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  '💡 รับ API Key ได้ฟรีที่ aistudio.google.com/app/apikey (โหมดฟรี 100% ไม่เสียเงิน)\n*หากไม่ใส่หรือยังไม่พร้อม ระบบจะใช้ Smart Local Mode ให้ทันที ไม่พังแน่นอนครับ*',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('gemini_api_key');
                _checkApiKeyStatus();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('ล้างค่า', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () async {
                final key = AIFinanceService.sanitizeApiKey(keyController.text);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', key);
                _checkApiKeyStatus();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(key.isNotEmpty ? '✨ บันทึก Gemini API Key เรียบร้อยแล้ว' : 'สลับเป็นโหมด Local Engine'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMsg = text.trim();
    _textController.clear();

    setState(() {
      _messages.add({'sender': 'user', 'text': userMsg});
      _isLoading = true;
    });

    final transactions = ref.read(rawTransactionsProvider);
    final categories = ref.read(mainCategoriesProvider);
    final subCategories = ref.read(subCategoriesProvider);
    final subcategoryBudgets = ref.read(subcategoryBudgetsProvider);
    final userProfile = ref.read(userProfileProvider).value;
    final partnerProfile = ref.read(partnerProfileProvider).value;

    final aiReply = await AIFinanceService.answerUserQueryAsync(
      query: userMsg,
      transactions: transactions,
      categories: categories,
      subCategories: subCategories,
      subcategoryBudgets: subcategoryBudgets,
      currentUserName: userProfile?.nickname ?? 'ต๋อง',
      partnerName: partnerProfile?.nickname ?? 'ฝน',
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add({'sender': 'ai', 'text': aiReply});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AI ที่ปรึกษาการเงินคู่รัก',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _showApiKeyDialog,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _hasGeminiKey ? Colors.green.shade50 : Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _hasGeminiKey ? Colors.green.shade300 : Colors.purple.shade200,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _hasGeminiKey ? Icons.bolt : Icons.memory,
                                    size: 10,
                                    color: _hasGeminiKey ? Colors.green.shade800 : Colors.purple,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _hasGeminiKey ? 'Gemini LLM' : 'Smart Local',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _hasGeminiKey ? Colors.green.shade800 : Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'วิเคราะห์หมวดย่อย คุมงบ และตอบคำถามต๋อง & ฝน',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.key, size: 18),
                  tooltip: 'ตั้งค่า Gemini API Key',
                  onPressed: _showApiKeyDialog,
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
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light ? Colors.pink.shade50 : const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _hasGeminiKey ? '🤖 Gemini กำลังคิดคำตอบให้ต๋อง & ฝน...' : '🤖 AI กำลังประมวลผล...',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

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
                  avatar: const Icon(Icons.favorite, size: 14, color: AppColors.primary),
                  label: const Text('💖 วันสำคัญคู่เรา (ต๋อง&ฝน)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('วันสำคัญของคู่เรา'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.pets, size: 14, color: Colors.orange),
                  label: const Text('🐱 ค่าใช้จ่ายกังฟู & โอเลี้ยง', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('ค่าใช้จ่ายน้องแมว (กังฟู & โอเลี้ยง)'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.category, size: 14, color: AppColors.primary),
                  label: const Text('🏷️ หมวดย่อยใช้อะไรเยอะสุด?', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('หมวดย่อยใช้อะไรเยอะสุด'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.track_changes, size: 14, color: AppColors.primary),
                  label: const Text('🎯 เช็กสถานะงบหมวดย่อย', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('เช็กสถานะงบประมาณหมวดย่อย'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('📊 สรุปหมวดหลัก', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('ใช้เงินหมวดอะไรเยอะสุด'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('👫 สถิติการจ่ายของคู่เรา', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('ใครเป็นคนจ่ายเงินมากกว่ากันในเดือนนี้'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('💰 สรุปภาพรวมเดือนนี้', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendMessage('เดือนนี้เราใช้เงินเท่าไหร่'),
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
