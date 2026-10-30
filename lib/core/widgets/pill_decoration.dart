import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Style "pilule" des champs de texte (même look que login / inscription).
InputDecoration pillDecoration(String label, {Widget? prefix, Widget? suffix}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.7),
    border: b(const Color(0xFFBDB6C8)),
    enabledBorder: b(const Color(0xFFBDB6C8)),
    focusedBorder: b(AppTheme.purpleLight, 1.8),
    errorBorder: b(Colors.red),
    focusedErrorBorder: b(Colors.red, 1.8),
  );
}