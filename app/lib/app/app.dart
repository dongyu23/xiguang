import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/themes/theme.dart';
import '../design/themes/extensions/blur_theme.dart';
import '../design/themes/extensions/glow_theme.dart';
import '../design/themes/extensions/space_theme.dart';
import 'router.dart';

class XiguangApp extends ConsumerStatefulWidget {
  const XiguangApp({super.key});

  @override
  ConsumerState<XiguangApp> createState() => _XiguangAppState();
}

class _XiguangAppState extends ConsumerState<XiguangApp> {
  late final _router = createRouter(ref);

  @override
  Widget build(BuildContext context) {
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
      routerConfig: _router,
    );
  }
}
