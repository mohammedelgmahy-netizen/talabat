import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/addresses/domain/address.dart';
import '../../features/addresses/presentation/address_form_page.dart';
import '../../features/addresses/presentation/addresses_page.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/profile_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/catalog/domain/entities.dart';
import '../../features/catalog/presentation/home_page.dart';
import '../../features/catalog/presentation/store_page.dart';
import '../../features/driver/presentation/driver_delivery_page.dart';
import '../../features/driver/presentation/driver_history_page.dart';
import '../../features/driver/presentation/driver_home_page.dart';
import '../../features/orders/presentation/my_orders_page.dart';
import '../../features/orders/presentation/order_tracking_page.dart';
import '../../features/store_owner/presentation/store_orders_page.dart';
import '../widgets/common.dart';
import 'shells.dart';

String homeFor(UserRole role) => switch (role) {
      UserRole.client => '/client',
      UserRole.driver => '/driver',
      UserRole.storeOwner => '/store',
      UserRole.admin => '/admin',
    };

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthPage = loc == '/login' || loc == '/register';
      switch (session.status) {
        case SessionStatus.loading:
          return loc == '/splash' ? null : '/splash';
        case SessionStatus.signedOut:
          return isAuthPage ? null : '/login';
        case SessionStatus.signedIn:
          final home = homeFor(session.user!.role);
          // كل دور يشوف المسارات الخاصة به فقط
          if (isAuthPage || loc == '/splash' || !loc.startsWith(home)) return home;
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: LoadingView())),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),

      // ---------------- العميل ----------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RoleShell(shell: shell, destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'طلباتي'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ]),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/client', builder: (_, _) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/client/orders', builder: (_, _) => const MyOrdersPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/client/profile',
              builder: (_, _) => const ProfilePage(),
              routes: [GoRoute(path: 'addresses', builder: (_, _) => const AddressesPage())],
            ),
          ]),
        ],
      ),
      GoRoute(path: '/client/store/:id', builder: (_, s) => StorePage(store: s.extra! as Store)),
      GoRoute(path: '/client/cart', builder: (_, _) => const CartPage()),
      GoRoute(path: '/client/orders/:id', builder: (_, s) => OrderTrackingPage(orderId: s.pathParameters['id']!)),
      GoRoute(path: '/client/addresses/select', builder: (_, _) => const AddressesPage(selectMode: true)),
      GoRoute(path: '/client/addresses/new', builder: (_, _) => const AddressFormPage()),
      GoRoute(path: '/client/addresses/edit', builder: (_, s) => AddressFormPage(initial: s.extra as Address?)),

      // ---------------- السائق ----------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RoleShell(shell: shell, destinations: const [
          NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'الشحنات'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'أرباحي'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ]),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/driver', builder: (_, _) => const DriverHomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/driver/earnings', builder: (_, _) => const DriverHistoryPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/driver/profile', builder: (_, _) => const ProfilePage())]),
        ],
      ),
      GoRoute(path: '/driver/delivery/:orderId', builder: (_, s) => DriverDeliveryPage(orderId: s.pathParameters['orderId']!)),

      // ---------------- صاحب المتجر ----------------
      GoRoute(path: '/store', builder: (_, _) => const StoreOrdersPage()),

      // ---------------- الأدمن (يستخدم لوحة الويب) ----------------
      GoRoute(path: '/admin', builder: (_, _) => const _AdminNotice()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _AdminNotice extends ConsumerWidget {
  const _AdminNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.admin_panel_settings, size: 64),
            const SizedBox(height: 12),
            const Text('حساب المدير يعمل من لوحة التحكم على الويب'),
            TextButton(onPressed: () => ref.read(sessionProvider).signOut(), child: const Text('تسجيل الخروج')),
          ]),
        ),
      );
}
