/// Validates that a requestor account is linked to a company before WO create.

const String kRequestorMissingCompanyMessage =
    'Your account is not linked to a company. '
    'Contact your administrator before submitting requests.';

class RequestorCompanyGate {
  const RequestorCompanyGate({
    required this.allowed,
    this.userMessage,
  });

  final bool allowed;
  final String? userMessage;
}

RequestorCompanyGate validateRequestorCompanyAssignment({
  required String role,
  required String? companyId,
}) {
  if (role.toLowerCase() != 'requestor') {
    return const RequestorCompanyGate(allowed: true);
  }

  final id = companyId?.trim();
  if (id == null || id.isEmpty) {
    return const RequestorCompanyGate(
      allowed: false,
      userMessage: kRequestorMissingCompanyMessage,
    );
  }

  return const RequestorCompanyGate(allowed: true);
}
