import 'package:flutter/material.dart';
import '../heritage/heritage_palette.dart';
import '../heritage/saffron_button.dart';

/// Primary (saffron pill) and secondary (outlined pill) buttons.
/// Leave [primaryLabel] null to show only the secondary one.
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    this.primaryLabel,
    required this.secondaryLabel,
    this.onPrimary,
    required this.onSecondary,
  });

  final String? primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (primaryLabel != null) ...[
          SaffronButton(label: primaryLabel!, onPressed: onPrimary),
          const SizedBox(height: 10),
        ],
        OutlinedButton(
          onPressed: onSecondary,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: p.text,
            side: BorderSide(color: p.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          child: Text(secondaryLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
