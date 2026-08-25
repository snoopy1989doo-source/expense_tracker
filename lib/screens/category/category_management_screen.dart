import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/category_provider.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/category/color_picker_dialog.dart';
import '../../widgets/category/emoji_picker_dialog.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  Color _dialogColor = AppColors.categoryPalette.first;
  String _dialogEmoji = '📁';
  String? _dialogParentCategoryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showAddEditMainCategoryDialog([MainCategory? existing]) {
    _nameController.text = existing?.name ?? '';
    _dialogColor = existing != null ? AppColors.fromHex(existing.color) : AppColors.categoryPalette.first;
    _dialogEmoji = existing?.emoji ?? '📁';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'เพิ่มหมวดหมู่หลัก' : 'แก้ไขหมวดหมู่หลัก'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อหมวดหมู่หลัก',
                  hintText: 'เช่น ค่ากินดื่ม, เสื้อผ้า',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('สีหมวดหมู่', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => ColorPickerDialog.show(context, (color) {
                          setDialogState(() => _dialogColor = color);
                        }),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: _dialogColor, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Emoji', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => EmojiPickerDialog.show(context, (emoji) {
                          setDialogState(() => _dialogEmoji = emoji);
                        }),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            shape: BoxShape.circle,
                          ),
                          child: Text(_dialogEmoji, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty) {
                  final cat = MainCategory(
                    id: existing?.id ?? 'main_cat_${const Uuid().v4()}',
                    name: _nameController.text.trim(),
                    color: AppColors.toHex(_dialogColor),
                    emoji: _dialogEmoji,
                    order: existing?.order ?? 99,
                    createdAt: existing?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  if (existing == null) {
                    ref.read(mainCategoriesProvider.notifier).addCategory(cat);
                  } else {
                    ref.read(mainCategoriesProvider.notifier).updateCategory(cat);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditSubCategoryDialog([SubCategory? existing]) {
    final mainCats = ref.read(mainCategoriesProvider);
    if (mainCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาสร้างหมวดหมู่หลักก่อนสร้างหมวดย่อย')));
      return;
    }

    _nameController.text = existing?.name ?? '';
    _dialogEmoji = existing?.emoji ?? '📄';
    _dialogParentCategoryId = existing?.mainCategoryId ?? mainCats.first.id;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final parentCat = mainCats.firstWhere((c) => c.id == _dialogParentCategoryId);
          return AlertDialog(
            title: Text(existing == null ? 'เพิ่มหมวดหมู่อย่างละเอียด (ย่อย)' : 'แก้ไขหมวดหมู่ย่อย'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _dialogParentCategoryId,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่หลัก'),
                  items: mainCats.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Text(cat.emoji),
                          const SizedBox(width: 8),
                          Text(cat.name, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _dialogParentCategoryId = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อหมวดหมู่ย่อย',
                    hintText: 'เช่น ค่านม, ชานมไข่มุก',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Emoji: '),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => EmojiPickerDialog.show(context, (emoji) {
                        setDialogState(() => _dialogEmoji = emoji);
                      }),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          shape: BoxShape.circle,
                        ),
                        child: Text(_dialogEmoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty && _dialogParentCategoryId != null) {
                    final sub = SubCategory(
                      id: existing?.id ?? 'sub_cat_${const Uuid().v4()}',
                      mainCategoryId: _dialogParentCategoryId!,
                      name: _nameController.text.trim(),
                      emoji: _dialogEmoji,
                      color: parentCat.color, // inherit
                      order: existing?.order ?? 99,
                    );
                    if (existing == null) {
                      ref.read(subCategoriesProvider.notifier).addSubCategory(sub);
                    } else {
                      ref.read(subCategoriesProvider.notifier).updateSubCategory(sub);
                    }
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteMainCategory(MainCategory cat) {
    ConfirmDialog.show(
      context,
      title: 'ลบหมวดหมู่หลัก',
      content: 'คุณแน่ใจว่าต้องการลบหมวดหมู่ "${cat.name}" หรือไม่?\n⚠️ การลบหมวดหมู่หลักจะทำการลบหมวดหมู่ย่อยทั้งหมดที่อยู่ในกลุ่มนี้ด้วย',
      confirmText: 'ลบข้อมูล',
      confirmColor: AppColors.expense,
      onConfirm: () {
        ref.read(mainCategoriesProvider.notifier).deleteCategory(cat.id);
      },
    );
  }

  void _confirmDeleteSubCategory(SubCategory sub) {
    ConfirmDialog.show(
      context,
      title: 'ลบหมวดหมู่ย่อย',
      content: 'คุณแน่ใจว่าต้องการลบหมวดหมู่ย่อย "${sub.name}" หรือไม่?',
      confirmText: 'ลบข้อมูล',
      confirmColor: AppColors.expense,
      onConfirm: () {
        ref.read(subCategoriesProvider.notifier).deleteSubCategory(sub.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainCats = ref.watch(mainCategoriesProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการหมวดหมู่'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'หมวดหมู่หลัก'),
            Tab(text: 'หมวดหมู่ย่อย'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Main categories (Reorderable)
          mainCats.isEmpty
              ? const Center(child: Text('ไม่มีหมวดหมู่หลัก'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mainCats.length,
                  onReorder: (oldIndex, newIndex) {
                    final items = List<MainCategory>.from(mainCats);
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    ref.read(mainCategoriesProvider.notifier).reorderCategories(items);
                  },
                  itemBuilder: (context, index) {
                    final cat = mainCats[index];
                    final catColor = AppColors.fromHex(cat.color);
                    return Card(
                      key: ValueKey(cat.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_handle, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: catColor.withOpacity(0.12),
                              child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          ],
                        ),
                        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddEditMainCategoryDialog(cat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.expense, size: 20),
                              onPressed: () => _confirmDeleteMainCategory(cat),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // Tab 2: Sub categories (Reorderable per Main Category)
          subCats.isEmpty && mainCats.isEmpty
              ? const Center(child: Text('ไม่มีหมวดหมู่ย่อย'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mainCats.length,
                  itemBuilder: (context, index) {
                    final parent = mainCats[index];
                    final subsInParent = subCats.where((s) => s.mainCategoryId == parent.id).toList()
                      ..sort((a, b) => a.order.compareTo(b.order));

                    return ExpansionTile(
                      key: ValueKey('parent_${parent.id}'),
                      title: Row(
                        children: [
                          Text(parent.emoji),
                          const SizedBox(width: 8),
                          Text(parent.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Text('(${subsInParent.length})', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                      childrenPadding: const EdgeInsets.only(left: 12, bottom: 8),
                      children: [
                        if (subsInParent.isEmpty)
                          const ListTile(
                            title: Text('ไม่มีหมวดหมู่ย่อย', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          )
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: subsInParent.length,
                            onReorder: (oldIndex, newIndex) {
                              final items = List<SubCategory>.from(subsInParent);
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final item = items.removeAt(oldIndex);
                              items.insert(newIndex, item);
                              ref.read(subCategoriesProvider.notifier).reorderSubCategories(items);
                            },
                            itemBuilder: (context, subIndex) {
                              final sub = subsInParent[subIndex];
                              return ListTile(
                                key: ValueKey(sub.id),
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.drag_handle, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                                    const SizedBox(width: 8),
                                    Text(sub.emoji, style: const TextStyle(fontSize: 16)),
                                  ],
                                ),
                                title: Text(sub.name, style: const TextStyle(fontSize: 14)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _showAddEditSubCategoryDialog(sub),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: AppColors.expense, size: 18),
                                      onPressed: () => _confirmDeleteSubCategory(sub),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddEditMainCategoryDialog();
          } else {
            _showAddEditSubCategoryDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
