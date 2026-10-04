// Database seeder for General Maintenance Assets
// Run this once to populate the 9 facility infrastructure assets

import 'package:flutter/material.dart';
import '../config/release_safety.dart';
import '../models/asset.dart';
import '../services/unified_data_service.dart';
import '../config/locator.dart';

/// Seed general maintenance assets into the database
/// This creates 9 facility infrastructure assets that can be used for
/// maintenance work that isn't tied to specific equipment
class GeneralMaintenanceAssetSeeder {
  UnifiedDataService get _dataService => sl<UnifiedDataService>();

  /// Run the seeder to create all general maintenance assets
  Future<List<Asset>> seedAssets() async {
    if (!ReleaseSafety.allowDataSeeding) {
      throw StateError('Asset seeding is disabled in release builds');
    }

    debugPrint('ðŸŒ± Starting General Maintenance Assets Seeder...');

    final assets = _getGeneralMaintenanceAssets();
    final createdAssets = <Asset>[];

    for (final asset in assets) {
      try {
        // Check if asset already exists
        final existingAsset = _dataService.assets.firstWhere(
          (a) => a.id == asset.id,
          orElse: () => asset, // Will use the new asset if not found
        );

        if (existingAsset.id == asset.id &&
            _dataService.assets.contains(existingAsset)) {
          debugPrint(
              'â­ï¸  Asset already exists: ${asset.name} (${asset.id})',);
          createdAssets.add(existingAsset);
          continue;
        }

        // Create the asset using UnifiedDataService (dual-write: local + Firestore)
        await _dataService.createAsset(asset);
        createdAssets.add(asset);
        debugPrint('âœ… Created asset: ${asset.name} (${asset.id})');
      } catch (e, st) {
        debugPrint('âŒ Error creating asset ${asset.name}: $e');
      }
    }

    debugPrint(
      'ðŸŒ± Seeding complete! Created ${createdAssets.length} of ${assets.length} assets',
    );
    return createdAssets;
  }

