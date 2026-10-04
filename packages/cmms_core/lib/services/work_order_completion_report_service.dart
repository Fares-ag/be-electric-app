// Work Order Completion Report Service
// Generates PDF completion reports with images and signatures

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:universal_html/html.dart' as html;
import '../models/work_order.dart';
import '../utils/work_order_duration.dart';

class WorkOrderCompletionReportService {
  static pw.Font? _suisseRegular;
  static pw.Font? _suisseBold;

  static Future<void> _ensureFontsLoaded() async {
    if (_suisseRegular != null && _suisseBold != null) return;
    const regularPaths = [
      'packages/cmms_core/assets/fonts/SuisseIntl-Regular.ttf',
      'assets/fonts/SuisseIntl-Regular.ttf',
      'packages/cmms_core/assets/fonts/SuisseIntl-Regular.otf',
      'assets/fonts/SuisseIntl-Regular.otf',
    ];
    const boldPaths = [
      'packages/cmms_core/assets/fonts/SuisseIntl-Bold.ttf',
      'assets/fonts/SuisseIntl-Bold.ttf',
      'packages/cmms_core/assets/fonts/SuisseIntl-Bold.otf',
      'assets/fonts/SuisseIntl-Bold.otf',
    ];
    try {
      final regularData = await _loadFirstAsset(regularPaths);
      final boldData = await _loadFirstAsset(boldPaths);
      _suisseRegular = pw.Font.ttf(regularData);
      _suisseBold = pw.Font.ttf(boldData);
    } catch (_) {
      _suisseRegular = pw.Font.helvetica();
      _suisseBold = pw.Font.helveticaBold();
    }
  }

