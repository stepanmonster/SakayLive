import 'package:flutter/foundation.dart';

class TripState {
  // Global singleton-like notifier for app session (survives page navigation)
  static final ValueNotifier<TripSession> session =
      ValueNotifier(const TripSession(isActive: false));

  static void start({String? busId}) {
    session.value = TripSession(
      isActive: true,
      startedAt: DateTime.now(),
      busId: busId,
    );
  }

  static void end() {
    session.value = const TripSession(isActive: false);
  }
}

@immutable
class TripSession {
  final bool isActive;
  final DateTime? startedAt;
  final String? busId;

  const TripSession({
    required this.isActive,
    this.startedAt,
    this.busId,
  });

  Duration get duration {
    if (!isActive || startedAt == null) return Duration.zero;
    return DateTime.now().difference(startedAt!);
  }
}
