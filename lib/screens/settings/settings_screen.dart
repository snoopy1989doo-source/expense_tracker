import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../models/user_profile.dart';
import '../category/category_management_screen.dart';
import '../wallet/wallet_management_screen.dart';
import '../couple/couple_setup_screen.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _picker = ImagePicker();

  Future<void> _pickProfileImage(String currentNickname, UserProfile? userProfile, String userId) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        final profileRepo = ref.read(userProfileRepositoryProvider);
        final updatedProfile = UserProfile(
          id: userId,
          email: userProfile?.email ?? '',
          nickname: currentNickname.isNotEmpty ? currentNickname : (userProfile?.nickname ?? 'ผู้ใช้'),
          photoBase64: base64Str,
          coupleRoomId: userProfile?.coupleRoomId,
          createdAt: userProfile?.createdAt ?? DateTime.now(),
        );
        await profileRepo.saveProfile(updatedProfile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ อัปเดตรูปโปรไฟล์สำเร็จ!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('แนบรูปโปรไฟล์ไม่สำเร็จ: $e')),
        );
      }
    }
  }

  void _editProfileDialog(UserProfile? userProfile, String userId) {
    final nicknameController = TextEditingController(text: userProfile?.nickname ?? '');
    Uint8List? tempImageBytes;
    String? tempBase64Str = userProfile?.photoBase64;

    if (tempBase64Str != null && tempBase64Str.startsWith('data:image')) {
      try {
        tempImageBytes = base64Decode(tempBase64Str.split(',').last);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('✏️ แก้ไขข้อมูลโปรไฟล์', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar Preview & Change Button
              GestureDetector(
                onTap: () async {
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                    maxWidth: 512,
                    maxHeight: 512,
                  );
                  if (pickedFile != null) {
                    final bytes = await pickedFile.readAsBytes();
                    final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    setDialogState(() {
                      tempImageBytes = bytes;
                      tempBase64Str = base64Str;
                    });
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      backgroundImage: tempImageBytes != null
                          ? MemoryImage(tempImageBytes!)
                          : (tempBase64Str != null && tempBase64Str!.startsWith('http')
                              ? NetworkImage(tempBase64Str!) as ImageProvider
                              : null),
                      child: (tempImageBytes == null && (tempBase64Str == null || !tempBase64Str!.startsWith('http')))
                          ? Text(
                              userProfile?.nickname?.isNotEmpty == true ? userProfile!.nickname.substring(0, 1) : '👤',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 28),
                            )
                          : null,
                    ),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กดที่รูปเพื่อเปลี่ยนรูปโปรไฟล์ 📸',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อเล่นของคุณในแอป',
                  hintText: 'กรอกชื่อเล่นที่ต้องการให้แสดงในสลิปและป้ายชื่อ',
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
                final newName = nicknameController.text.trim();
                if (newName.isNotEmpty) {
                  final profileRepo = ref.read(userProfileRepositoryProvider);
                  final updatedProfile = UserProfile(
                    id: userId,
                    email: userProfile?.email ?? '',
                    nickname: newName,
                    photoBase64: tempBase64Str,
                    coupleRoomId: userProfile?.coupleRoomId,
                    createdAt: userProfile?.createdAt ?? DateTime.now(),
                  );
                  await profileRepo.saveProfile(updatedProfile);
                  await ref.read(rawTransactionsProvider.notifier).updateCreatorNameForUser(userId, newName);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✨ อัปเดตข้อมูลโปรไฟล์เรียบร้อยแล้ว!')),
                    );
                  }
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
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final authState = ref.watch(authNotifierProvider);
    final coupleRoomId = ref.watch(coupleRoomIdProvider);
    final coupleRoomAsync = ref.watch(coupleRoomProvider);
    final userProfile = ref.watch(userProfileProvider).value;

    final theme = Theme.of(context);
    final userId = authState.userId ?? '';

    Uint8List? profileImageBytes;
    final photoUrl = userProfile?.photoBase64;
    if (photoUrl != null && photoUrl.startsWith('data:image')) {
      try {
        profileImageBytes = base64Decode(photoUrl.split(',').last);
      } catch (_) {}
    }

    void confirmResetCategories() {
      ConfirmDialog.show(
        context,
        title: 'รีเซ็ตหมวดหมู่เริ่มต้น',
        content: 'คุณแน่ใจว่าต้องการรีเซ็ตโครงสร้างหมวดหมู่เป็นค่าเริ่มต้นหรือไม่?\n⚠️ การรีเซ็ตจะคืนค่าหมวดหมู่มาตรฐานตามระบบ และลบหมวดหมู่ย่อยที่คุณสร้างใหม่',
        confirmText: 'ยืนยันการรีเซ็ต',
        confirmColor: AppColors.primary,
        onConfirm: () async {
          await ref.read(mainCategoriesProvider.notifier).resetToDefault();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('รีเซ็ตหมวดหมู่สำเร็จแล้ว')));
          }
        },
      );
    }

    void confirmResetOnboarding() {
      ConfirmDialog.show(
        context,
        title: 'จำลอง Onboarding ใหม่',
        content: 'ต้องการรีเซ็ตสถานะแอปเพื่อกลับไปทำตามขั้นตอนแนะนำ Onboarding อีกครั้งหรือไม่?',
        confirmText: 'รีเซ็ตและออกระบบ',
        confirmColor: AppColors.expense,
        onConfirm: () async {
          await ref.read(onboardingCompletedProvider.notifier).resetOnboarding();
          await authNotifier.signOut();
        },
      );
    }

    void confirmLogout() {
      ConfirmDialog.show(
        context,
        title: 'ออกจากระบบ',
        content: 'คุณแน่ใจว่าต้องการออกจากระบบบัญชีปัจจุบันหรือไม่?',
        confirmText: 'ออกจากระบบ',
        confirmColor: AppColors.expense,
        onConfirm: () {
          authNotifier.signOut();
        },
      );
    }

    void showGeminiApiKeyDialog() {
      final keyController = TextEditingController();

      SharedPreferences.getInstance().then((prefs) {
        keyController.text = prefs.getString('gemini_api_key') ?? '';
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Google Gemini API Key 🤖', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ใส่ Google Gemini API Key เพื่อปลดล็อกให้ AI สามารถตอบคำถามปลายเปิด, ปรึกษาวางแผนการเงินลึกๆ และคุยเล่นได้ทุกเรื่อง:',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key (AIzaSy...)',
                  hintText: 'วาง API Key ของคุณที่นี่',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '💡 รับ API Key ได้ฟรีที่ aistudio.google.com/app/apikey (มีโหมดฟรี 100%)\n*หากไม่ใส่ ระบบจะใช้ Smart Local Engine ในเครื่องให้อัตโนมัติ ปลอดภัยและแอปไม่พังแน่นอนครับ!*',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('gemini_api_key');
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('ล้างค่า API Key', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () async {
                final key = keyController.text.trim();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', key);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(key.isNotEmpty ? '✨ บันทึก Gemini API Key เรียบร้อยแล้ว' : 'สลับเป็นโหมด Local Engine')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      );
    }

    final partnerProfile = ref.watch(partnerProfileProvider).value;

    Uint8List? partnerImageBytes;
    final partnerPhotoUrl = partnerProfile?.photoBase64;
    if (partnerPhotoUrl != null && partnerPhotoUrl.startsWith('data:image')) {
      try {
        partnerImageBytes = base64Decode(partnerPhotoUrl.split(',').last);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Duo Couple Profile Card (👩‍❤️‍👨 Dual Avatars & Live Room Sync)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.14),
                  Colors.purple.withOpacity(0.06),
                  theme.colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top: Room & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💕 ห้องคู่รัก: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text(
                            coupleRoomAsync.value?.inviteCode ?? (coupleRoomId != null ? 'เชื่อมต่อแล้ว' : 'ยังไม่มีห้อง'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (coupleRoomAsync.value?.inviteCode != null)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: coupleRoomAsync.value!.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('คัดลอกโค้ดเชิญแล้ว: ${coupleRoomAsync.value!.inviteCode}')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 12, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('คัดลอกโค้ด', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Center: Duo Avatars & Love Heart Bridge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // User 1: Me
                    Expanded(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _pickProfileImage(userProfile?.nickname ?? '', userProfile, userId),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: AppColors.primary.withOpacity(0.15),
                                  backgroundImage: profileImageBytes != null
                                      ? MemoryImage(profileImageBytes)
                                      : (photoUrl != null && photoUrl.startsWith('http')
                                          ? NetworkImage(photoUrl) as ImageProvider
                                          : null),
                                  child: (profileImageBytes == null && (photoUrl == null || !photoUrl.startsWith('http')))
                                      ? Text(
                                          userProfile != null && userProfile.nickname.isNotEmpty ? userProfile.nickname.substring(0, 1) : '👤',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 24),
                                        )
                                      : null,
                                ),
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor: AppColors.primary,
                                  child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  userProfile?.nickname ?? 'ฉัน',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(left: 4),
                                icon: const Icon(Icons.edit, size: 14, color: Colors.grey),
                                tooltip: 'แก้ไขชื่อ',
                                onPressed: () => _editProfileDialog(userProfile, userId),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ฉัน (บัญชีนี้)', style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    // Heart & Connection indicator
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Text('💖', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coupleRoomAsync.value?.isFull == true ? 'เชื่อมต่อแล้ว' : 'รอคู่รัก',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: coupleRoomAsync.value?.isFull == true ? Colors.green.shade700 : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),

                    // User 2: Partner
                    Expanded(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CoupleSetupScreen()),
                              );
                            },
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: Colors.purple.withOpacity(0.15),
                                  backgroundImage: partnerImageBytes != null
                                      ? MemoryImage(partnerImageBytes)
                                      : (partnerPhotoUrl != null && partnerPhotoUrl.startsWith('http')
                                          ? NetworkImage(partnerPhotoUrl) as ImageProvider
                                          : null),
                                  child: (partnerImageBytes == null && (partnerPhotoUrl == null || !partnerPhotoUrl.startsWith('http')))
                                      ? Text(
                                          partnerProfile != null && partnerProfile.nickname.isNotEmpty
                                              ? partnerProfile.nickname.substring(0, 1)
                                              : (coupleRoomAsync.value?.isFull == true ? 'แฟน' : '➕'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                            fontSize: 22,
                                          ),
                                        )
                                      : null,
                                ),
                                if (coupleRoomAsync.value?.isFull == true)
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.green.shade600,
                                    child: const Icon(Icons.favorite, size: 11, color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            partnerProfile?.nickname ?? (coupleRoomAsync.value?.isFull == true ? 'แฟนของคุณ' : 'ยังไม่มีคู่รัก'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              partnerProfile != null ? 'แฟน 💕' : 'กดเพื่อเชิญแฟน',
                              style: TextStyle(fontSize: 9, color: Colors.purple.shade700, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom: Manage Room Button
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CoupleSetupScreen()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.settings, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          coupleRoomId != null ? 'จัดการห้องคู่รัก & โค้ดเชิญ' : 'เชื่อมต่อหรือสร้างห้องคู่รัก 💕',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Theme selection
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: theme.colorScheme.primary),
            title: const Text('โหมดมืด', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isDark ? 'เปิดใช้งานโหมดมืด' : 'ปิดใช้งานโหมดมืด'),
            trailing: Switch(
              value: isDark,
              onChanged: (val) => themeNotifier.toggleTheme(),
            ),
          ),
          const Divider(),

          // Navigation Links
          ListTile(
            leading: const Icon(Icons.category_outlined, color: AppColors.primary),
            title: const Text('จัดการหมวดหมู่หลัก & หมวดหมู่ย่อย', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('เพิ่ม แก้ไข ลบ จัดการสีและ emoji ของหมวดหมู่การจดเงิน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
            title: const Text('จัดการกระเป๋าเงิน & บัญชี', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('เพิ่ม แก้ไข ปรับยอดเงินคงเหลือ และจัดการกระเป๋าเงินทั้งหมด'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletManagementScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: AppColors.primary),
            title: const Text('ตั้งค่า Google Gemini API Key 🤖', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('ใส่ API Key เพื่อเปิดใช้งาน AI ตอบคำถามปลายเปิดและวางแผนการเงินแบบไม่จำกัด'),
            trailing: const Icon(Icons.chevron_right),
            onTap: showGeminiApiKeyDialog,
          ),
          const Divider(),

          // Database administration / reset helpers
          ListTile(
            leading: const Icon(Icons.refresh, color: AppColors.primary),
            title: const Text('รีเซ็ตหมวดหมู่เริ่มต้น', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('ย้อนโครงสร้างหมวดหมู่กลับเป็นค่าเริ่มต้นตามที่แนะนำในระบบ'),
            onTap: confirmResetCategories,
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind_outlined, color: AppColors.primary),
            title: const Text('เริ่มขั้นตอนแนะนำเริ่มต้นใหม่', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('กลับไปตอบคำถามแนะนำตั้งต้นกระเป๋าเงินและหมวดหมู่อีกครั้ง'),
            onTap: confirmResetOnboarding,
          ),
          const Divider(),

          // User detail and logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              'บัญชีผู้ใช้ปัจจุบัน: ${authState.userId ?? "Guest"}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: AppColors.expense),
            title: const Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense)),
            onTap: confirmLogout,
          ),
        ],
      ),
    );
  }
}