  static Future<ByteData> _loadFirstAsset(List<String> paths) async {
    Object? lastError;
    for (final path in paths) {
      try {
        return await rootBundle.load(path);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Font asset not found');
  }
  /// Build PDF content
  static Future<void> _buildPdfContent(pw.Document pdf, WorkOrder workOrder) async {
    await _ensureFontsLoaded();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: _suisseRegular!,
          bold: _suisseBold!,
        ),
        build: (context) => [
          // Beautiful Header with colored background
          _buildHeader(workOrder),
          
          pw.SizedBox(height: 24),

          // Summary Cards Row
          _buildSummaryCards(workOrder),

          pw.SizedBox(height: 24),

          // Work Order Details Section
          _buildSection(
            'Work Order Information',
            [
              _buildInfoRow('Ticket Number', workOrder.ticketNumber, isHighlight: true),
              _buildInfoRow('Status', workOrder.status.name.toUpperCase(), isBold: true, isHighlight: true),
              pw.Divider(color: PdfColors.grey300, height: 20),
              _buildInfoRow('Asset', workOrder.assetName ?? (workOrder.location ?? 'N/A')),
              if (workOrder.asset != null) ...[
                _buildInfoRow('Asset ID', workOrder.assetId ?? 'N/A'),
                _buildInfoRow('Asset Location', workOrder.assetLocation ?? 'N/A'),
                _buildInfoRow('Asset Category', workOrder.asset?.category ?? 'N/A'),
                _buildInfoRow('Asset Status', workOrder.asset?.status ?? 'N/A'),
              ] else if (workOrder.location != null)
                _buildInfoRow('Location', workOrder.location!),
              _buildInfoRow(
                'Problem Description',
                workOrder.problemDescription,
              ),
              _buildInfoRow('Category', workOrder.categoryDisplayName),
              if (workOrder.workCategory != null)
                _buildInfoRow('Work Category', workOrder.workCategory!),
              _buildInfoRow('Priority', workOrder.priority.name.toUpperCase()),
              if (workOrder.severityLevel != null)
                _buildInfoRow('Severity Level', workOrder.severityLevel.toString()),
              if (workOrder.isRepeatFailure == true)
                _buildInfoRow('Repeat Failure', 'Yes'),
            ],
          ),

          pw.SizedBox(height: 20),

          // People Section
          _buildSection(
            'People Involved',
            [
              _buildInfoRow(
                'Requestor',
                workOrder.requestorName != null &&
                        workOrder.requestorName!.isNotEmpty
                    ? workOrder.requestorName!
                    : (workOrder.requestor?.name ?? 'N/A'),
                isHighlight: true,
              ),
              if (workOrder.requestor?.email != null && workOrder.requestor!.email.isNotEmpty)
                _buildInfoRow('Requestor Email', workOrder.requestor!.email),
              if (workOrder.requestor?.workEmail != null && workOrder.requestor!.workEmail!.isNotEmpty)
                _buildInfoRow('Requestor Work Email', workOrder.requestor!.workEmail!),
              if (workOrder.assignedTechnicians != null && workOrder.assignedTechnicians!.isNotEmpty) ...[
                pw.Divider(color: PdfColors.grey300, height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Assigned Technicians:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      ...workOrder.assignedTechnicians!.map((tech) {
                        final effort = workOrder.technicianEffortMinutes?[tech.id];
                        final effortText = effort != null && effort > 0
                            ? ' - ${formatWorkDurationSeconds(effort * 60)}'
                            : '';
                        return pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 6),
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey50,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.grey300, width: 1),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Container(
                                width: 6,
                                height: 6,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.blue700,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.SizedBox(width: 10),
                              pw.Expanded(
                                child: pw.Text(
                                  '${tech.name}$effortText',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.normal,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ] else if (workOrder.assignedTechnician != null)
                _buildInfoRow('Technician', workOrder.assignedTechnician!.name),
            ],
          ),

          pw.SizedBox(height: 20),

          // Timeline Section
          _buildSection(
            'Timeline',
            [
              _buildInfoRow('Created', _formatDate(workOrder.createdAt)),
              if (workOrder.assignedAt != null)
                _buildInfoRow('Assigned', _formatDate(workOrder.assignedAt!)),
              if (workOrder.startedAt != null)
                _buildInfoRow('Started', _formatDate(workOrder.startedAt!)),
              if (workOrder.completedAt != null)
                _buildInfoRow('Completed', _formatDate(workOrder.completedAt!)),
              if (workOrder.closedAt != null)
                _buildInfoRow('Closed', _formatDate(workOrder.closedAt!)),
              if (workOrder.firstResponseTime != null)
                _buildInfoRow('First Response', _formatDate(workOrder.firstResponseTime!)),
              if (workOrder.actualStartTime != null)
                _buildInfoRow('Actual Start', _formatDate(workOrder.actualStartTime!)),
              if (workOrder.actualEndTime != null)
                _buildInfoRow('Actual End', _formatDate(workOrder.actualEndTime!)),
            ],
          ),

          pw.SizedBox(height: 20),

          // Duration Section
          if (workOrder.startedAt != null || workOrder.completedAt != null) ...[
            _buildSection(
              'Duration',
              [
                if (workOrder.startedAt != null && workOrder.completedAt != null) ...[
                  _buildInfoRow(
                    'Total Duration',
                    formatWorkDurationSeconds(
                      calculateWorkDurationSeconds(workOrder) ?? 0,
                    ),
                  ),
                ],
                if (workOrder.startedAt != null) ...[
                  _buildInfoRow(
                    'Time to Start',
                    formatWorkDurationSeconds(
                      elapsedSecondsBetween(
                        workOrder.createdAt,
                        workOrder.startedAt!,
                      ),
                    ),
                  ),
                ],
                if (workOrder.completedAt != null) ...[
                  _buildInfoRow(
                    'Total Time',
                    formatWorkDurationSeconds(
                      elapsedSecondsBetween(
                        workOrder.createdAt,
                        workOrder.completedAt!,
                      ),
                    ),
                  ),
                ],
                if (workOrder.estimatedDuration != null)
                  _buildInfoRow(
                    'Estimated Duration',
                    formatWorkDuration(workOrder.estimatedDuration!),
                  ),
                if (workOrder.actualDuration != null)
                  _buildInfoRow(
                    'Actual Duration',
                    formatWorkDuration(workOrder.actualDuration!),
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          pw.SizedBox(height: 20),

          // Root Cause & Failure Analysis Section
          if (workOrder.rootCause != null || workOrder.failureMode != null) ...[
            _buildSection(
              'Root Cause & Failure Analysis',
              [
                if (workOrder.rootCause != null && workOrder.rootCause!.isNotEmpty)
                  _buildInfoRow('Root Cause', workOrder.rootCause!),
                if (workOrder.failureMode != null && workOrder.failureMode!.isNotEmpty)
                  _buildInfoRow('Failure Mode', workOrder.failureMode!),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Completion Details Section
          if (workOrder.isCompleted) ...[
            _buildSection(
              'Completion Details',
              [
                if (workOrder.correctiveActions != null &&
                    workOrder.correctiveActions!.isNotEmpty)
                  _buildInfoRow(
                    'Corrective Actions',
                    workOrder.correctiveActions!,
                  ),
                if (workOrder.recommendations != null &&
                    workOrder.recommendations!.isNotEmpty)
                  _buildInfoRow('Recommendations', workOrder.recommendations!),
                if (workOrder.nextMaintenanceDate != null)
                  _buildInfoRow(
                    'Next Maintenance',
                    _formatDate(workOrder.nextMaintenanceDate!),
                  ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Cost Section
            if (workOrder.laborCost != null || workOrder.partsCost != null || workOrder.estimatedCost != null || workOrder.actualCost != null) ...[
              _buildSection(
                'Cost Breakdown',
                () {
                  final widgets = <pw.Widget>[];
                  
                  if (workOrder.estimatedCost != null) {
                    widgets.add(_buildInfoRow(
                      'Estimated Cost',
                      'QAR ${workOrder.estimatedCost!.toStringAsFixed(2)}',
                    ));
                  }
                  if (workOrder.laborCost != null) {
                    widgets.add(_buildInfoRow(
                      'Labor Cost',
                      'QAR ${workOrder.laborCost!.toStringAsFixed(2)}',
                    ));
                  }
                  if (workOrder.partsCost != null) {
                    widgets.add(_buildInfoRow(
                      'Parts Cost',
                      'QAR ${workOrder.partsCost!.toStringAsFixed(2)}',
                    ));
                  }
                  if (workOrder.actualCost != null) {
                    widgets.add(_buildInfoRow(
                      'Actual Cost',
                      'QAR ${workOrder.actualCost!.toStringAsFixed(2)}',
                    ));
                  }
                  if (workOrder.totalCost != null) {
                    widgets.add(pw.Divider(color: PdfColors.grey300, height: 20));
                    widgets.add(
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 8),
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.green300, width: 2),
                        ),
                        child: _buildInfoRow(
                          'Total Cost',
                          'QAR ${workOrder.totalCost!.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ),
                    );
                  }
                  
                  return widgets;
                }(),
              ),
            ],

            // Parts Used Section
            if (workOrder.partsUsed != null && workOrder.partsUsed!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildSection(
                'Parts Used',
                [
                  pw.Text(
                    workOrder.partsUsed!.join(', '),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],

            // Notes Section
            if (workOrder.notes != null && workOrder.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildSection(
                'Notes',
                [
                  pw.Text(
                    workOrder.notes!,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],

            // Pause History Section
            if (workOrder.pauseHistory != null && workOrder.pauseHistory!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildSection(
                'Work Pause History',
                [
                  ...workOrder.pauseHistory!.map((pause) {
                    final pausedAt = pause['pausedAt'] != null
                        ? DateTime.parse(pause['pausedAt'] as String)
                        : null;
                    final resumedAt = pause['resumedAt'] != null
                        ? DateTime.parse(pause['resumedAt'] as String)
                        : null;
                    final reason = pause['reason'] as String? ?? 'No reason provided';
                    final duration = pausedAt != null && resumedAt != null
                        ? formatWorkDurationSeconds(
                            elapsedSecondsBetween(pausedAt, resumedAt),
                          )
                        : 'Ongoing';
                    
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Pause ${workOrder.pauseHistory!.indexOf(pause) + 1}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          if (pausedAt != null)
                            pw.Text(
                              'Paused: ${_formatDate(pausedAt)}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          if (resumedAt != null)
                            pw.Text(
                              'Resumed: ${_formatDate(resumedAt)}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          pw.Text(
                            'Duration: $duration',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            'Reason: $reason',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ],

          pw.SizedBox(height: 30),

          // Signatures Section
          if (workOrder.requestorSignature != null ||
              workOrder.technicianSignature != null) ...[
            _buildSection(
              'Signatures',
              [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (workOrder.technicianSignature != null)
                      pw.Expanded(
                        child: _buildSignatureBox(
                          'Technician Signature',
                          workOrder.technicianSignature!,
                          workOrder.assignedTechnician?.name ?? 'Unknown',
                          workOrder.completedAt,
                        ),
                      ),
                    if (workOrder.requestorSignature != null && workOrder.technicianSignature != null)
                      pw.SizedBox(width: 20),
                    if (workOrder.requestorSignature != null)
                      pw.Expanded(
                        child: _buildSignatureBox(
                          'Requestor Signature',
                          workOrder.requestorSignature!,
                          workOrder.requestor?.name ?? 'Unknown',
                          workOrder.completedAt,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          pw.SizedBox(height: 30),

          // Footer
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Q-AUTO CMMS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated on ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'This is an automated report generated by the Q-AUTO CMMS system',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Generate completion report PDF bytes (for web or custom handling)
  static Future<Uint8List> generateCompletionReportBytes(WorkOrder workOrder) async {
    try {
      print('📄 WorkOrderCompletionReportService: Generating report bytes for ${workOrder.ticketNumber}');
      
      final pdf = pw.Document();
      await _buildPdfContent(pdf, workOrder);
      
      final bytes = await pdf.save();
      print('✅ WorkOrderCompletionReportService: PDF generated (${bytes.length} bytes)');
      return bytes;
    } catch (e, stackTrace) {
      print('❌ WorkOrderCompletionReportService: Error generating report: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate completion report PDF and save to file
  static Future<String> generateCompletionReport(WorkOrder workOrder) async {
    try {
      print('📄 WorkOrderCompletionReportService: Generating report for ${workOrder.ticketNumber}');
      print('   - Is completed: ${workOrder.isCompleted}');
      print('   - Has requestor: ${workOrder.requestor != null}');
      print('   - Has assigned technician: ${workOrder.assignedTechnician != null}');
      print('   - Has requestor signature: ${workOrder.requestorSignature != null}');
      print('   - Has technician signature: ${workOrder.technicianSignature != null}');
      
      final pdf = pw.Document();
      await _buildPdfContent(pdf, workOrder);

      // Save PDF to file
      if (kIsWeb) {
        // For web, trigger browser download
        final bytes = await pdf.save();
        print('✅ WorkOrderCompletionReportService: PDF generated for web (${bytes.length} bytes)');
        
        // Create a blob and trigger download
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = 'WorkOrder_${workOrder.ticketNumber}_Completion_${DateTime.now().millisecondsSinceEpoch}.pdf';
        // ignore: unused_local_variable
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        
        // Clean up the object URL after a short delay to ensure download starts
        Future.delayed(const Duration(milliseconds: 100), () {
          html.Url.revokeObjectUrl(url);
        });
        
        // Return a placeholder path for consistency
        return 'WorkOrder_${workOrder.ticketNumber}_Completion_${DateTime.now().millisecondsSinceEpoch}.pdf';
      } else {
        // For mobile/desktop platforms
        try {
          final directory = await getApplicationDocumentsDirectory();
          final filePath =
              '${directory.path}/WorkOrder_${workOrder.ticketNumber}_Completion_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File(filePath);
          final bytes = await pdf.save();
          await file.writeAsBytes(bytes);

          print('✅ WorkOrderCompletionReportService: Report saved to $filePath');
          return filePath;
        } catch (e, st) {
          // If getApplicationDocumentsDirectory fails, try using bytes method
          print('⚠️ WorkOrderCompletionReportService: Failed to get directory, error: $e');
          print('   This might be a platform-specific issue. Please ensure path_provider is properly configured.');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      print('❌ WorkOrderCompletionReportService: Error generating report: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Build beautiful header with gradient background
  static pw.Widget _buildHeader(WorkOrder workOrder) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'WORK ORDER',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'COMPLETION REPORT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  workOrder.status.name.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  '[TICKET]',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    'Ticket #${workOrder.ticketNumber}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ),
                pw.Text(
                  _formatDate(DateTime.now()),
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build summary cards with key metrics
  static pw.Widget _buildSummaryCards(WorkOrder workOrder) {
    final statusColor = workOrder.isCompleted ? PdfColors.green700 : PdfColors.orange700;
    final durationSeconds = workOrder.startedAt != null &&
            workOrder.completedAt != null
        ? calculateWorkDurationSeconds(workOrder)
        : null;
    final totalCost = workOrder.totalCost ?? workOrder.actualCost;
    
    return pw.Row(
      children: [
        // Status Card
        pw.Expanded(
          child: _buildSummaryCard(
            'Status',
            workOrder.status.name.toUpperCase(),
            statusColor,
            0xe86c, // check_circle
          ),
        ),
        pw.SizedBox(width: 12),
        // Duration Card
        pw.Expanded(
          child: _buildSummaryCard(
            'Duration',
            durationSeconds != null
                ? formatWorkDurationSeconds(durationSeconds)
                : (workOrder.startedAt != null ? 'In Progress' : 'Not Started'),
            PdfColors.blue700,
            0xe425, // timer
          ),
        ),
        pw.SizedBox(width: 12),
        // Cost Card
        pw.Expanded(
          child: _buildSummaryCard(
            'Total Cost',
            totalCost != null
                ? 'QAR ${totalCost.toStringAsFixed(2)}'
                : 'N/A',
            PdfColors.orange700,
            0xe227, // attach_money
          ),
        ),
      ],
    );
  }

  /// Build individual summary card
  static pw.Widget _buildSummaryCard(
    String label,
    String value,
    PdfColor color,
    int iconCodePoint,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: color, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  _getIconLabel(iconCodePoint),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build signature box
  static pw.Widget _buildSignatureBox(
    String label,
    String signatureData,
    String signerName,
    DateTime? date,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue300, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 100,
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: () {
              try {
                if (signatureData.isNotEmpty) {
                  Uint8List imageBytes;
                  
                  if (signatureData.startsWith('data:image')) {
                    final base64String = signatureData.split(',').last;
                    imageBytes = base64Decode(base64String);
                  } else {
                    imageBytes = base64Decode(signatureData);
                  }
                  
                  if (imageBytes.isNotEmpty) {
                    return pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(imageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    );
                  }
                }
              } catch (e, st) {
                print('⚠️ Error loading signature image: $e');
              }
              
              return pw.Center(
                child: pw.Text(
                  'Signature',
                  style: pw.TextStyle(
                    color: PdfColors.grey400,
                    fontSize: 12,
                  ),
                ),
              );
            }(),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$label:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    signerName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
              if (date != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _formatDate(date),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _getIconLabel(int iconCodePoint) {
    switch (iconCodePoint) {
      case 0xe86c: // check_circle
        return '[OK]';
      case 0xe425: // timer
        return '[TIME]';
      case 0xe227: // attach_money
        return '[COST]';
      default:
        return '[ICON]';
    }
  }

  static pw.Widget _buildSection(String title, List<pw.Widget> children) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 4,
                  height: 20,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
  }) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: isHighlight
            ? pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.blue200, width: 1),
              )
            : null,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 140,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isBold ? 13 : 11,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: isBold ? 13 : 11,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isHighlight ? PdfColors.blue900 : PdfColors.black,
                ),
              ),
            ),
          ],
        ),
      );

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
