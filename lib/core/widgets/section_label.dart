import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// `// SECTION TITLE ─────── trailing?`
///
/// Ports the design's mono "//" prefix + fading rule + optional trailing tag.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            '// ${title.toUpperCase()}',
            style: LbType.sectionLabel,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1, color: LbColors.borderMuted)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(child: trailing!),
        ],
      ],
    );
  }
}
