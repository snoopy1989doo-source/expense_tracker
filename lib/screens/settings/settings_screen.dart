import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../category/category_management_screen.dart';
import '../wallet/wallet_management_screen.dart';
import '../couple/couple_setup_screen.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final authState = ref.watch(authNotifierProvider);
    final coupleRoomId = ref.watch(coupleRoomIdProvider);
    final coupleRoomAsync = ref.watch(coupleRoomProvider);

    final theme = Theme.of(context);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Couple Room Management Section (💕)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.08),
                  theme.colorScheme.primary.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text('💕', style: TextStyle(fontSize: 18)),
              ),
              title: Text(
                coupleRoomId != null ? 'ห้องคู่รัก (Kapookluxx Room)' : 'เชื่อมต่อกับแฟน (ห้องคู่รัก)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: coupleRoomAsync.when(
                data: (room) {
                  if (room == null) {
                    return const Text('สร้างห้องใหม่ หรือกรอกโค้ดเพื่อเริ่มบันทึกเงินร่วมกัน');
                  }
                  final memberCount = room.memberIds.length;
                  return Text('รหัสเชิญแฟน: ${room.inviteCode} (${memberCount}/2 คน)');
                },
                loading: () => const Text('กำลังโหลดข้อมูลห้องคู่รัก...'),
                error: (_, __) => const Text('กดเพื่อสร้างหรือเชื่อมต่อห้องคู่รัก'),
              ),
              trailing: coupleRoomAsync.value?.inviteCode != null
                  ? IconButton(
                      icon: const Icon(Icons.copy, color: AppColors.primary),
                      tooltip: 'คัดลอกโค้ดเชิญ',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: coupleRoomAsync.value!.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('คัดลอกโค้ดเชิญแล้ว: ${coupleRoomAsync.value!.inviteCode}')),
                        );
                      },
                    )
                  : const Icon(Icons.chevron_right, color: AppColors.primary),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoupleSetupScreen()),
                );
              },
            ),
          ),
          const Divider(),

          // Theme selection
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: theme.colorScheme.primary),
            title: const Text('โหมดมืด (Dark Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
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
            title: const Text('เริ่มขั้นตอน Onboarding ใหม่', style: TextStyle(fontWeight: FontWeight.bold)),
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
