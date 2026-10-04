import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/responsive_layout.dart';

class SupportFormField extends StatelessWidget {
  const SupportFormField({
    required this.label,
    required this.controller,
    super.key,
    this.hintText,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textInputAction: textInputAction,
          style: TextStyle(
            color: Colors.black,
            fontSize: isDesktop ? 15 : 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: isDesktop ? 15 : 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: isDesktop ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: const Color(0xFF424242),
                width: isDesktop ? 2.5 : 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12,
            ),
          ),
        ),
      ],
    );
  }
}

class SupportCountryDropdown extends StatelessWidget {
  const SupportCountryDropdown({
    required this.label,
    required this.value,
    required this.countries,
    required this.onChanged,
    super.key,
    this.validator,
  });

  final String label;
  final String? value;
  final List<String> countries;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        DropdownButtonFormField<String>(
          initialValue: value,
          style: TextStyle(
            color: Colors.black,
            fontSize: isDesktop ? 15 : 14,
          ),
          decoration: InputDecoration(
            hintText: 'Select country',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: isDesktop ? 15 : 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: isDesktop ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: const Color(0xFF424242),
                width: isDesktop ? 2.5 : 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12,
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          ),
          items: countries
              .map(
                (country) => DropdownMenuItem<String>(
                  value: country,
                  child: Text(country),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}
