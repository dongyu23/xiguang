import 'package:flutter/material.dart';

import '../design/themes/theme.dart';
import '../design/themes/extensions/blur_theme.dart';
import '../design/themes/extensions/glow_theme.dart';
import '../design/themes/extensions/space_theme.dart';
import 'router.dart';

class XiguangApp extends StatelessWidget {
  const XiguangApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '隙光',
      theme: xiguangTheme().copyWith(
        extensions: [
          BlurTheme.light(),
          GlowTheme.default_(),
          SpaceTheme.default_(),
        ],
      ),
      routerConfig: router,
    );
  }
}
