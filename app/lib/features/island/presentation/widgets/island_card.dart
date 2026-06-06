import 'package:flutter/material.dart';

class IslandCard extends StatelessWidget {
  const IslandCard({
    super.key,
    required this.name,
    required this.fragmentCount,
  });

  final String name;
  final int fragmentCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(name), trailing: Text('$fragmentCount'));
  }
}
