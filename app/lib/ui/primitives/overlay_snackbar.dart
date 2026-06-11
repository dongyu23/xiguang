import 'package:flutter/material.dart';

/// 显示 SnackBar，自动关闭当前正在显示的消息（覆盖而非排队）。
void showOverlaySnackBar(BuildContext context, SnackBar snackBar) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
