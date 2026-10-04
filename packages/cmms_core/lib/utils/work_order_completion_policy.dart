/// Work order completion rules for the technician completion screen (T-004).
///
/// Option A: technician signature required; requestor signature deferred.
class WorkOrderCompletionPolicy {
  const WorkOrderCompletionPolicy._();

  /// When false, technicians may set `status = completed` without requestor sign-off.
  static const bool requireRequestorSignatureOnTechnicianComplete = false;

  static bool canSubmitTechnicianCompletion({
    required String? technicianSignature,
    String? requestorSignature,
  }) {
    final tech = technicianSignature?.trim();
    if (tech == null || tech.isEmpty) {
      return false;
    }
    if (requireRequestorSignatureOnTechnicianComplete) {
      final req = requestorSignature?.trim();
      if (req == null || req.isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// User-facing validation message when [canSubmitTechnicianCompletion] is false.
  static String? blockingMessage({
    required String? technicianSignature,
    String? requestorSignature,
  }) {
    final tech = technicianSignature?.trim();
    if (tech == null || tech.isEmpty) {
      return 'Technician signature is required';
    }
    if (requireRequestorSignatureOnTechnicianComplete) {
      final req = requestorSignature?.trim();
      if (req == null || req.isEmpty) {
        return 'Requestor signature is required';
      }
    }
    return null;
  }
}
