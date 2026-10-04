/// Outcome of uploading new photos on the requestor edit screen.
class EditPhotoUploadDecision {
  const EditPhotoUploadDecision({
    required this.shouldSaveChanges,
    this.partialSuccessMessage,
    this.allNewPhotosFailedMessage,
  });

  /// Edit saves proceed even when new photo uploads fail (text/category changes).
  final bool shouldSaveChanges;

  final String? partialSuccessMessage;

  /// Shown when every selected new photo failed but other edits were saved.
  final String? allNewPhotosFailedMessage;
}

/// Decides post-save messaging after uploading new photos on edit.
EditPhotoUploadDecision evaluateEditPhotoUpload({
  required int newPhotoCount,
  required int uploadedCount,
  required int failCount,
}) {
  if (newPhotoCount == 0) {
    return const EditPhotoUploadDecision(shouldSaveChanges: true);
  }

  if (failCount == newPhotoCount) {
    return const EditPhotoUploadDecision(
      shouldSaveChanges: true,
      allNewPhotosFailedMessage:
          'Your changes were saved, but new photos could not be uploaded. '
          'Check your connection and try again.',
    );
  }

  if (failCount > 0) {
    return EditPhotoUploadDecision(
      shouldSaveChanges: true,
      partialSuccessMessage:
          'Request updated successfully. $uploadedCount of $newPhotoCount new photos were attached.',
    );
  }

  return const EditPhotoUploadDecision(shouldSaveChanges: true);
}
