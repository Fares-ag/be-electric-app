import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parts_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/parts_request_service.dart';
import '../../utils/app_theme.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';

class PartsRequestQueueScreen extends StatefulWidget {
  const PartsRequestQueueScreen({super.key});

  @override
  State<PartsRequestQueueScreen> createState() =>
      _PartsRequestQueueScreenState();
}

class _PartsRequestQueueScreenState extends State<PartsRequestQueueScreen> {
  final PartsRequestService _service = sl<PartsRequestService>();
  StreamSubscription<List<PartsRequest>>? _realtimeSub;
  bool _loading = false;
  List<PartsRequest> _requests = [];
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = _service.requestsChanged.listen((all) {
      if (!mounted) return;
      setState(() {
        _requests = _applyFilter(all, _filter);
      });
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _service.getAllPartsRequests();
      setState(() {
        _requests = _applyFilter(all, _filter);
      });
      if (_service.lastListFromCache && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _service.lastListError ??
                  'Showing cached parts requests. Cloud refresh failed.',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load requests. Please try again.',
          stackTrace: st,
          contextLabel: 'PartsRequestQueue: load requests',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PartsRequest> _applyFilter(List<PartsRequest> all, String filter) {
    switch (filter) {
      case 'approved':
        return all
            .where((r) => r.status == PartsRequestStatus.approved)
            .toList();
      case 'rejected':
        return all
            .where((r) => r.status == PartsRequestStatus.rejected)
            .toList();
      case 'fulfilled':
        return all
            .where((r) => r.status == PartsRequestStatus.fulfilled)
            .toList();
      case 'pending':
      default:
        return all
            .where((r) => r.status == PartsRequestStatus.pending)
            .toList();
    }
  }

  Future<void> _approve(PartsRequest r) async {
    final approverId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (approverId == null || approverId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in required to approve requests'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.approvePartsRequest(
        requestId: r.id,
        approvedBy: approverId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Approval failed. Please try again.',
          stackTrace: st,
          contextLabel: 'PartsRequestQueue: approve request',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject(PartsRequest r) async {
    final approverId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (approverId == null || approverId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in required to reject requests'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return;
    }
    var reason = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Reason'),
          onChanged: (v) => reason = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject'),),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _service.rejectPartsRequest(
        requestId: r.id,
        rejectedBy: approverId,
        rejectionReason: reason.isEmpty ? 'Not specified' : reason,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Rejection failed. Please try again.',
          stackTrace: st,
          contextLabel: 'PartsRequestQueue: reject request',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Parts Request Queue'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.darkTextColor,
          elevation: AppTheme.elevationS,
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                setState(() {
                  _filter = v;
                  _requests = _applyFilter(_requests, _filter);
                });
                _load();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'pending', child: Text('Pending')),
                PopupMenuItem(value: 'approved', child: Text('Approved')),
                PopupMenuItem(value: 'rejected', child: Text('Rejected')),
                PopupMenuItem(value: 'fulfilled', child: Text('Fulfilled')),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _requests.isEmpty
                    ? const Center(child: Text('No requests'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        itemCount: _requests.length,
                        itemBuilder: (context, i) => _tile(_requests[i]),
                      ),
              ),
      );

  Widget _tile(PartsRequest r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.inventoryItem?.name ?? r.inventoryItemId,
                      style: AppTheme.heading2
                          .copyWith(color: AppTheme.darkTextColor),
                    ),
                  ),
                  _statusChip(r.status),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                  'WO: ${r.workOrder?.ticketNumber ?? r.workOrderId} â€¢ Qty: ${r.quantity}',),
              if (r.reason.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text('Reason: ${r.reason}'),
              ],
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  if (r.status == PartsRequestStatus.pending) ...[
                    ElevatedButton(
                      onPressed: () => _approve(r),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    OutlinedButton(
                      onPressed: () => _reject(r),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentRed,
                        side: const BorderSide(color: AppTheme.accentRed),
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );

  Widget _statusChip(PartsRequestStatus s) {
    Color c;
    String t;
    switch (s) {
      case PartsRequestStatus.pending:
        c = AppTheme.accentOrange;
        t = 'Pending';
        break;
      case PartsRequestStatus.approved:
        c = AppTheme.accentGreen;
        t = 'Approved';
        break;
      case PartsRequestStatus.rejected:
        c = AppTheme.accentRed;
        t = 'Rejected';
        break;
      case PartsRequestStatus.fulfilled:
        c = AppTheme.accentBlue;
        t = 'Fulfilled';
        break;
      case PartsRequestStatus.cancelled:
        c = AppTheme.secondaryTextColor;
        t = 'Cancelled';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12),),
      child: Text(t,
          style: AppTheme.smallText
              .copyWith(color: c, fontWeight: FontWeight.bold),),
    );
  }
}
