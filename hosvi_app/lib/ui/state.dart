import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/feedback_mode.dart';

final feedbackModeProvider = StateProvider<FeedbackMode>((ref) {
  return FeedbackMode.voiceBeep;
});
