import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../providers/category_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction_item.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
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
  bool _isSaving = false;

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
      if (_existingImageUrl != null && _existingImageUrl!.startsWith('data:image')) {
        try {
          _selectedImageBytes = base64Decode(_existingImageUrl!.split(',').last);
        } catch (_) {}
      }
    }
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
          duration: Duration(seconds: 3),
        ),
      );
    }

    String extractedText = '';

    try {
      if (js.context.hasProperty('parseSlipOCR')) {
        final promise = js.context.callMethod('parseSlipOCR', [base64Str]);
        final result = await js_util.promiseToFuture(promise);
        extractedText = result.toString();
      }
    } catch (e) {
      debugPrint('OCR JS Exception: $e');
    }

    final fullTextToScan = '$fileName $extractedText'.toLowerCase();
    String? matchedCategory;
    String? matchedNote;
    double? matchedAmount;

    // Amount extraction regex
    final amountRegex = RegExp(r'(\d{1,3}(?:,\d{3})*\.\d{2})');
    final matches = amountRegex.allMatches(extractedText);
    for (var m in matches) {
      final parsed = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (parsed != null && parsed > 0) {
        matchedAmount = parsed;
        break;
      }
    }

    if (fullTextToScan.contains('pea') || fullTextToScan.contains('ไฟฟ้า') || fullTextToScan.contains('ภูมิภาค')) {
      matchedNote = 'ค่าไฟฟ้าส่วนภูมิภาค';
      matchedCategory = mainCats.firstWhere(
        (c) => c.name.contains('ไฟ') || c.name.contains('น้ำ') || c.name.contains('Living'),
        orElse: () => mainCats.first,
      ).id;
    } else if (fullTextToScan.contains('mwa') || fullTextToScan.contains('pwa') || fullTextToScan.contains('ประปา')) {
      matchedNote = 'ค่าน้ำประปา';
      matchedCategory = mainCats.firstWhere(
        (c) => c.name.contains('น้ำ') || c.name.contains('ไฟ') || c.name.contains('Living'),
        orElse: () => mainCats.first,
      ).id;
    } else if (fullTextToScan.contains('true') || fullTextToScan.contains('ais') || fullTextToScan.contains('dtac') || fullTextToScan.contains('เน็ต')) {
      matchedNote = 'ค่าอินเทอร์เน็ต / โทรศัพท์';
      matchedCategory = mainCats.firstWhere(
        (c) => c.name.contains('อินเทอร์เน็ต') || c.name.contains('ไฟ'),
        orElse: () => mainCats.first,
      ).id;
    } else if (fullTextToScan.contains('อาหาร') || fullTextToScan.contains('ข้าว') || fullTextToScan.contains('cafe') || fullTextToScan.contains('ร้าน')) {
      matchedNote = 'ค่าอาหาร/กินดื่ม';
      matchedCategory = mainCats.firstWhere(
        (c) => c.name.contains('อาหาร') || c.name.contains('กิน') || c.name.contains('Living'),
        orElse: () => mainCats.first,
      ).id;
    }

    if (mounted) {
      setState(() {
        if (matchedAmount != null) {
          _amountController.text = matchedAmount.toStringAsFixed(2);
        }
        if (matchedCategory != null) {
          _selectedMainCategoryId = matchedCategory;
        }
        if (matchedNote != null && _noteController.text.isEmpty) {
          _noteController.text = matchedNote;
        }
      });

      final successMsg = matchedAmount != null
          ? '✨ AI อ่านสลิปสำเร็จ! พบยอดเงิน ฿${matchedAmount.toStringAsFixed(2)} (${matchedNote ?? "เลือกหมวดหมู่อัตโนมัติ"})'
          : '✨ AI สแกนสลิปสำเร็จ! เติมหมวดหมู่ให้อัตโนมัติ (สามารถปรับแก้ได้ก่อนบันทึก)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
    if (_selectedMainCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกหมวดหมู่หลัก')));
      return;
    }
    if (_selectedSubCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกหมวดหมู่ย่อย')));
      return;
    }
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกกระเป๋าเงิน')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final isNew = widget.transaction == null;
      final transactionId = isNew ? const Uuid().v4() : widget.transaction!.id;
      final userProfile = ref.read(userProfileProvider).value;

      final transaction = TransactionItem(
        id: transactionId,
        type: _isIncome ? 'income' : 'expense',
        amount: amount,
        date: _selectedDate,
        mainCategoryId: _selectedMainCategoryId!,
        subCategoryId: _selectedSubCategoryId!,
        walletId: _selectedWalletId!,
        note: _noteController.text.trim(),
        loveNote: _loveNoteController.text.trim().isNotEmpty ? _loveNoteController.text.trim() : null,
        receiptImageUrl: _existingImageUrl,
        isTaxDeductible: _isTaxDeductible,
        createdByUserId: userProfile?.id ?? widget.transaction?.createdByUserId,
        createdByName: userProfile?.nickname ?? widget.transaction?.createdByName ?? 'ผู้ใช้',
        createdByPhoto: userProfile?.photoBase64 ?? widget.transaction?.createdByPhoto,
        createdAt: isNew ? DateTime.now() : widget.transaction!.createdAt,
        updatedAt: DateTime.now(),
      );

      final notifier = ref.read(rawTransactionsProvider.notifier);
      final storageRepo = ref.read(storageRepositoryProvider);

      if (isNew) {
        await notifier.addTransaction(transaction, receiptFile: _selectedImageFile, storageRepo: storageRepo);
      } else {
        await notifier.updateTransaction(transaction, receiptFile: _selectedImageFile, storageRepo: storageRepo);
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

    // Filter main categories by income/expense type
    final filteredMainCats = mainCats.where((cat) {
      if (_isIncome) {
        return cat.id.contains('income') || cat.name.contains('รายรับ') || cat.name.contains('เงิน');
      } else {
        return !cat.id.contains('income') && !cat.name.contains('รายรับ');
      }
    }).toList();

    // Cascaded subcategories based on selected main category
    final filteredSubCats = subCats.where((sub) => sub.mainCategoryId == _selectedMainCategoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'เพิ่มรายการใหม่' : 'แก้ไขรายการ'),
        actions: [
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
                padding: const EdgeInsets.all(20.0),
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
                                  color: !_isIncome ? AppColors.expense.withOpacity(0.12) : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
                                ),
                                child: Text(
                                  'รายจ่าย',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !_isIncome ? AppColors.expense : theme.colorScheme.onSurface.withOpacity(0.6),
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
                                  color: _isIncome ? AppColors.income.withOpacity(0.12) : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topRight: Radius.circular(11), bottomRight: Radius.circular(11)),
                                ),
                                child: Text(
                                  'รายรับ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isIncome ? AppColors.income : theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount input
                    CustomTextField(
                      controller: _amountController,
                      labelText: 'จำนวนเงิน (บาท)',
                      hintText: '0.00',
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'กรุณากรอกจำนวนเงิน';
                        final num = double.tryParse(val);
                        if (num == null) return 'ตัวเลขไม่ถูกต้อง';
                        if (num <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

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

                    // Main Category Selector dropdown
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
                          _selectedSubCategoryId = null; // reset subcategory on main change
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Sub Category Selector dropdown
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

                    // Receipt Upload section
                    const Text('รูปภาพใบเสร็จ / หลักฐานการจ่ายเงิน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _showImagePickerOptions,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outlineVariant, style: BorderStyle.values[1]),
                          borderRadius: BorderRadius.circular(16),
                          color: theme.colorScheme.surface,
                        ),
                        child: _selectedImageBytes != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.memory(
                                      _selectedImageBytes!,
                                      width: double.infinity,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black.withOpacity(0.6),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.white),
                                        onPressed: () => setState(() {
                                          _selectedImageFile = null;
                                          _selectedImageBytes = null;
                                          _existingImageUrl = null;
                                        }),
                                      ),
                                    ),
                                  )
                                ],
                              )
                            : (_existingImageUrl != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: _existingImageUrl!.startsWith('data:image')
                                            ? Image.memory(
                                                base64Decode(_existingImageUrl!.split(',').last),
                                                width: double.infinity,
                                                height: 160,
                                                fit: BoxFit.cover,
                                              )
                                            : (_existingImageUrl!.startsWith('http')
                                                ? Image.network(_existingImageUrl!, width: double.infinity, height: 160, fit: BoxFit.cover)
                                                : Image.file(File(_existingImageUrl!), width: double.infinity, height: 160, fit: BoxFit.cover)),
                                      ),
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withOpacity(0.6),
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.white),
                                            onPressed: () => setState(() {
                                              _selectedImageFile = null;
                                              _selectedImageBytes = null;
                                              _existingImageUrl = null;
                                            }),
                                          ),
                                        ),
                                      )
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 40, color: theme.colorScheme.primary.withOpacity(0.6)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'กดที่นี่เพื่อถ่ายรูปหรือแนบใบเสร็จ',
                                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                                      ),
                                    ],
                                  )),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick AI Slip Recognition Buttons
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'AI ช่วยเลือกหมวดหมู่จากประเภทสลิปโอนเงิน:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                avatar: const Text('⚡', style: TextStyle(fontSize: 12)),
                                label: const Text('สลิปค่าไฟ (PEA)', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  final mainCats = ref.read(mainCategoriesProvider);
                                  final cat = mainCats.firstWhere((c) => c.name.contains('ไฟ') || c.name.contains('น้ำ') || c.name.contains('Living'), orElse: () => mainCats.first);
                                  setState(() {
                                    _selectedMainCategoryId = cat.id;
                                    if (_noteController.text.isEmpty) _noteController.text = 'ค่าไฟฟ้าส่วนภูมิภาค';
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const Text('💧', style: TextStyle(fontSize: 12)),
                                label: const Text('สลิปค่าน้ำ (MWA)', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  final mainCats = ref.read(mainCategoriesProvider);
                                  final cat = mainCats.firstWhere((c) => c.name.contains('น้ำ') || c.name.contains('ไฟ') || c.name.contains('Living'), orElse: () => mainCats.first);
                                  setState(() {
                                    _selectedMainCategoryId = cat.id;
                                    if (_noteController.text.isEmpty) _noteController.text = 'ค่าน้ำประปา';
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const Text('🍚', style: TextStyle(fontSize: 12)),
                                label: const Text('สลิปค่าอาหาร/กาแฟ', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  final mainCats = ref.read(mainCategoriesProvider);
                                  final cat = mainCats.firstWhere((c) => c.name.contains('อาหาร') || c.name.contains('กิน') || c.name.contains('Living'), orElse: () => mainCats.first);
                                  setState(() {
                                    _selectedMainCategoryId = cat.id;
                                    if (_noteController.text.isEmpty) _noteController.text = 'ค่าอาหาร/กินดื่ม';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    CustomButton(
                      text: 'บันทึกรายการ',
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
