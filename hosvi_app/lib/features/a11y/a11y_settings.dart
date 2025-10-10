import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class A11ySettings {
  final bool highContrast;    // “filtro” alto contraste
  final double textScale;     // 1.0 – 1.6
  final double iconScale;     // 1.0 – 1.6
  final bool bigTargets;      // botones más altos
  final double ttsRate;       // 0.5 = lento, 1.0 = normal

  const A11ySettings({
    this.highContrast = false,
    this.textScale = 1.0,
    this.iconScale = 1.0,
    this.bigTargets = false,
    this.ttsRate = 1.0,
  });

  A11ySettings copyWith({
    bool? highContrast,
    double? textScale,
    double? iconScale,
    bool? bigTargets,
    double? ttsRate,
  }) => A11ySettings(
    highContrast: highContrast ?? this.highContrast,
    textScale: textScale ?? this.textScale,
    iconScale: iconScale ?? this.iconScale,
    bigTargets: bigTargets ?? this.bigTargets,
    ttsRate: ttsRate ?? this.ttsRate,
  );
}

class A11yController extends StateNotifier<A11ySettings> {
  A11yController() : super(const A11ySettings());

  void setHighContrast(bool v) => state = state.copyWith(highContrast: v);
  void setTextScale(double v)   => state = state.copyWith(textScale: v.clamp(1.0, 1.8));
  void setIconScale(double v)   => state = state.copyWith(iconScale: v.clamp(1.0, 1.8));
  void setBigTargets(bool v)    => state = state.copyWith(bigTargets: v);
  void setTtsRate(double v)     => state = state.copyWith(ttsRate: v.clamp(0.5, 1.25));
}

final a11yProvider = StateNotifierProvider<A11yController, A11ySettings>(
      (ref) => A11yController(),
);
