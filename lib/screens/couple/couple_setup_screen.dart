import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/couple_provider.dart';
import '../../providers/auth_provider.dart';

class CoupleSetupScreen extends ConsumerStatefulWidget {
  const CoupleSetupScreen({super.key});

  @override
  ConsumerState<CoupleSetupScreen> createState() => _CoupleSetupScreenState();
}

class _CoupleSetupScreenState extends ConsumerState<CoupleSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coupleState = ref.watch(coupleNotifierProvider);

    // Listen for errors/success
    ref.listen<CoupleState>(coupleNotifierProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(coupleNotifierProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 24),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('💕', style: TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'เชื่อมต่อกับแฟน',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'สร้างห้องใหม่หรือเข้าร่วมห้องของแฟนคุณ',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                  tabs: const [
                    Tab(text: 'สร้างห้องใหม่'),
                    Tab(text: 'เข้าร่วมด้วยโค้ด'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CreateRoomTab(coupleState: coupleState),
                    _JoinRoomTab(
                      codeController: _codeController,
                      formKey: _formKey,
                      coupleState: coupleState,
                    ),
                  ],
                ),
              ),

              // Sign out option
              TextButton(
                onPressed: () {
                  ref.read(authNotifierProvider.notifier).signOut();
                },
                child: Text(
                  'ออกจากระบบ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Create Room Tab ──────────────────────────────────────────────────────────

class _CreateRoomTab extends ConsumerWidget {
  final CoupleState coupleState;

  const _CreateRoomTab({required this.coupleState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (coupleState.inviteCode != null) {
      // Show invite code
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
          const SizedBox(height: 16),
          Text(
            'สร้างห้องสำเร็จแล้ว!',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'แชร์โค้ดด้านล่างให้แฟนของคุณ',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
            child: Text(
              coupleState.inviteCode!,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: coupleState.inviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('คัดลอกโค้ดแล้ว!')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('คัดลอกโค้ด'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'รอให้แฟนกรอกโค้ดนี้ในหน้า "เข้าร่วมด้วยโค้ด"\nแล้วแอปจะเชื่อมต่อโดยอัตโนมัติ 💕',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_home_rounded,
          size: 72,
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
        const SizedBox(height: 20),
        Text(
          'คุณจะเป็นเจ้าของห้อง',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'ระบบจะสร้างรหัสเชิญ 6 หลัก\nสำหรับแชร์ให้แฟนของคุณเข้าร่วม',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: coupleState.isLoading
                ? null
                : () => ref.read(coupleNotifierProvider.notifier).createRoom(),
            icon: coupleState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.favorite_rounded),
            label: Text(coupleState.isLoading ? 'กำลังสร้าง...' : 'สร้างห้องคู่รัก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Join Room Tab ─────────────────────────────────────────────────────────────

class _JoinRoomTab extends ConsumerWidget {
  final TextEditingController codeController;
  final GlobalKey<FormState> formKey;
  final CoupleState coupleState;

  const _JoinRoomTab({
    required this.codeController,
    required this.formKey,
    required this.coupleState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_rounded,
            size: 72,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'กรอกรหัสเชิญจากแฟน',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ขอรหัส 6 หลักจากแฟนของคุณ\nเพื่อเข้าร่วมห้องคู่รัก',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: codeController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: TextStyle(
                letterSpacing: 6,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              counterText: '',
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'กรุณากรอกรหัสเชิญ';
              if (val.length != 6) return 'รหัสต้องมี 6 หลัก';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: coupleState.isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        final success = await ref
                            .read(coupleNotifierProvider.notifier)
                            .joinRoom(codeController.text.trim().toUpperCase());
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('เชื่อมต่อกับแฟนสำเร็จ! 💕'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
              icon: coupleState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.favorite_rounded),
              label: Text(coupleState.isLoading ? 'กำลังเชื่อมต่อ...' : 'เข้าร่วมห้องคู่รัก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
