import 'package:flutter/material.dart';

import '../../models/company.dart';
import '../../repositories/cmms_repositories.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_layout.dart';
import 'company_chargers_screen.dart';
import 'create_company_screen.dart';
import '../../utils/user_facing_errors.dart';

class CompanyManagementScreen extends StatefulWidget {
  const CompanyManagementScreen({super.key});

  @override
  State<CompanyManagementScreen> createState() => _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen> {
  List<Company> _companies = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    try {
      final companies = await CmmsRepositories.users.getAllCompanies();
      if (mounted) {
        setState(() {
          _companies = companies;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _isLoading = false);
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load companies. Please try again.',
          stackTrace: st,
          contextLabel: 'CompanyManagement: load',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<void> _deleteCompany(Company company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Company?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${company.name}"?\n\n'
          'This will set companyId to NULL for all users and assets associated with this company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await CmmsRepositories.users.deleteCompany(company.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company deleted successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          _loadCompanies();
        }
      } catch (e, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not delete company. Please try again.',
          stackTrace: st,
          contextLabel: 'CompanyManagement: delete',
          backgroundColor: AppTheme.accentRed,
        );
        }
      }
    }
  }

  List<Company> get _filteredCompanies {
    if (_searchQuery.isEmpty) return _companies;
    final query = _searchQuery.toLowerCase();
    return _companies.where((company) {
      return company.name.toLowerCase().contains(query) ||
          (company.contactEmail?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Company Management (${_companies.length})'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.darkTextColor,
        elevation: AppTheme.elevationS,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCompanies,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search companies...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Companies list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCompanies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.business,
                              size: 64,
                              color: AppTheme.secondaryTextColor,
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No companies found'
                                  : 'No companies match your search',
                              style: AppTheme.bodyText.copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? AppTheme.spacingXL : AppTheme.spacingM,
                          vertical: AppTheme.spacingM,
                        ),
                        itemCount: _filteredCompanies.length,
                        itemBuilder: (context, index) {
                          final company = _filteredCompanies[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.business,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                              title: Text(
                                company.name,
                                style: AppTheme.heading2,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (company.contactEmail != null)
                                    Text('Email: ${company.contactEmail}'),
                                  if (company.contactPhone != null)
                                    Text('Phone: ${company.contactPhone}'),
                                  if (company.address != null)
                                    Text('Address: ${company.address}'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: company.isActive
                                              ? AppTheme.accentGreen.withValues(alpha: 0.1)
                                              : AppTheme.accentRed.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          company.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: company.isActive
                                                ? AppTheme.accentGreen
                                                : AppTheme.accentRed,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CreateCompanyScreen(company: company),
                                      ),
                                    ).then((_) => _loadCompanies());
                                  } else if (value == 'chargers') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CompanyChargersScreen(company: company),
                                      ),
                                    );
                                  } else if (value == 'delete') {
                                    _deleteCompany(company);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'chargers',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.ev_station,
                                          size: 20,
                                          color: AppTheme.accentGreen,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Manage Chargers'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateCompanyScreen(),
            ),
          ).then((_) => _loadCompanies());
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Company'),
        backgroundColor: AppTheme.accentGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}


