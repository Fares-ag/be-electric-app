// Professional Asset Display Widget - Minimalistic and sophisticated design
// Clean, professional asset information display with modern UI patterns

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../theme/unified_design_system.dart';
import '../utils/charger_asset_filter.dart';

class ProfessionalAssetDisplayWidget extends StatefulWidget {
  const ProfessionalAssetDisplayWidget({
    required this.asset,
    super.key,
    this.connectionMethod = 'direct',
    this.showFullDetails = true,
    this.onViewDetails,
    this.onEditAsset,
    this.onSelectAsset,
    this.isCompact = false,
    this.showActions = true,
  });

  final Asset asset;
  final String connectionMethod;
  final bool showFullDetails;
  final Function(Asset)? onViewDetails;
  final Function(Asset)? onEditAsset;
  final Function(Asset)? onSelectAsset;
  final bool isCompact;
  final bool showActions;

  @override
  State<ProfessionalAssetDisplayWidget> createState() =>
      _ProfessionalAssetDisplayWidgetState();
}

class _ProfessionalAssetDisplayWidgetState
    extends State<ProfessionalAssetDisplayWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactView();
    } else {
      return _buildFullView();
    }
  }

  Widget _buildCompactView() => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.surface,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
          border: Border.all(
            color: UnifiedDesignSystem.borderColor,
          ),
        ),
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
          child: Padding(
            padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_isExpanded || widget.showFullDetails) ...[
                  const SizedBox(height: UnifiedDesignSystem.spaceM),
                  _buildDetails(),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildFullView() => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.surface,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
          border: Border.all(
            color: UnifiedDesignSystem.borderColor,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: UnifiedDesignSystem.spaceM),
              _buildDetails(),
            ],
          ),
        ),
      );

  Widget _buildHeader() => Row(
        children: [
          _buildAssetIcon(),
          const SizedBox(width: UnifiedDesignSystem.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.asset.name,
                  style: UnifiedDesignSystem.heading4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.asset.location,
                  style: UnifiedDesignSystem.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildStatusChip(),
          if (widget.showActions) ...[
            const SizedBox(width: UnifiedDesignSystem.spaceS),
            _buildActionButtons(),
          ],
        ],
      );

  Widget _buildAssetIcon() {
    // Try to show image first, fallback to icon
    if (widget.asset.imageUrl != null && widget.asset.imageUrl!.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusM),
          border: Border.all(color: UnifiedDesignSystem.borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusM),
          child: CachedNetworkImage(
            imageUrl: widget.asset.imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => ColoredBox(
              color: _getCategoryColor().withValues(alpha: 0.1),
              child: Icon(
                _getCategoryIcon(),
                color: _getCategoryColor(),
                size: 24,
              ),
            ),
            placeholder: (context, url) => ColoredBox(
              color: _getCategoryColor().withValues(alpha: 0.1),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    // Fallback to icon if no image
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getCategoryColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusM),
      ),
      child: Icon(
        _getCategoryIcon(),
        color: _getCategoryColor(),
        size: 24,
      ),
    );
  }

  Widget _buildStatusChip() => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedDesignSystem.spaceS,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusS),
          border: Border.all(
            color: _getStatusColor().withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          widget.asset.status.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _getStatusColor(),
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _buildActionButtons() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onViewDetails != null)
            _buildActionButton(
              icon: Icons.visibility_outlined,
              onPressed: () => widget.onViewDetails!(widget.asset),
              tooltip: 'View Details',
            ),
          if (widget.onSelectAsset != null)
            _buildActionButton(
              icon: Icons.check_circle_outline,
              onPressed: () => widget.onSelectAsset!(widget.asset),
              tooltip: 'Select Asset',
              color: UnifiedDesignSystem.accentGreen,
            ),
        ],
      );

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) =>
      IconButton(
        icon: Icon(icon, size: 20),
        color: color ?? UnifiedDesignSystem.textSecondary,
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      );

  Widget _buildDetails() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoGrid(),
          if (widget.asset.description != null &&
              widget.asset.description!.isNotEmpty) ...[
            const SizedBox(height: UnifiedDesignSystem.spaceM),
            _buildDescription(),
          ],
          if (widget.asset.notes != null && widget.asset.notes!.isNotEmpty) ...[
            const SizedBox(height: UnifiedDesignSystem.spaceM),
            _buildNotes(),
          ],
          if ((widget.asset.imageUrl != null &&
                  widget.asset.imageUrl!.isNotEmpty) ||
              (widget.asset.imageUrls != null &&
                  widget.asset.imageUrls!.isNotEmpty)) ...[
            const SizedBox(height: UnifiedDesignSystem.spaceM),
            _buildImageSection(),
          ],
        ],
      );

  Widget _buildInfoGrid() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.background,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusM),
        ),
        child: Column(
          children: [
            _buildInfoRow('ID', widget.asset.id),
            if (widget.asset.category != null)
              _buildInfoRow('Category', widget.asset.category!),
            if (isChargerLikeAsset(widget.asset) ||
                widget.asset.manufacturer != null)
              _buildInfoRow(
                'Manufacturer',
                isChargerLikeAsset(widget.asset)
                    ? resolveChargerManufacturer(widget.asset)
                    : widget.asset.manufacturer!,
              ),
            if (widget.asset.model != null)
              _buildInfoRow('Model', widget.asset.model!),
            if (widget.asset.serialNumber != null)
              _buildInfoRow('Serial', widget.asset.serialNumber!),
            if (widget.asset.assignedStaff != null)
              _buildInfoRow('Assigned To', widget.asset.assignedStaff!),
          ],
        ),
      );

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: UnifiedDesignSystem.bodySmall.copyWith(
                  color: UnifiedDesignSystem.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: UnifiedDesignSystem.spaceS),
            Expanded(
              child: Text(
                value,
                style: UnifiedDesignSystem.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _buildDescription() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.background,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: UnifiedDesignSystem.bodySmall.copyWith(
                color: UnifiedDesignSystem.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceS),
            Text(
              widget.asset.description!,
              style: UnifiedDesignSystem.bodyMedium,
            ),
          ],
        ),
      );

  Widget _buildNotes() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.background,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: UnifiedDesignSystem.bodySmall.copyWith(
                color: UnifiedDesignSystem.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceS),
            Text(
              widget.asset.notes!,
              style: UnifiedDesignSystem.bodyMedium,
            ),
          ],
        ),
      );

  Widget _buildImageSection() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.background,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Images',
              style: UnifiedDesignSystem.bodySmall.copyWith(
                color: UnifiedDesignSystem.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceS),
            if (widget.asset.imageUrl != null &&
                widget.asset.imageUrl!.isNotEmpty)
              _buildImagePreview(widget.asset.imageUrl!),
            if (widget.asset.imageUrls != null &&
                widget.asset.imageUrls!.isNotEmpty)
              ...widget.asset.imageUrls!.map(_buildImagePreview),
          ],
        ),
      );

  Widget _buildImagePreview(String imageUrl) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(UnifiedDesignSystem.radiusM),
                border: Border.all(color: UnifiedDesignSystem.borderColor),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(UnifiedDesignSystem.radiusM),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      const ColoredBox(
                    color: UnifiedDesignSystem.background,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 32,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  placeholder: (context, url) => const ColoredBox(
                    color: UnifiedDesignSystem.background,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              imageUrl,
              style: UnifiedDesignSystem.bodySmall.copyWith(
                color: UnifiedDesignSystem.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  IconData _getCategoryIcon() {
    final category = widget.asset.category?.toLowerCase() ?? '';
    switch (category) {
      case 'vehicle':
      case 'truck':
      case 'car':
        return Icons.directions_car;
      case 'equipment':
      case 'machine':
        return Icons.precision_manufacturing;
      case 'computer':
      case 'laptop':
        return Icons.computer;
      case 'phone':
      case 'mobile':
        return Icons.phone_android;
      case 'furniture':
        return Icons.chair;
      case 'tool':
        return Icons.build;
      default:
        return Icons.inventory_2;
    }
  }

  Color _getCategoryColor() {
    final category = widget.asset.category?.toLowerCase() ?? '';
    switch (category) {
      case 'vehicle':
      case 'truck':
      case 'car':
        return UnifiedDesignSystem.accentBlue;
      case 'equipment':
      case 'machine':
        return UnifiedDesignSystem.accentOrange;
      case 'computer':
      case 'laptop':
        return UnifiedDesignSystem.accentGreen;
      case 'phone':
      case 'mobile':
        return UnifiedDesignSystem.accentRed;
      case 'furniture':
        return UnifiedDesignSystem.textSecondary;
      case 'tool':
        return UnifiedDesignSystem.primary;
      default:
        return UnifiedDesignSystem.textSecondary;
    }
  }

  Color _getStatusColor() {
    switch (widget.asset.status.toLowerCase()) {
      case 'active':
        return UnifiedDesignSystem.accentGreen;
      case 'inactive':
        return UnifiedDesignSystem.textSecondary;
      case 'maintenance':
        return UnifiedDesignSystem.accentOrange;
      case 'pending':
        return UnifiedDesignSystem.accentBlue;
      case 'completed':
        return UnifiedDesignSystem.accentGreen;
      case 'cancelled':
        return UnifiedDesignSystem.accentRed;
      default:
        return UnifiedDesignSystem.textSecondary;
    }
  }
}
