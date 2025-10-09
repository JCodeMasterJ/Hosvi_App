enum FeedbackMode { voiceBeep, vibrationOnly, silent }

extension FeedbackModeX on FeedbackMode {
  String get label => switch (this) {
    FeedbackMode.voiceBeep => "Voz + Beep",
    FeedbackMode.vibrationOnly => "Sólo vibración",
    FeedbackMode.silent => "Silencio",
  };

  FeedbackMode next() => switch (this) {
    FeedbackMode.voiceBeep => FeedbackMode.vibrationOnly,
    FeedbackMode.vibrationOnly => FeedbackMode.silent,
    FeedbackMode.silent => FeedbackMode.voiceBeep,
  };
}
