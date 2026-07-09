import 'package:flutter/material.dart';

import 'fragment_detail_page.dart';

class FragmentEditPage extends StatelessWidget {
  const FragmentEditPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => FragmentDetailPage(id: id);
}
