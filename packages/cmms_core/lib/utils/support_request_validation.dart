class SupportRequestValidation {
  static String? requiredText(String? value, {required String fieldLabel}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldLabel';
    }
    return null;
  }

  static String? requiredSelection<T>(T? value, {required String fieldLabel}) {
    if (value == null) {
      return 'Please select $fieldLabel';
    }
    return null;
  }

  static String? requiredDate(DateTime? value) {
    if (value == null) {
      return 'Please select a date and time';
    }
    return null;
  }

  static bool isKnowHowValid({
    required String topic,
    required String question,
  }) {
    return topic.trim().isNotEmpty && question.trim().isNotEmpty;
  }

  static bool isCommissioningValid({
    required String summary,
    required DateTime? scheduledDate,
    required String address,
    required String? country,
    required String chargerSerialNumber,
    required String chargerModel,
    required String details,
  }) {
    return summary.trim().isNotEmpty &&
        scheduledDate != null &&
        address.trim().isNotEmpty &&
        country != null &&
        country.trim().isNotEmpty &&
        chargerSerialNumber.trim().isNotEmpty &&
        chargerModel.trim().isNotEmpty &&
        details.trim().isNotEmpty;
  }
}
