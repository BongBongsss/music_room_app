import 'package:flutter/material.dart';

class VisitNameInput extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const VisitNameInput({
    super.key,
    required this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: '성함',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