  /// Get list of all general maintenance assets to seed
  List<Asset> _getGeneralMaintenanceAssets() {
    final now = DateTime.now();

    return [
      // 1. Building - General Maintenance
      Asset(
        id: 'FACILITY-GENERAL-001',
        name: 'Building - General Maintenance',
        location: 'Main Facility',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'General building maintenance not tied to specific equipment. Use for door repairs, lock replacements, minor structural work, and other general facility maintenance.',
        notes:
            'This is a virtual asset for tracking general facility maintenance costs and work orders.',
      ),

      // 2. Building - Painting & Walls
      Asset(
        id: 'FACILITY-PAINT-001',
        name: 'Building - Painting & Walls',
        location: 'Main Facility',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'Wall painting, repairs, and interior finishing work. Use for painting projects, drywall repairs, texture work, and interior decorating.',
        notes:
            'Track all painting and wall maintenance costs. Create separate work orders for different rooms/areas.',
      ),

      // 3. Building - Flooring & Surfaces
      Asset(
        id: 'FACILITY-FLOOR-001',
        name: 'Building - Flooring & Surfaces',
        location: 'Main Facility',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'Floor maintenance, tile work, and surface repairs. Use for floor waxing, tile replacement, carpet repairs, and surface refinishing.',
        notes:
            'Covers all flooring types: tile, carpet, vinyl, hardwood, concrete.',
      ),

      // 4. Facility - Plumbing System
      Asset(
        id: 'FACILITY-PLUMB-001',
        name: 'Facility - Plumbing System',
        location: 'Main Facility',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'General plumbing work not tied to specific equipment. Use for pipe repairs, drain cleaning, leak fixes, and water system maintenance.',
        notes:
            'For specific plumbing equipment (water heaters, pumps), use individual equipment assets.',
      ),

      // 5. Facility - Electrical System
      Asset(
        id: 'FACILITY-ELEC-001',
        name: 'Facility - Electrical System',
        location: 'Main Facility',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'General electrical work and lighting. Use for light fixture repairs, outlet installation, electrical panel work, wiring, and switches.',
        notes:
            'For major electrical equipment (generators, transformers), use specific equipment assets.',
      ),

      // 6. Facility - HVAC System
      Asset(
        id: 'FACILITY-HVAC-001',
        name: 'Facility - HVAC System',
        location: 'Main Facility',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'General heating, ventilation, and air conditioning. Use for AC maintenance, heating repairs, ventilation cleaning, and ductwork.',
        notes:
            'For specific HVAC units (chillers, air handlers), use individual equipment assets.',
      ),

      // 7. Facility - Grounds & Landscaping
      Asset(
        id: 'FACILITY-GROUNDS-001',
        name: 'Facility - Grounds & Landscaping',
        location: 'Exterior',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'Landscaping, grounds maintenance, and exterior work. Use for lawn care, tree trimming, parking lot repairs, and exterior painting.',
        notes:
            'Includes all outdoor facility maintenance and landscaping work.',
      ),

      // 8. Facility - Roofing System
      Asset(
        id: 'FACILITY-ROOF-001',
        name: 'Facility - Roofing System',
        location: 'Exterior',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'Roof maintenance and repairs. Use for roof leaks, shingle replacement, gutter maintenance, and drainage.',
        notes:
            'For warranted roof sections, create specific assets to track warranty periods.',
      ),

      // 9. Facility - Safety Systems
      Asset(
        id: 'FACILITY-SAFETY-001',
        name: 'Facility - Safety Systems',
        location: 'Main Facility',
        createdAt: now,
        updatedAt: now,
        category: 'Infrastructure',
        manufacturer: 'N/A',
        model: 'General',
        serialNumber: 'N/A',
        purchaseDate: now,
        installationDate: now,
        description:
            'Fire safety, emergency systems, and security. Use for general safety system work, signage installation, and emergency equipment.',
        notes:
            'For compliance-tracked items (individual fire extinguishers), create specific assets with serial numbers.',
      ),
    ];
  }

  /// Check if general maintenance assets already exist
  Future<bool> assetsExist() async {
    try {
      final facilityAssets = _dataService.assets.where(
        (asset) => asset.id.startsWith('FACILITY-'),
      );
      return facilityAssets.length >= 9;
    } catch (e, st) {
      return false;
    }
  }

  /// Get count of existing general maintenance assets
  int getExistingAssetsCount() => _dataService.assets
      .where((asset) => asset.id.startsWith('FACILITY-'))
      .length;

  /// Delete all general maintenance assets (for testing/cleanup)
  Future<void> deleteAllGeneralMaintenanceAssets() async {
    if (!ReleaseSafety.allowDestructiveAdminTools) {
      throw StateError('Asset deletion is disabled in release builds');
    }

    debugPrint('ðŸ—‘ï¸  Deleting all general maintenance assets...');

    final facilityAssets = _dataService.assets
        .where((asset) => asset.id.startsWith('FACILITY-'))
        .toList();

    for (final asset in facilityAssets) {
      try {
        await _dataService.deleteAsset(asset.id);
        debugPrint('ðŸ—‘ï¸  Deleted: ${asset.name}');
      } catch (e, st) {
        debugPrint('âŒ Error deleting ${asset.name}: $e');
      }
    }

    debugPrint('ðŸ—‘ï¸  Cleanup complete!');
  }
}

/// Helper function to run the seeder from anywhere in the app
Future<List<Asset>> seedGeneralMaintenanceAssets() async {
  final seeder = GeneralMaintenanceAssetSeeder();
  return seeder.seedAssets();
}

/// Helper function to check if assets are already seeded
Future<bool> generalMaintenanceAssetsExist() async {
  final seeder = GeneralMaintenanceAssetSeeder();
  return seeder.assetsExist();
}
