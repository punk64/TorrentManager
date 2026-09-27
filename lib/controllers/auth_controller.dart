import 'package:get/get.dart';

import '../data/local/local_store.dart';
import '../utils/app_log.dart';
import '../utils/log_text.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final error = RxnString();

  final account = Rxn<LocalAccount>();

  @override
  void onInit() {
    super.onInit();
    restore();
  }

  Future<void> restore() async {
    account.value = await LocalStore.loadAccount();
  }

  bool get isSignedIn => account.value != null;

  String get displayName => account.value?.displayName ?? 'Signed in';

  String get provider => account.value?.provider ?? '';

  Future<bool> signInWithProvider(String providerName, {String? name}) async {
    try {
      isLoading.value = true;
      error.value = null;
      final String display =
          (name == null || name.trim().isEmpty) ? providerName : name.trim();
      final LocalAccount a = LocalAccount(
        displayName: display,
        provider: providerName,
        signedInAt: DateTime.now().millisecondsSinceEpoch,
      );
      await LocalStore.saveAccount(a);
      account.value = a;
      AppLog.instance.op(LogT.accountCreated(display, providerName));
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signInWithGoogle({String? name}) =>
      signInWithProvider('Google', name: name);

  Future<bool> signInWithMicrosoft({String? name}) =>
      signInWithProvider('Microsoft', name: name);

  Future<void> rename(String name) async {
    final LocalAccount? a = account.value;
    if (a == null || name.trim().isEmpty) return;
    final LocalAccount updated = a.copyWith(displayName: name.trim());
    await LocalStore.saveAccount(updated);
    account.value = updated;
    AppLog.instance.op(LogT.accountRenamed(a.displayName, updated.displayName));
  }

  Future<void> signOut() async {
    await LocalStore.clearAccount();
    account.value = null;
    AppLog.instance.op(LogT.accountSignedOut());
  }
}
