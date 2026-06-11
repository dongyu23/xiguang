import 'package:flutter/material.dart';

/// Root navigator key shared across the app.
/// Used for navigation from within ShellRoute branches to top-level routes (e.g. logout).
final rootNavigatorKey = GlobalKey<NavigatorState>();
