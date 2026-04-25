class LocalNotificationService {
  const LocalNotificationService();

  Future<void> initialize() async {
    // Wire flutter_local_notifications initialization after the package and
    // Android notification permission setup are added.
  }

  Future<void> showTestNotification() async {
    // Show a local test notification after notification setup is ready.
  }

  Future<void> scheduleBillReminder({
    required String billId,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    // Schedule bill reminders after local notification setup is ready.
  }
}
