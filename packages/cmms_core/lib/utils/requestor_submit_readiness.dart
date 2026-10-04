import '../config/cmms_app_mode.dart';
import '../models/asset.dart';
import '../models/user.dart';
import 'app_role_policy.dart';
import 'requestor_company_policy.dart';
import 'requestor_work_order_asset.dart';
import 'review_photo_upload_decision.dart';

/// Result of evaluating whether a requestor may proceed with submit.
class RequestorSubmitReadiness {
  const RequestorSubmitReadiness({
    required this.canProceed,
    this.dialogTitle,
    this.dialogMessage,
    this.partialPhotoMessage,
  });

  final bool canProceed;
  final String? dialogTitle;
  final String? dialogMessage;
  final String? partialPhotoMessage;
}

const String kRequestorSubmitNotAuthenticatedMessage =
    'User not authenticated';

/// Checks session + company assignment before photo upload begins.
RequestorSubmitReadiness evaluateRequestorSubmitPreUpload({User? user}) {
  if (user == null) {
    return const RequestorSubmitReadiness(
      canProceed: false,
      dialogTitle: 'Sign in required',
      dialogMessage: kRequestorSubmitNotAuthenticatedMessage,
    );
  }

  final companyGate = validateRequestorCompanyAssignment(
    role: user.role,
    companyId: user.companyId,
  );
  if (!companyGate.allowed) {
    return RequestorSubmitReadiness(
      canProceed: false,
      dialogTitle: 'Company required',
      dialogMessage: companyGate.userMessage,
    );
  }

  return const RequestorSubmitReadiness(canProceed: true);
}

/// Checks photo upload outcome and registered asset linkage after uploads.
RequestorSubmitReadiness evaluateRequestorSubmitPostUpload({
  required Asset asset,
  required int selectedPhotoCount,
  required int uploadedCount,
  required int failCount,
}) {
  final uploadDecision = evaluateReviewPhotoUpload(
    selectedPhotoCount: selectedPhotoCount,
    uploadedCount: uploadedCount,
    failCount: failCount,
  );

  if (!uploadDecision.shouldCreateWorkOrder) {
    return RequestorSubmitReadiness(
      canProceed: false,
      dialogTitle: 'Photos not uploaded',
      dialogMessage: uploadDecision.failureMessage,
    );
  }

  if (resolveRequestorWorkOrderAssetSubmission(asset) == null) {
    return const RequestorSubmitReadiness(
      canProceed: false,
      dialogTitle: 'Charger required',
      dialogMessage:
          'This request must be linked to a registered charger. '
          'Go back and select a charger from the list.',
    );
  }

  return RequestorSubmitReadiness(
    canProceed: true,
    partialPhotoMessage: uploadDecision.partialSuccessMessage,
  );
}

/// Whether an authenticated user may enter the requestor app shell.
RequestorSubmitReadiness evaluateRequestorAppAccess({User? user}) {
  if (user == null) {
    return const RequestorSubmitReadiness(
      canProceed: false,
      dialogMessage: kRequestorSubmitNotAuthenticatedMessage,
    );
  }

  if (!isRoleAllowedForAppMode(
    role: user.role,
    appMode: CmmsAppMode.requestor,
  )) {
    return RequestorSubmitReadiness(
      canProceed: false,
      dialogMessage: wrongAppRoleMessage(
        role: user.role,
        appMode: CmmsAppMode.requestor,
      ),
    );
  }

  return const RequestorSubmitReadiness(canProceed: true);
}
