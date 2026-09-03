import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:js_util' as js_util;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../providers/category_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../models/transaction_item.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/merchant_learning_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';

class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final TransactionItem? transaction;

  const AddEditTransactionScreen({super.key, this.transaction});

  @override
  ConsumerState<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _loveNoteController = TextEditingController();
  
  bool _isIncome = false; // False = Expense, True = Income
  DateTime _selectedDate = DateTime.now();
  String? _selectedMainCategoryId;
  String? _selectedSubCategoryId;
  String? _selectedWalletId;
  bool _isTaxDeductible = false;
  
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _existingImageUrl;
  final List<String> _receiptImagesList = []; // Multi-image support
  bool _isSaving = false;
  String? _detectedReceiverName; // AI Merchant / Receiver Quiet Memory

  // Split Bill / Multi-Category Breakdown mode 🔀
  bool _isSplitBill = false;
  final List<Map<String, dynamic>> _splitItems = [];

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toString();
      _noteController.text = tx.note ?? '';
      _loveNoteController.text = tx.loveNote ?? '';
      _isIncome = tx.type == 'income';
      _selectedDate = tx.date;
      _selectedMainCategoryId = tx.mainCategoryId;
      _selectedSubCategoryId = tx.subCategoryId;
      _selectedWalletId = tx.walletId;
      _isTaxDeductible = tx.isTaxDeductible;
      _existingImageUrl = tx.receiptImageUrl;
      if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
        _receiptImagesList.add(_existingImageUrl!);
      }
      if (_existingImageUrl != null && _existingImageUrl!.startsWith('data:image')) {
        try {
          _selectedImageBytes = base64Decode(_existingImageUrl!.split(',').last);
        } catch (_) {}
      }
    }
  }

  void _showImagePreviewDialog(String imageStr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageStr.startsWith('data:image')
                    ? Image.memory(base64Decode(imageStr.split(',').last), fit: BoxFit.contain)
                    : (imageStr.startsWith('http')
                        ? Image.network(imageStr, fit: BoxFit.contain)
                        : Image.file(File(imageStr), fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.7),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _loveNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1024,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _selectedImageBytes = bytes;
          _existingImageUrl = base64Str;
          if (!_receiptImagesList.contains(base64Str)) {
            _receiptImagesList.add(base64Str);
          }
        });
        _analyzeSlipAndAutoFill(pickedFile.name, bytes, base64Str);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เลือกรูปภาพไม่สำเร็จ: $e')),
        );
      }
    }
  }

  Future<void> _analyzeSlipAndAutoFill(String fileName, Uint8List bytes, String base64Str) async {
    final mainCats = ref.read(mainCategoriesProvider);
    final subCats = ref.read(subCategoriesProvider);
    final coupleRoomId = ref.read(coupleRoomIdProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('🤖 AI กำลังสแกนอ่านข้อความและยอดเงินจากสลิป...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }

    String extractedText = '';

    // Step 1: Direct High-Accuracy Thai Cloud OCR via HTTP
    try {
      final uri = Uri.parse('https://api.ocr.space/parse/image');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'base64Image': base64Str,
          'language': 'tha',
          'apikey': 'helloworld',
          'OCREngine': '2',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ParsedResults'] != null && (data['ParsedResults'] as List).isNotEmpty) {
          extractedText = (data['ParsedResults'][0]['ParsedText'] ?? '').toString();
          debugPrint('Dart OCR Parsed Text: $extractedText');
        }
      }
    } catch (e) {
      debugPrint('Dart OCR HTTP Notice: $e');
    }

    // Step 2: Fallback to JS Pipeline (Local PromptParse + jsQR + Tesseract)
    if (extractedText.isEmpty) {
      try {
        if (js_util.hasProperty(js_util.globalThis, 'parseSlipOCR')) {
          final promise = js_util.callMethod(js_util.globalThis, 'parseSlipOCR', [base64Str]);
          final result = await js_util.promiseToFuture(promise);
          extractedText = result.toString();
        }
      } catch (e) {
        debugPrint('JS OCR Fallback Notice: $e');
      }
    }

    final fullTextToScan = '$fileName $extractedText'.toLowerCase();
    String? matchedCategory;
    String? matchedSubCategory;
    double? matchedAmount;

    // Tier 1: Direct match from QR Tag 54 payload e.g. "จำนวนเงิน 130.00 บาท"
    final qrAmountMatch = RegExp(r'จำนวนเงิน\s+(\d{1,6}(?:,\d{3})*\.\d{2})\s+บาท', caseSensitive: false).firstMatch(extractedText);
    if (qrAmountMatch != null) {
      final str = qrAmountMatch.group(1)?.replaceAll(',', '');
      matchedAmount = double.tryParse(str ?? '');
    }

    // Tier 2: Keyword-adjacent amount e.g. "จำนวน\n130.00 บาท", "ยอดเงิน 130.00", "Amount 130.00 THB"
    if (matchedAmount == null) {
      final keywordRegexes = [
        RegExp(r'(?:จำนวน(?:เงิน)?|ยอดเงิน|ยอดโอน|ยอดรวม|โอนเงิน|จ่ายเงิน|ชำระเงิน|amount|total|paid|transfer|sum|net|payment|subtotal|grand\s*total)[\s\S]{0,35}?(\d{1,6}(?:,\d{3})*\.\d{2})', caseSensitive: false),
        RegExp(r'(\d{1,6}(?:,\d{3})*\.\d{2})\s*(?:บาท|thb|baht|฿|usd|un|vn|bade|ble)', caseSensitive: false),
      ];

      for (var regex in keywordRegexes) {
        final matches = regex.allMatches(extractedText);
        for (var m in matches) {
          final str = m.group(1)?.replaceAll(',', '');
          if (str != null) {
            final val = double.tryParse(str);
            if (val != null && val > 0 && val < 500000) {
              matchedAmount = val;
              break;
            }
          }
        }
        if (matchedAmount != null) break;
      }
    }

    // Tier 3: First positive 2-decimal number on the slip (ignoring 0.00 fee)
    if (matchedAmount == null) {
      final allDecimals = RegExp(r'(\d{1,6}(?:,\d{3})*\.\d{2})').allMatches(extractedText);
      for (var m in allDecimals) {
        final str = m.group(1)?.replaceAll(',', '');
        if (str != null) {
          final val = double.tryParse(str);
          if (val != null && val > 0 && val < 500000) {
            matchedAmount = val;
            break;
          }
        }
      }
    }

    // Auto-detect Receiver / Shop Name for AI Learning (Background Only, DO NOT pollute Note)
    final receiverRegexes = [
      RegExp(r'ถุงเงิน\s*\(([ก-๙a-zA-Z\.\s]+)\)'),
      RegExp(r'(?:ไปยัง|ผู้รับ|to)\s*:?\s*([ก-๙a-zA-Z\.\(\)\s]{3,35})', caseSensitive: false),
      RegExp(r'([ก-๙a-zA-Z\s]{3,25})\s*(?:xxx-xxx-\d{4}|xxx-x-x\d{4}-x)', caseSensitive: false),
    ];
    for (var r in receiverRegexes) {
      final m = r.firstMatch(extractedText);
      if (m != null) {
        final name = m.group(1)?.trim();
        if (name != null && name.isNotEmpty && !name.contains('make') && !name.contains('kbank')) {
          _detectedReceiverName = name;
          break;
        }
      }
    }

    // AI Prediction from learned memory
    if (_detectedReceiverName != null) {
      final memory = await MerchantLearningService.predictCategory(
        receiverOrMerchantName: _detectedReceiverName!,
        householdId: coupleRoomId,
      );
      if (memory != null && memory.mainCategoryId.isNotEmpty) {
        matchedCategory = memory.mainCategoryId;
        matchedSubCategory = memory.subCategoryId;
        debugPrint('✨ AI predicted category ${memory.mainCategoryId} from memory for $_detectedReceiverName');
      }
    }

    // Keyword rule-based fallback if AI hasn't learned yet
    if (matchedCategory == null) {
      // 1. Fuel / Gas Stations (ปตท, PTT, Oil, ปิโตรเลียม, บางจาก, เชลล์, Caltex, PT, Esso, Susco)
      if (fullTextToScan.contains('ปตท') ||
          fullTextToScan.contains('ptt') ||
          fullTextToScan.contains('ปิโตรเลียม') ||
          fullTextToScan.contains('petroleum') ||
          fullTextToScan.contains('ออยล์') ||
          fullTextToScan.contains('ออย') ||
          fullTextToScan.contains('oil') ||
          fullTextToScan.contains('น้ำมัน') ||
          fullTextToScan.contains('เชลล์') ||
          fullTextToScan.contains('shell') ||
          fullTextToScan.contains('บางจาก') ||
          fullTextToScan.contains('bangchak') ||
          fullTextToScan.contains('caltex') ||
          fullTextToScan.contains('คาลเท็กซ์') ||
          fullTextToScan.contains('ptg') ||
          fullTextToScan.contains('พีที') ||
          fullTextToScan.contains('เอสโซ่') ||
          fullTextToScan.contains('esso') ||
          fullTextToScan.contains('susco') ||
          fullTextToScan.contains('ซัสโก้')) {
        final transportCat = mainCats.firstWhere(
          (c) => c.name.contains('เดินทาง') || c.name.contains('Transport') || c.id.contains('transport') || c.name.contains('รถ'),
          orElse: () => mainCats.first,
        );
        matchedCategory = transportCat.id;

        // Find fuel subcategory
        final fuelSub = subCats.firstWhere(
          (s) => s.mainCategoryId == transportCat.id && (s.name.contains('น้ำมัน') || s.id.contains('fuel')),
          orElse: () => subCats.firstWhere((s) => s.mainCategoryId == transportCat.id, orElse: () => subCats.first),
        );
        matchedSubCategory = fuelSub.id;

        if (_noteController.text.trim().isEmpty) {
          _noteController.text = _detectedReceiverName != null && _detectedReceiverName!.isNotEmpty
              ? '$_detectedReceiverName (ค่าน้ำมัน)'
              : 'ค่าน้ำมันรถ ⛽';
        }
      } else if (fullTextToScan.contains('pea') || fullTextToScan.contains('ไฟฟ้า') || fullTextToScan.contains('ภูมิภาค')) {
        matchedCategory = mainCats.firstWhere(
          (c) => c.name.contains('ไฟ') || c.name.contains('น้ำ') || c.name.contains('Living'),
          orElse: () => mainCats.first,
        ).id;
      } else if (fullTextToScan.contains('mwa') || fullTextToScan.contains('pwa') || fullTextToScan.contains('ประปา')) {
        matchedCategory = mainCats.firstWhere(
          (c) => c.name.contains('น้ำ') || c.name.contains('ไฟ') || c.name.contains('Living'),
          orElse: () => mainCats.first,
        ).id;
      } else if (fullTextToScan.contains('true') || fullTextToScan.contains('ais') || fullTextToScan.contains('dtac') || fullTextToScan.contains('เน็ต')) {
        matchedCategory = mainCats.firstWhere(
          (c) => c.name.contains('อินเทอร์เน็ต') || c.name.contains('ไฟ'),
          orElse: () => mainCats.first,
        ).id;
      } else if (fullTextToScan.contains('อาหาร') || fullTextToScan.contains('ข้าว') || fullTextToScan.contains('cafe') || fullTextToScan.contains('ร้าน') || fullTextToScan.contains('ถุงเงิน')) {
        matchedCategory = mainCats.firstWhere(
          (c) => c.name.contains('อาหาร') || c.name.contains('กิน') || c.name.contains('Living'),
          orElse: () => mainCats.first,
        ).id;
      }
    }

    if (mounted) {
      double? finalTotalAmount;
      if (matchedAmount != null) {
        final currentVal = double.tryParse(_amountController.text.trim()) ?? 0.0;
        // If more than 1 slip attached, accumulate total!
        if (_receiptImagesList.length > 1 && currentVal > 0) {
          finalTotalAmount = currentVal + matchedAmount;
        } else {
          finalTotalAmount = matchedAmount;
        }
      }

      setState(() {
        if (finalTotalAmount != null) {
          _amountController.text = finalTotalAmount.toStringAsFixed(2);
        }
        if (matchedCategory != null) {
          _selectedMainCategoryId = matchedCategory;
          if (matchedSubCategory != null) {
            _selectedSubCategoryId = matchedSubCategory;
          }
        }
      });

      String successMsg;
      if (matchedAmount != null) {
        if (_receiptImagesList.length > 1 && finalTotalAmount != null) {
          successMsg = '✨ AI สแกนสลิปเพิ่มสำเร็จ! (+฿${matchedAmount.toStringAsFixed(2)}) รวมยอดบิลเป็น ฿${finalTotalAmount.toStringAsFixed(2)}';
        } else {
          successMsg = '✨ AI สแกนอ่านสลิปสำเร็จ! เติมยอดเงิน ฿${matchedAmount.toStringAsFixed(2)} ให้อัตโนมัติแล้ว';
        }
      } else {
        successMsg = '📸 แนบรูปสลิปเรียบร้อยแล้ว กรุณากรอกจำนวนเงิน หรือกดปุ่ม 🧮 เพื่อคิดเลขได้เลยครับ';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: matchedAmount != null ? Colors.green.shade700 : AppColors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showCalculatorDialog() {
    String calcDisplay = _amountController.text.trim();
    if (calcDisplay.isEmpty) calcDisplay = '0';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setCalcState) {
          void onBtnPress(String val) {
            setCalcState(() {
              if (val == 'C') {
                calcDisplay = '0';
              } else if (val == '⌫') {
                if (calcDisplay.length > 1) {
                  calcDisplay = calcDisplay.substring(0, calcDisplay.length - 1);
                } else {
                  calcDisplay = '0';
                }
              } else if (val == '=') {
                try {
                  final exp = calcDisplay.replaceAll('×', '*').replaceAll('÷', '/');
                  calcDisplay = _evaluateExpression(exp).toStringAsFixed(2);
                } catch (_) {}
              } else {
                if (calcDisplay == '0' && val != '.' && val != '+' && val != '-' && val != '×' && val != '÷') {
                  calcDisplay = val;
                } else {
                  calcDisplay += val;
                }
              }
            });
          }

          final buttons = [
            'C', '⌫', '÷', '×',
            '7', '8', '9', '-',
            '4', '5', '6', '+',
            '1', '2', '3', '=',
            '0', '.', '00', 'OK'
          ];

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.calculate, color: AppColors.primary),
                SizedBox(width: 8),
                Text('เครื่องคิดเลขคำนวณบิล 🧮', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      calcDisplay,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: buttons.length,
                  itemBuilder: (context, index) {
                    final btn = buttons[index];
                    final isOp = ['+', '-', '×', '÷', '='].contains(btn);
                    final isAction = ['C', '⌫', 'OK'].contains(btn);

                    return ElevatedButton(
                      onPressed: () {
                        if (btn == 'OK') {
                          try {
                            final exp = calcDisplay.replaceAll('×', '*').replaceAll('÷', '/');
                            final val = _evaluateExpression(exp);
                            _amountController.text = val.toStringAsFixed(2);
                          } catch (_) {
                            _amountController.text = calcDisplay;
                          }
                          Navigator.of(ctx).pop();
                        } else {
                          onBtnPress(btn);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btn == 'OK'
                            ? AppColors.primary
                            : (isOp ? Colors.pink.shade100 : (isAction ? Colors.grey.shade200 : Colors.white)),
                        foregroundColor: btn == 'OK' ? Colors.white : (isOp ? AppColors.primary : Colors.black),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(btn, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _evaluateExpression(String expr) {
    expr = expr.replaceAll(' ', '');
    final parts = expr.split(RegExp(r'(?<=[+-])|(?=[+-])'));
    double total = 0;
    String currentOp = '+';

    for (var part in parts) {
      if (part == '+' || part == '-') {
        currentOp = part;
      } else {
        double termVal = _evalMultDiv(part);
        if (currentOp == '+') total += termVal;
        if (currentOp == '-') total -= termVal;
      }
    }
    return total;
  }

  double _evalMultDiv(String term) {
    final factors = term.split(RegExp(r'(?<=[*/])|(?=[*/])'));
    double total = double.tryParse(factors[0]) ?? 0;
    String op = '*';

    for (int i = 1; i < factors.length; i++) {
      final f = factors[i];
      if (f == '*' || f == '/') {
        op = f;
      } else {
        final val = double.tryParse(f) ?? 1;
        if (op == '*') total *= val;
        if (op == '/') total = val != 0 ? total / val : total;
      }
    }
    return total;
  }

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _addSplitItemDialog() {
    final mainCats = ref.read(mainCategoriesProvider);
    final subCats = ref.read(subCategoriesProvider);
    String? tempMainCatId = _selectedMainCategoryId ?? (mainCats.isNotEmpty ? mainCats.first.id : null);
    String? tempSubCatId = tempMainCatId != null
        ? subCats.firstWhere((s) => s.mainCategoryId == tempMainCatId, orElse: () => subCats.first).id
        : null;

    final totalBill = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final allocatedSum = _splitItems.fold<double>(0.0, (s, item) => s + (item['amount'] as double));
    final remaining = totalBill - allocatedSum;

    final nameController = TextEditingController();
    final amountController = TextEditingController(
      text: remaining > 0 ? remaining.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSubState) {
          final filteredSubs = subCats.where((s) => s.mainCategoryId == tempMainCatId).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.call_split, color: AppColors.primary),
                SizedBox(width: 8),
                Text('➕ เพิ่มรายการย่อยในบิลนี้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (remaining > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '💡 คงเหลือที่ยังไม่ได้จัดสรร: ฿${remaining.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อรายการ (เช่น ขนม 🍦, น้ำยาปรับผ้านุ่ม 🧹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน (฿)',
                    border: OutlineInputBorder(),
                    prefixText: '฿ ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: tempMainCatId,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่หลัก', border: OutlineInputBorder()),
                  items: mainCats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}'))).toList(),
                  onChanged: (val) {
                    setSubState(() {
                      tempMainCatId = val;
                      tempSubCatId = subCats.firstWhere((s) => s.mainCategoryId == val, orElse: () => subCats.first).id;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: tempSubCatId,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่ย่อย', border: OutlineInputBorder()),
                  items: filteredSubs.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.emoji} ${s.name}'))).toList(),
                  onChanged: (val) => setSubState(() => tempSubCatId = val),
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
                  final amt = double.tryParse(amountController.text.trim()) ?? 0;
                  if (name.isNotEmpty && amt > 0 && tempMainCatId != null && tempSubCatId != null) {
                    setState(() {
                      _splitItems.add({
                        'name': name,
                        'amount': amt,
                        'mainCatId': tempMainCatId,
                        'subCatId': tempSubCatId,
                      });
                      // Intentionally do NOT overwrite _amountController.text to preserve target bill!
                    });
                    Navigator.of(ctx).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('เพิ่มรายการ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูปจากกล้อง'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isSplitBill) {
      if (_selectedMainCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกหมวดหมู่หลัก')));
        return;
      }
      if (_selectedSubCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกหมวดหมู่ย่อย')));
        return;
      }
    }
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกกระเป๋าเงิน')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isNew = widget.transaction == null;
      final userProfile = ref.read(userProfileProvider).value;
      final notifier = ref.read(rawTransactionsProvider.notifier);
      final storageRepo = ref.read(storageRepositoryProvider);

      if (_isSplitBill && _splitItems.isNotEmpty) {
        final totalBill = double.tryParse(_amountController.text.trim()) ?? 0.0;
        final allocatedSum = _splitItems.fold<double>(0.0, (s, item) => s + (item['amount'] as double));
        final remaining = totalBill - allocatedSum;

        // Multi-category bill split submission
        for (var item in _splitItems) {
          final txId = const Uuid().v4();
          final tx = TransactionItem(
            id: txId,
            type: _isIncome ? 'income' : 'expense',
            amount: item['amount'] as double,
            date: _selectedDate,
            mainCategoryId: item['mainCatId'] as String,
            subCategoryId: item['subCatId'] as String,
            walletId: _selectedWalletId!,
            note: '${item['name']}${_noteController.text.trim().isNotEmpty ? " (${_noteController.text.trim()})" : ""}',
            loveNote: _loveNoteController.text.trim().isNotEmpty ? _loveNoteController.text.trim() : null,
            receiptImageUrl: _existingImageUrl,
            isTaxDeductible: _isTaxDeductible,
            createdByUserId: userProfile?.id,
            createdByName: userProfile?.nickname ?? 'ผู้ใช้',
            createdByPhoto: userProfile?.photoBase64,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await notifier.addTransaction(tx, receiptFile: _selectedImageFile, storageRepo: storageRepo);
        }

        // Auto-allocate remaining balance if any positive remainder exists
        if (remaining > 0.01) {
          final mainCats = ref.read(mainCategoriesProvider);
          final subCats = ref.read(subCategoriesProvider);
          final defaultMain = _selectedMainCategoryId ?? (mainCats.isNotEmpty ? mainCats.first.id : '');
          final defaultSub = _selectedSubCategoryId ?? (subCats.isNotEmpty ? subCats.first.id : '');
          final remainderTx = TransactionItem(
            id: const Uuid().v4(),
            type: _isIncome ? 'income' : 'expense',
            amount: remaining,
            date: _selectedDate,
            mainCategoryId: defaultMain,
            subCategoryId: defaultSub,
            walletId: _selectedWalletId!,
            note: 'รายการอื่นๆ ในบิล${_noteController.text.trim().isNotEmpty ? " (${_noteController.text.trim()})" : ""}',
            loveNote: _loveNoteController.text.trim().isNotEmpty ? _loveNoteController.text.trim() : null,
            receiptImageUrl: _existingImageUrl,
            isTaxDeductible: _isTaxDeductible,
            createdByUserId: userProfile?.id,
            createdByName: userProfile?.nickname ?? 'ผู้ใช้',
            createdByPhoto: userProfile?.photoBase64,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await notifier.addTransaction(remainderTx, receiptFile: _selectedImageFile, storageRepo: storageRepo);
        }
      } else {
        // Single transaction submission
        final amount = double.parse(_amountController.text.trim());
        final transactionId = isNew ? const Uuid().v4() : widget.transaction!.id;

        final transaction = TransactionItem(
          id: transactionId,
          type: _isIncome ? 'income' : 'expense',
          amount: amount,
          date: _selectedDate,
          mainCategoryId: _selectedMainCategoryId!,
          subCategoryId: _selectedSubCategoryId!,
          walletId: _selectedWalletId!,
          note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
          loveNote: _loveNoteController.text.trim().isNotEmpty ? _loveNoteController.text.trim() : null,
          receiptImageUrl: _existingImageUrl,
          isTaxDeductible: _isTaxDeductible,
          createdByUserId: userProfile?.id ?? widget.transaction?.createdByUserId,
          createdByName: userProfile?.nickname ?? widget.transaction?.createdByName ?? 'ผู้ใช้',
          createdByPhoto: userProfile?.photoBase64 ?? widget.transaction?.createdByPhoto,
          createdAt: isNew ? DateTime.now() : widget.transaction!.createdAt,
          updatedAt: DateTime.now(),
        );

        if (isNew) {
          await notifier.addTransaction(transaction, receiptFile: _selectedImageFile, storageRepo: storageRepo);
        } else {
          await notifier.updateTransaction(transaction, receiptFile: _selectedImageFile, storageRepo: storageRepo);
        }
      }

      // Quiet Background AI Merchant Learning (Max 5 samples per receiver name)
      if (_detectedReceiverName != null && _selectedMainCategoryId != null) {
        final coupleRoomId = ref.read(coupleRoomIdProvider);
        MerchantLearningService.learnMerchantCategory(
          receiverOrMerchantName: _detectedReceiverName!,
          mainCategoryId: _selectedMainCategoryId!,
          subCategoryId: _selectedSubCategoryId,
          householdId: coupleRoomId,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _delete() {
    ConfirmDialog.show(
      context,
      title: 'ลบธุรกรรม',
      content: 'คุณแน่ใจหรือไม่ว่าต้องการลบรายการธุรกรรมนี้? การดำเนินการนี้ไม่สามารถย้อนกลับได้',
      confirmText: 'ลบรายการ',
      confirmColor: AppColors.expense,
      onConfirm: () async {
        setState(() => _isSaving = true);
        try {
          await ref.read(rawTransactionsProvider.notifier).deleteTransaction(widget.transaction!.id);
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบรายการไม่สำเร็จ: $e')));
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainCats = ref.watch(mainCategoriesProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final theme = Theme.of(context);

    final filteredMainCats = mainCats.where((cat) {
      if (_isIncome) {
        return cat.id.contains('income') || cat.name.contains('รายรับ') || cat.name.contains('เงิน');
      } else {
        return !cat.id.contains('income') && !cat.name.contains('รายรับ');
      }
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    final filteredSubCats = subCats
        .where((sub) => sub.mainCategoryId == _selectedMainCategoryId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'เพิ่มรายการใหม่' : 'แก้ไขรายการ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
            tooltip: 'บันทึกรายการ',
            onPressed: _isSaving ? null : _submit,
          ),
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.expense),
              onPressed: _delete,
            )
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Income / Expense selector
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isIncome = false;
                                  _selectedMainCategoryId = null;
                                  _selectedSubCategoryId = null;
                                });
                              },
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !_isIncome
                                      ? (theme.brightness == Brightness.dark ? AppColors.expenseDark.withOpacity(0.22) : AppColors.expense.withOpacity(0.12))
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
                                ),
                                child: Text(
                                  'รายจ่าย',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !_isIncome
                                        ? (theme.brightness == Brightness.dark ? AppColors.expenseDark : AppColors.expense)
                                        : theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isIncome = true;
                                  _selectedMainCategoryId = null;
                                  _selectedSubCategoryId = null;
                                });
                              },
                              borderRadius: const BorderRadius.only(topRight: Radius.circular(11), bottomRight: Radius.circular(11)),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _isIncome
                                      ? (theme.brightness == Brightness.dark ? AppColors.incomeDark.withOpacity(0.22) : AppColors.income.withOpacity(0.12))
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topRight: Radius.circular(11), bottomRight: Radius.circular(11)),
                                ),
                                child: Text(
                                  'รายรับ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isIncome
                                        ? (theme.brightness == Brightness.dark ? AppColors.incomeDark : AppColors.income)
                                        : theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── SMART SLIP SCANNER CARD (TOP OF SCREEN) ───
                    _buildSmartSlipScannerCard(context, theme),
                    const SizedBox(height: 20),

                    // Amount input with Quick Calculator Button 🧮
                    CustomTextField(
                      controller: _amountController,
                      labelText: 'จำนวนเงิน (บาท)',
                      hintText: '0.00 หรือพิมพ์นิพจน์คำนวณ เช่น 129+45',
                      prefixWidget: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '฿',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calculate, color: AppColors.primary),
                        tooltip: 'เปิดเครื่องคิดเลขคำนวณบิล 🧮',
                        onPressed: _showCalculatorDialog,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'กรุณากรอกจำนวนเงิน';
                        try {
                          final exp = val.replaceAll('×', '*').replaceAll('÷', '/');
                          final num = _evaluateExpression(exp);
                          if (num <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                        } catch (_) {
                          return 'ตัวเลขหรือนิพจน์ไม่ถูกต้อง';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Multi-Category Bill Split Toggle 🔀
                    SwitchListTile(
                      title: const Row(
                        children: [
                          Icon(Icons.call_split, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('แยกสลิปนี้ออกเป็นหลายหมวดหมู่ 🔀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      subtitle: const Text('สำหรับสลิปซูเปอร์มาร์เก็ต/บิล 1 ใบที่มีของหลายหมวด'),
                      value: _isSplitBill,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          _isSplitBill = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Split Items List view (if Split Bill mode active)
                    if (_isSplitBill) ...[
                      Builder(
                        builder: (context) {
                          final totalBill = double.tryParse(_amountController.text.trim()) ?? 0.0;
                          final allocatedSum = _splitItems.fold<double>(0.0, (s, item) => s + (item['amount'] as double));
                          final remaining = totalBill - allocatedSum;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 3 Metric Columns Overview
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildMetricTile('ยอดรวมบิล', '฿${totalBill.toStringAsFixed(2)}', theme.colorScheme.onSurface),
                                      ),
                                      Container(width: 1, height: 32, color: theme.colorScheme.outlineVariant),
                                      Expanded(
                                        child: _buildMetricTile('จัดสรรแล้ว (${_splitItems.length})', '฿${allocatedSum.toStringAsFixed(2)}', AppColors.primary),
                                      ),
                                      Container(width: 1, height: 32, color: theme.colorScheme.outlineVariant),
                                      Expanded(
                                        child: _buildMetricTile(
                                          'คงเหลือที่ยังขาด',
                                          '฿${remaining > 0 ? remaining.toStringAsFixed(2) : (remaining.abs() < 0.01 ? "0.00" : "-${(-remaining).toStringAsFixed(2)}")}',
                                          remaining > 0.01
                                              ? Colors.orange.shade800
                                              : (remaining.abs() < 0.01 ? Colors.green.shade700 : Colors.red.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Smart Status Banner / Badge
                                if (remaining > 0.01)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ยังขาดอีก ฿${remaining.toStringAsFixed(2)} กรุณากด "+ เพิ่มรายการย่อย" ให้ครบยอดบิล',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (remaining.abs() < 0.01 && _splitItems.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '🎉 จัดสรรยอดเงินครบถ้วน 100% พอดีกับบิลแล้ว!',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (remaining < -0.01)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '⚠️ ยอดรวมรายการย่อยเกินยอดบิลอยู่ ฿${(-remaining).toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),

                                // Section Header + Add Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('รายการย่อยในบิลนี้:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ElevatedButton.icon(
                                      onPressed: _addSplitItemDialog,
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('เพิ่มรายการย่อย', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                if (_splitItems.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12.0),
                                    child: Center(
                                      child: Text(
                                        'ยังไม่มีรายการย่อย กดปุ่ม "เพิ่มรายการย่อย" ด้านบนเพื่อแยกหมวดหมู่',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    children: _splitItems.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final item = entry.value;
                                      final mainCat = mainCats.firstWhere((c) => c.id == item['mainCatId'], orElse: () => mainCats.first);

                                      return Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: Colors.grey.shade200),
                                        ),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: AppColors.primary.withOpacity(0.1),
                                            child: Text(mainCat.emoji, style: const TextStyle(fontSize: 18)),
                                          ),
                                          title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          subtitle: Text(mainCat.name, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '฿${(item['amount'] as double).toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.expense),
                                                onPressed: () {
                                                  setState(() {
                                                    _splitItems.removeAt(idx);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Date & Time picker Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormatter.formatSmartDate(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormatter.formatTime(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Main & Sub Category Selector dropdowns (if NOT Split Bill mode)
                    if (!_isSplitBill) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedMainCategoryId,
                        decoration: const InputDecoration(labelText: 'หมวดหมู่หลัก'),
                        items: filteredMainCats.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Text(cat.emoji),
                                const SizedBox(width: 8),
                                Text(cat.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedMainCategoryId = val;
                            _selectedSubCategoryId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedSubCategoryId,
                        decoration: const InputDecoration(labelText: 'หมวดหมู่ย่อย'),
                        disabledHint: const Text('กรุณาเลือกหมวดหมู่หลักก่อน'),
                        items: _selectedMainCategoryId == null
                            ? []
                            : filteredSubCats.map((sub) {
                                return DropdownMenuItem<String>(
                                  value: sub.id,
                                  child: Row(
                                    children: [
                                      Text(sub.emoji),
                                      const SizedBox(width: 8),
                                      Text(sub.name),
                                    ],
                                  ),
                                );
                              }).toList(),
                        onChanged: _selectedMainCategoryId == null
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedSubCategoryId = val;
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Wallet Selector dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedWalletId,
                      decoration: const InputDecoration(labelText: 'เลือกกระเป๋าเงิน / บัญชี'),
                      items: wallets.map((wallet) {
                        return DropdownMenuItem<String>(
                          value: wallet.id,
                          child: Row(
                            children: [
                              Icon(
                                wallet.icon == 'account_balance'
                                    ? Icons.account_balance
                                    : (wallet.icon == 'payments' ? Icons.payments : Icons.credit_card),
                                color: AppColors.fromHex(wallet.color),
                              ),
                              const SizedBox(width: 8),
                              Text(wallet.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedWalletId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Note field
                    if (!_isSplitBill)
                      CustomTextField(
                        controller: _noteController,
                        labelText: 'บันทึกข้อความ / หมายเหตุ (ถ้ามี)',
                        hintText: 'กรอกหมายเหตุ หรือบันทึกเพิ่มเติมที่นี่',
                        prefixIcon: Icons.notes,
                        maxLines: 2,
                      ),
                    const SizedBox(height: 16),

                    // Love Memory Note field
                    CustomTextField(
                      controller: _loveNoteController,
                      labelText: 'ข้อความความทรงจำคู่รัก 💕 (ถ้ามี)',
                      hintText: 'พิมพ์ความประทับใจ เช่น เดตมื้อแรกของเดือน อร่อยมาก 💕',
                      prefixIcon: Icons.favorite,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Tax-deductible switch
                    SwitchListTile(
                      title: const Row(
                        children: [
                          Icon(Icons.gavel, color: AppColors.taxDeductible),
                          SizedBox(width: 8),
                          Text('ใช้ลดหย่อนภาษีได้ (Tax Deductible)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      subtitle: const Text('บันทึกยอดนี้เพื่อแยกกลุ่มคำนวณและสรุปยอดภาษีตอนส่งออกรายงาน'),
                      value: _isTaxDeductible,
                      activeColor: AppColors.taxDeductible,
                      onChanged: (val) {
                        setState(() {
                          _isTaxDeductible = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: CustomButton(
            text: widget.transaction == null ? 'บันทึกรายการ 💾' : 'บันทึกการแก้ไข 💾',
            isLoading: _isSaving,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }

  Widget _buildSmartSlipScannerCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _receiptImagesList.isNotEmpty
              ? AppColors.primary.withOpacity(0.5)
              : theme.colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Icon, Title & Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'สแกนสลิป / แนบรูปภาพ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (_receiptImagesList.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_receiptImagesList.length} สลิป',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'AI อ่านยอดเงิน & กรอกข้อมูลให้อัตโนมัติ',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: Camera & Album
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickImage(ImageSource.camera),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'ถ่ายรูปสลิป',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _pickImage(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'เลือกรูปจากอัลบั้ม',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Attached Images Thumbnails strip
          if (_receiptImagesList.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _receiptImagesList.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  if (i == _receiptImagesList.length) {
                    // Quick add another slip button
                    return InkWell(
                      onTap: _showImagePickerOptions,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, size: 20, color: theme.colorScheme.primary.withOpacity(0.7)),
                            const SizedBox(height: 2),
                            Text(
                              '+ เพิ่มรูป',
                              style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final imgStr = _receiptImagesList[i];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _showImagePreviewDialog(imgStr),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imgStr.startsWith('data:image')
                                ? Image.memory(base64Decode(imgStr.split(',').last), fit: BoxFit.cover)
                                : (imgStr.startsWith('http')
                                    ? Image.network(imgStr, fit: BoxFit.cover)
                                    : Image.file(File(imgStr), fit: BoxFit.cover)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _receiptImagesList.removeAt(i);
                            if (_receiptImagesList.isEmpty) {
                              _selectedImageFile = null;
                              _selectedImageBytes = null;
                              _existingImageUrl = null;
                            } else {
                              _existingImageUrl = _receiptImagesList.last;
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 11, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'สลิป ${i + 1}',
                            style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'อ่านสลิปแล้ว ยอดเงินและหมวดหมู่ถูกกรอกด้านล่างเรียบร้อย',
                  style: TextStyle(fontSize: 10.5, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
