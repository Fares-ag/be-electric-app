// Enhanced Asset Display Widget - Comprehensive asset information display
// Shows ALL fields from your 1,238 assets with rich visual formatting

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/unified_design_system.dart';
import '../utils/app_theme.dart';
import '../utils/charger_asset_filter.dart';

class ComprehensiveAssetDisplayWidget extends StatefulWidget {
  const ComprehensiveAssetDisplayWidget({
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
  State<ComprehensiveAssetDisplayWidget> createState() =>
      _ComprehensiveAssetDisplayWidgetState();
}

class _ComprehensiveAssetDisplayWidgetState
    extends State<ComprehensiveAssetDisplayWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactView();
    } else {
      return _buildFullView();
    }
  }

  Widget _buildCompactView() => Card(
        elevation: UnifiedDesignSystem.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: _buildAssetIcon(),
          title: Text(
            widget.asset.name,
            style: UnifiedDesignSystem.heading4,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show Asset Tag (QR Code) prominently for chargers
              if (widget.asset.qrCode != null && widget.asset.qrCode!.isNotEmpty)
                Text(
                  'Asset Tag: ${widget.asset.qrCode}',
                  style: UnifiedDesignSystem.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentGreen,
                  ),
                ),
              // Show QR Code ID if different from qrCode
              if (widget.asset.qrCodeId != null && 
                  widget.asset.qrCodeId!.isNotEmpty &&
                  widget.asset.qrCodeId != widget.asset.qrCode)
                Text(
                  'Asset Number: ${widget.asset.qrCodeId}',
                  style: UnifiedDesignSystem.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                'ID: ${widget.asset.id}',
                style: UnifiedDesignSystem.bodyMedium,
              ),
              Text(
                'Location: ${widget.asset.location}',
                style: UnifiedDesignSystem.bodyMedium,
              ),
              // Show manufacturer and model for chargers
              if (isChargerLikeAsset(widget.asset) ||
                  widget.asset.manufacturer != null)
                Text(
                  'Manufacturer: ${isChargerLikeAsset(widget.asset) ? resolveChargerManufacturer(widget.asset) : widget.asset.manufacturer}',
                  style: UnifiedDesignSystem.bodyMedium,
                ),
              if (widget.asset.model != null)
                Text(
                  'Model: ${widget.asset.model}',
                  style: UnifiedDesignSystem.bodyMedium,
                ),
              if (widget.asset.serialNumber != null)
                Text(
                  'Serial: ${widget.asset.serialNumber}',
                  style: UnifiedDesignSystem.bodyMedium,
                ),
              if (widget.asset.category != null)
                Text(
                  'Category: ${widget.asset.category!}',
                  style: UnifiedDesignSystem.bodyMedium,
                ),
            ],
          ),
          trailing: widget.showActions
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onViewDetails != null)
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: UnifiedDesignSystem.textSecondary,
                        ),
                        onPressed: () => widget.onViewDetails!(widget.asset),
                        tooltip: 'View Details',
                      ),
                    if (widget.onSelectAsset != null)
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: UnifiedDesignSystem.accentGreen,
                        ),
                        onPressed: () => widget.onSelectAsset!(widget.asset),
                        tooltip: 'Select Asset',
                      ),
                  ],
                )
              : null,
          onTap: () => setState(() => _isExpanded = !_isExpanded),
        ),
      );

  Widget _buildFullView() => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_isExpanded || widget.showFullDetails) ...[
              const Divider(),
              _buildAssetSections(),
            ],
            if (widget.showActions) _buildActionButtons(),
          ],
        ),
      );

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            _buildAssetIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.asset.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.asset.id}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (widget.asset.location.isNotEmpty)
                    Text(
                      'Location: ${widget.asset.location}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            if (!widget.showFullDetails)
              IconButton(
                icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
          ],
        ),
      );

  Widget _buildAssetIcon() {
    // Try to show image first, fallback to icon
    if (widget.asset.imageUrl != null && widget.asset.imageUrl!.isNotEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: widget.asset.imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => ColoredBox(
              color: _getStatusColor().withValues(alpha: 0.2),
              child: Icon(
                _getAssetIcon(),
                color: _getStatusColor(),
                size: 24,
              ),
            ),
            placeholder: (context, url) => ColoredBox(
              color: _getStatusColor().withValues(alpha: 0.2),
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getAssetIcon(),
        color: _getStatusColor(),
        size: 24,
      ),
    );
  }

  IconData _getAssetIcon() {
    final category = widget.asset.category?.toLowerCase() ?? '';
    if (category.contains('vehicle') || category.contains('car')) {
      return Icons.directions_car;
    } else if (category.contains('furniture')) {
      return Icons.chair;
    } else if (category.contains('equipment') || category.contains('machine')) {
      return Icons.precision_manufacturing;
    } else if (category.contains('computer') || category.contains('laptop')) {
      return Icons.computer;
    } else if (category.contains('tool')) {
      return Icons.build;
    } else {
      return Icons.inventory_2;
    }
  }

  Color _getStatusColor() {
    final status = widget.asset.status.toLowerCase();
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      case 'maintenance':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAssetSections() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 16),
            _buildLocationAssignmentSection(),
            const SizedBox(height: 16),
            _buildFinancialSection(),
            const SizedBox(height: 16),
            _buildTechnicalSection(),
            const SizedBox(height: 16),
            _buildMaintenanceSection(),
            const SizedBox(height: 16),
            _buildVehicleSection(),
            const SizedBox(height: 16),
            _buildSystemInfoSection(),
            const SizedBox(height: 16),
            _buildImageSection(),
            const SizedBox(height: 16),
            _buildMetadataSection(),
          ],
        ),
      );

  Widget _buildBasicInfoSection() => _buildSection(
        'Basic Information',
        Icons.info_outline,
        [
          _buildInfoRow('ID', widget.asset.id),
          _buildInfoRow('Name', widget.asset.name),
          _buildInfoRow('Category', widget.asset.category),
          _buildInfoRow('Status', widget.asset.status),
          _buildInfoRow('Condition', widget.asset.condition),
          _buildInfoRow('Description', widget.asset.description),
        ],
      );

  Widget _buildLocationAssignmentSection() => _buildSection(
        'Location & Assignment',
        Icons.location_on,
        [
          _buildInfoRow('Location', widget.asset.location),
          _buildInfoRow('Department', widget.asset.department),
          _buildInfoRow('Assigned Staff', widget.asset.assignedStaff),
          _buildInfoRow('Company', widget.asset.company),
        ],
      );

  Widget _buildFinancialSection() => _buildSection(
        'Financial Information',
        Icons.attach_money,
        [
          _buildInfoRow(
            'Purchase Price',
            widget.asset.purchasePrice?.toString(),
          ),
          _buildInfoRow('Current Value', widget.asset.currentValue?.toString()),
          _buildInfoRow('Purchase Date', widget.asset.purchaseDate?.toString()),
          _buildInfoRow('Supplier', widget.asset.supplier),
          _buildInfoRow('Vendor', widget.asset.vendor),
          _buildInfoRow('Warranty', widget.asset.warranty),
          _buildInfoRow(
            'Warranty Expiry',
            widget.asset.warrantyExpiry?.toString(),
          ),
        ],
      );

  Widget _buildTechnicalSection() => _buildSection(
        'Technical Details',
        Icons.engineering,
        [
          _buildInfoRow(
            'Manufacturer',
            isChargerLikeAsset(widget.asset)
                ? resolveChargerManufacturer(widget.asset)
                : widget.asset.manufacturer,
          ),
          _buildInfoRow('Model', widget.asset.model),
          _buildInfoRow('Serial Number', widget.asset.serialNumber),
          _buildInfoRow('Model Year', widget.asset.modelYear?.toString()),
          _buildInfoRow('Item Type', widget.asset.itemType),
        ],
      );

  Widget _buildMaintenanceSection() => _buildSection(
        'Maintenance',
        Icons.build,
        [
          _buildInfoRow(
            'Last Maintenance',
            widget.asset.lastMaintenanceDate?.toString(),
          ),
          _buildInfoRow(
            'Next Maintenance',
            widget.asset.nextMaintenanceDate?.toString(),
          ),
          _buildInfoRow(
            'Maintenance Schedule',
            widget.asset.maintenanceSchedule,
          ),
          _buildInfoRow('Mileage', widget.asset.mileage?.toString()),
          _buildInfoRow(
            'Installation Date',
            widget.asset.installationDate?.toString(),
          ),
        ],
      );

  Widget _buildVehicleSection() => _buildSection(
        'Vehicle Information',
        Icons.directions_car,
        [
          _buildInfoRow('Vehicle ID', widget.asset.vehicleIdNo),
          _buildInfoRow('License Plate', widget.asset.licPlate),
          _buildInfoRow('Vehicle Model', widget.asset.vehicleModel),
          _buildInfoRow('Model Description', widget.asset.modelDesc),
        ],
      );

  Widget _buildSystemInfoSection() => _buildSection(
        'System Information',
        Icons.qr_code,
        [
          _buildInfoRow('QR Code', widget.asset.qrCode),
          _buildInfoRow('QR Code ID', widget.asset.qrCodeId),
        ],
      );

  Widget _buildImageSection() {
    final hasImages = (widget.asset.imageUrl != null &&
            widget.asset.imageUrl!.isNotEmpty) ||
        (widget.asset.imageUrls != null && widget.asset.imageUrls!.isNotEmpty);

    if (!hasImages) return const SizedBox.shrink();

    return _buildSection(
      'Images',
      Icons.photo_library,
      [
        if (widget.asset.imageUrl != null && widget.asset.imageUrl!.isNotEmpty)
          _buildImagePreview(widget.asset.imageUrl!),
        if (widget.asset.imageUrls != null &&
            widget.asset.imageUrls!.isNotEmpty)
          ...widget.asset.imageUrls!.map(_buildImagePreview),
      ],
    );
  }

  Widget _buildImagePreview(String imageUrl) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => ColoredBox(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  placeholder: (context, url) => ColoredBox(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Image URL: $imageUrl',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  Widget _buildMetadataSection() => _buildSection(
        'Metadata',
        Icons.info,
        [
          _buildInfoRow('Created At', widget.asset.createdAt.toString()),
          _buildInfoRow('Updated At', widget.asset.updatedAt.toString()),
          _buildInfoRow('Connection Method', widget.connectionMethod),
          _buildInfoRow('Notes', widget.asset.notes),
        ],
      );

  Widget _buildSection(String title, IconData icon, List<Widget> children) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      );

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.onViewDetails != null)
              ElevatedButton.icon(
                onPressed: () => widget.onViewDetails!(widget.asset),
                icon: const Icon(Icons.info_outline),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            if (widget.onEditAsset != null)
              ElevatedButton.icon(
                onPressed: () => widget.onEditAsset!(widget.asset),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            if (widget.onSelectAsset != null)
              ElevatedButton.icon(
                onPressed: () => widget.onSelectAsset!(widget.asset),
                icon: const Icon(Icons.check_circle),
                label: const Text('Select'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      );
}
