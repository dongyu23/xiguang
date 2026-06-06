import 'package:flutter/material.dart';

class FragmentEditPage extends StatelessWidget {
  const FragmentEditPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('编辑光片: $id')));
  }
}
