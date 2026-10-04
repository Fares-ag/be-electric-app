// PM Task Completion Report Service
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

import '../models/pm_task.dart';
import '../utils/work_order_duration.dart';

class PMTaskCompletionReportService {
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

  /// Build PDF content for a specific completion cycle
  static Future<void> _buildPdfContentForCycle(
    pw.Document pdf,
    PMTask pmTask,
    Map<String, dynamic> completion,
    int cycleNumber,
  ) async {
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
          _buildHeader(pmTask, cycleNumber),
          
          pw.SizedBox(height: 24),

          // Summary Cards Row
          _buildSummaryCards(pmTask, completion, cycleNumber),

          pw.SizedBox(height: 24),

          // PM Task Details Section
          _buildSection(
            'PM Task Information',
            [
              _buildInfoRow('Task Name', pmTask.taskName),
              _buildInfoRow('Status', 'COMPLETED'), // This is a completion report, so status is always completed
              if (pmTask.asset != null || pmTask.assetName != null) ...[
                _buildInfoRow('Asset', pmTask.asset?.name ?? pmTask.assetName ?? 'N/A'),
                if (pmTask.asset != null) ...[
                  _buildInfoRow('Asset ID', pmTask.assetId.isNotEmpty ? pmTask.assetId : 'N/A'),
                  _buildInfoRow('Asset Location', pmTask.asset?.location ?? pmTask.assetLocation ?? 'N/A'),
                  _buildInfoRow('Asset Category', pmTask.asset?.category ?? 'N/A'),
                  _buildInfoRow('Asset Status', pmTask.asset?.status ?? 'N/A'),
                ] else if (pmTask.assetLocation != null)
                  _buildInfoRow('Location', pmTask.assetLocation!),
              ] else
                _buildInfoRow('Asset', 'General Maintenance (No Asset)'),
              _buildInfoRow('Description', pmTask.description),
              _buildInfoRow('Frequency', _formatFrequency(pmTask.frequency)),
              _buildInfoRow('Interval', '${pmTask.intervalDays} days'),
              if (pmTask.createdBy != null)
                _buildInfoRow('Created By', pmTask.createdBy!.name),
            ],
          ),

          pw.SizedBox(height: 20),

          // People Section
          _buildSection(
            'People Involved',
            [
              if (pmTask.assignedTechnicians != null && pmTask.assignedTechnicians!.isNotEmpty) ...[
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
                      ...pmTask.assignedTechnicians!.map((tech) {
                        final effort = pmTask.technicianEffortMinutes?[tech.id];
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
              ] else if (pmTask.assignedTechnician != null)
                _buildInfoRow('Technician', pmTask.assignedTechnician!.name),
            ],
          ),

          pw.SizedBox(height: 20),

          // Completion Cycle Details Section
          _buildSection(
            'Completion #$cycleNumber Details',
            () {
              final widgets = <pw.Widget>[];
              
              final completedAt = _parseDateTimeFromCompletion(completion['completedAt']);
              final startedAt = _parseDateTimeFromCompletion(completion['startedAt']);
              final durationSeconds = completion['durationSeconds'] as int?;
              final completedBy = completion['completedByName'] as String? ?? completion['completedBy'] as String? ?? 'Unknown';
              
              // Timeline Section
              if (startedAt != null || completedAt != null) {
                widgets.add(
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Timeline',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        if (startedAt != null)
                          _buildTimelineItem('Started', _formatDate(startedAt), PdfColors.green700),
                        if (completedAt != null)
                          _buildTimelineItem('Completed', _formatDate(completedAt), PdfColors.blue700),
                        if (durationSeconds != null && durationSeconds > 0)
                          _buildTimelineItem('Duration', formatWorkDurationSeconds(durationSeconds), PdfColors.orange700)
                        else if (startedAt != null && completedAt != null) ...[
                          () {
                            final calculatedSeconds = calculateActiveDurationSeconds(
                              start: startedAt,
                              end: completedAt,
                            );
                            if (calculatedSeconds > 0) {
                              return _buildTimelineItem(
                                'Duration',
                                formatWorkDurationSeconds(calculatedSeconds),
                                PdfColors.orange700,
                              );
                            }
                            return pw.SizedBox.shrink();
                          }(),
                        ],
                      ],
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 12));
              }
              
              widgets.add(_buildInfoRow('Completed By', completedBy));
              
              // Cost Breakdown
              if (completion['laborCost'] != null || 
                  completion['partsCost'] != null || 
                  completion['totalCost'] != null) {
                widgets.add(pw.Divider(color: PdfColors.grey300, height: 20));
                widgets.add(
                  pw.Text(
                    'Cost Breakdown',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 8));
                if (completion['laborCost'] != null) {
                  widgets.add(_buildInfoRow('Labor Cost', 'QAR ${(completion['laborCost'] as num).toStringAsFixed(2)}'));
                }
                if (completion['partsCost'] != null) {
                  widgets.add(_buildInfoRow('Parts Cost', 'QAR ${(completion['partsCost'] as num).toStringAsFixed(2)}'));
                }
                if (completion['totalCost'] != null) {
                  widgets.add(
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 8),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.green300, width: 2),
                      ),
                      child: _buildInfoRow('Total Cost', 'QAR ${(completion['totalCost'] as num).toStringAsFixed(2)}', isBold: true),
                    ),
                  );
                }
              }
              
              return widgets;
            }(),
          ),

          pw.SizedBox(height: 20),

          // Checklist Section (from this completion)
          if (completion['checklist'] != null) ...[
            _buildSection(
              'Checklist Items',
              () {
                final checklistItems = _parseChecklistFromCompletionData(completion['checklist']);
                final checkedCount = checklistItems.where((item) => item['checked'] == true).length;
                final totalCount = checklistItems.length;
                
                return [
                  // Checklist Summary
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: checkedCount == totalCount ? PdfColors.green50 : PdfColors.orange50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                        color: checkedCount == totalCount ? PdfColors.green300 : PdfColors.orange300,
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: checkedCount == totalCount ? PdfColors.green700 : PdfColors.orange700,
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          child: pw.Text(
                            checkedCount == totalCount ? '[OK]' : '[!]',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          '$checkedCount of $totalCount items completed',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: checkedCount == totalCount ? PdfColors.green700 : PdfColors.orange700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  // Checklist Items
                  ...checklistItems.map((item) {
                    final isChecked = item['checked'] == true;
                    final text = item['text'] as String? ?? '';
                    final isRequired = item['required'] == true;
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: isChecked ? PdfColors.green50 : PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                          color: isChecked ? PdfColors.green300 : PdfColors.grey300,
                          width: isChecked ? 2 : 1,
                        ),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 20,
                            height: 20,
                            decoration: pw.BoxDecoration(
                              color: isChecked ? PdfColors.green700 : PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(
                                color: isChecked ? PdfColors.green700 : PdfColors.grey400,
                                width: 2,
                              ),
                            ),
                            child: isChecked
                                ? pw.Center(
                                    child: pw.Text(
                                      '[X]',
                                      style: pw.TextStyle(
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.white,
                                      ),
                                    ),
                                  )
                                : pw.Center(
                                    child: pw.Text(
                                      '[ ]',
                                      style: pw.TextStyle(
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.grey400,
                                      ),
                                    ),
                                  ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  text,
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.normal,
                                    color: isChecked ? PdfColors.grey600 : PdfColors.black,
                                    decoration: isChecked ? pw.TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (isRequired)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(top: 4),
                                    child: pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.red100,
                                        borderRadius: pw.BorderRadius.circular(10),
                                      ),
                                      child: pw.Text(
                                        'Required',
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.red700,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ];
              }(),
            ),
            pw.SizedBox(height: 20),
          ],

          // Completion Notes Section
          if (completion['completionNotes'] != null && (completion['completionNotes'] as String).isNotEmpty) ...[
            _buildSection(
              'Completion Notes',
              [
                pw.Text(
                  completion['completionNotes'] as String,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Signature Section
          if (completion['technicianSignature'] != null && (completion['technicianSignature'] as String).isNotEmpty) ...[
            () {
              final completedAtForSignature = _parseDateTimeFromCompletion(completion['completedAt']);
              final completedByNameForSignature = completion['completedByName'] as String? ?? completion['completedBy'] as String? ?? 'Unknown';
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          height: 80,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(),
                          ),
                          child: () {
                            try {
                              final signatureData = completion['technicianSignature'] as String?;
                              if (signatureData != null && signatureData.isNotEmpty) {
                                // Try to decode base64 signature
                                Uint8List? imageBytes;
                                
                                // Check if it's a data URL
                                if (signatureData.startsWith('data:image')) {
                                  final base64String = signatureData.split(',').last;
                                  imageBytes = base64Decode(base64String);
                                } else {
                                  // Try direct base64 decode
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
                            
                            // Fallback to placeholder text
                            return pw.Center(
                              child: pw.Text(
                                'Technician Signature',
                                style: const pw.TextStyle(color: PdfColors.grey),
                              ),
                            );
                          }(),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Technician: $completedByNameForSignature',
                        ),
                        if (completedAtForSignature != null)
                          pw.Text(
                            'Date: ${_formatDate(completedAtForSignature)}',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }(),
            pw.SizedBox(height: 20),
          ],

          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey)),
            ),
            child: pw.Text(
              'Generated on ${_formatDate(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// Build PDF content
  static Future<void> _buildPdfContent(pw.Document pdf, PMTask pmTask) async {
    await _ensureFontsLoaded();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: _suisseRegular!,
          bold: _suisseBold!,
        ),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PM TASK COMPLETION REPORT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Task ID: ${pmTask.id}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // PM Task Details Section
          _buildSection(
            'PM Task Information',
            [
              _buildInfoRow('Task Name', pmTask.taskName),
              _buildInfoRow('Status', 'COMPLETED'), // This is a completion report, so status is always completed
              if (pmTask.asset != null || pmTask.assetName != null) ...[
                _buildInfoRow('Asset', pmTask.asset?.name ?? pmTask.assetName ?? 'N/A'),
                if (pmTask.asset != null) ...[
                  _buildInfoRow('Asset ID', pmTask.assetId.isNotEmpty ? pmTask.assetId : 'N/A'),
                  _buildInfoRow('Asset Location', pmTask.asset?.location ?? pmTask.assetLocation ?? 'N/A'),
                  _buildInfoRow('Asset Category', pmTask.asset?.category ?? 'N/A'),
                  _buildInfoRow('Asset Status', pmTask.asset?.status ?? 'N/A'),
                ] else if (pmTask.assetLocation != null)
                  _buildInfoRow('Location', pmTask.assetLocation!),
              ] else
                _buildInfoRow('Asset', 'General Maintenance (No Asset)'),
              _buildInfoRow('Description', pmTask.description),
              _buildInfoRow('Frequency', _formatFrequency(pmTask.frequency)),
              _buildInfoRow('Interval', '${pmTask.intervalDays} days'),
              if (pmTask.createdBy != null)
                _buildInfoRow('Created By', pmTask.createdBy!.name),
            ],
          ),

          pw.SizedBox(height: 20),

          // People Section
          _buildSection(
            'People Involved',
            [
              if (pmTask.assignedTechnicians != null && pmTask.assignedTechnicians!.isNotEmpty) ...[
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
                      ...pmTask.assignedTechnicians!.map((tech) {
                        final effort = pmTask.technicianEffortMinutes?[tech.id];
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
              ] else if (pmTask.assignedTechnician != null)
                _buildInfoRow('Technician', pmTask.assignedTechnician!.name),
            ],
          ),

          pw.SizedBox(height: 20),

          // Timeline Section
          _buildSection(
            'Timeline',
            [
              _buildInfoRow('Created', _formatDate(pmTask.createdAt)),
              if (pmTask.startedAt != null)
                _buildInfoRow('Started', _formatDate(pmTask.startedAt!)),
              if (pmTask.completedAt != null)
                _buildInfoRow('Last Completed', _formatDate(pmTask.completedAt!)),
              if (pmTask.lastCompletedAt != null)
                _buildInfoRow('Previous Completion', _formatDate(pmTask.lastCompletedAt!)),
              if (pmTask.nextDueDate != null)
                _buildInfoRow('Next Due Date', _formatDate(pmTask.nextDueDate!)),
            ],
          ),

          pw.SizedBox(height: 20),

          // Duration Section
          if (pmTask.startedAt != null || pmTask.completedAt != null) ...[
            _buildSection(
              'Duration',
              () {
                final durationWidgets = <pw.Widget>[];
                
                if (pmTask.startedAt != null && pmTask.completedAt != null) {
                  final totalElapsedSeconds = elapsedSecondsBetween(
                    pmTask.startedAt!,
                    pmTask.completedAt!,
                  );
                  final actualWorkSeconds =
                      calculatePmTaskDurationSeconds(pmTask) ?? 0;
                  final totalPausedSeconds =
                      totalElapsedSeconds - actualWorkSeconds;

                  durationWidgets.add(
                    _buildInfoRow(
                      'Total Duration',
                      formatWorkDurationSeconds(totalElapsedSeconds),
                    ),
                  );
                  durationWidgets.add(
                    _buildInfoRow(
                      'Actual Work Duration',
                      formatWorkDurationSeconds(actualWorkSeconds),
                    ),
                  );
                  if (totalPausedSeconds > 0) {
                    durationWidgets.add(
                      _buildInfoRow(
                        'Total Paused Time',
                        formatWorkDurationSeconds(totalPausedSeconds),
                      ),
                    );
                  }
                }

                if (pmTask.startedAt != null) {
                  durationWidgets.add(
                    _buildInfoRow(
                      'Time to Start',
                      formatWorkDurationSeconds(
                        elapsedSecondsBetween(
                          pmTask.createdAt,
                          pmTask.startedAt!,
                        ),
                      ),
                    ),
                  );
                }
                
                return durationWidgets;
              }(),
            ),
            pw.SizedBox(height: 20),
          ],

          // Checklist Section
          if (pmTask.checklist != null && pmTask.checklist!.isNotEmpty) ...[
            _buildSection(
              'Checklist',
              [
                ..._parseChecklist(pmTask.checklist!).map((item) {
                  final isChecked = item['checked'] == true;
                  final text = item['text'] as String? ?? '';
                  final isRequired = item['required'] == true;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isChecked ? '[X]' : '[ ]',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: isChecked ? PdfColors.green : PdfColors.grey,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(
                            text,
                            style: pw.TextStyle(
                              fontSize: 11,
                              decoration: isChecked ? pw.TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (isRequired)
                          pw.Text(
                            '(Required)',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.red,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Completion History Section
          if (pmTask.completionHistory != null && pmTask.completionHistory!.isNotEmpty) ...[
            _buildSection(
              'Completion History',
              [
                ...pmTask.completionHistory!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final completion = entry.value;
                  final completionCycle = index + 1;
                  
                  final completedAt = _parseDateTimeFromCompletion(completion['completedAt']);
                  final startedAt = _parseDateTimeFromCompletion(completion['startedAt']);
                  final durationSeconds = completion['durationSeconds'] as int?;
                  
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Completion #$completionCycle',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          if (completedAt != null)
                            _buildInfoRow('Completed At', _formatDate(completedAt)),
                          if (startedAt != null)
                            _buildInfoRow('Started At', _formatDate(startedAt)),
                          if (durationSeconds != null)
                            _buildInfoRow('Duration', formatWorkDurationSeconds(durationSeconds)),
                          if (completion['laborCost'] != null)
                            _buildInfoRow('Labor Cost', 'QAR ${(completion['laborCost'] as num).toStringAsFixed(2)}'),
                          if (completion['partsCost'] != null)
                            _buildInfoRow('Parts Cost', 'QAR ${(completion['partsCost'] as num).toStringAsFixed(2)}'),
                          if (completion['totalCost'] != null)
                            _buildInfoRow('Total Cost', 'QAR ${(completion['totalCost'] as num).toStringAsFixed(2)}'),
                          if (completion['completionNotes'] != null && (completion['completionNotes'] as String).isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 8),
                              child: pw.Text(
                                'Notes: ${completion['completionNotes']}',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Cost Section
          if (pmTask.laborCost != null || pmTask.partsCost != null || pmTask.totalCost != null) ...[
            _buildSection(
              'Cost Breakdown',
              [
                if (pmTask.laborCost != null)
                  _buildInfoRow(
                    'Labor Cost',
                    'QAR ${pmTask.laborCost!.toStringAsFixed(2)}',
                  ),
                if (pmTask.partsCost != null)
                  _buildInfoRow(
                    'Parts Cost',
                    'QAR ${pmTask.partsCost!.toStringAsFixed(2)}',
                  ),
                if (pmTask.totalCost != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.only(top: 8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(width: 2)),
                    ),
                    child: _buildInfoRow(
                      'Total Cost',
                      'QAR ${pmTask.totalCost!.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Completion Notes Section
          if (pmTask.completionNotes != null && pmTask.completionNotes!.isNotEmpty) ...[
            _buildSection(
              'Completion Notes',
              [
                pw.Text(
                  pmTask.completionNotes!,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Pause History Section
          if (pmTask.pauseHistory != null && pmTask.pauseHistory!.isNotEmpty) ...[
            _buildSection(
              'Work Pause History',
              [
                ...pmTask.pauseHistory!.map((pause) {
                  final pausedAt = _parseDateTimeFromPauseHistory(pause['pausedAt']);
                  final resumedAt = _parseDateTimeFromPauseHistory(pause['resumedAt']);
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
                          'Pause ${pmTask.pauseHistory!.indexOf(pause) + 1}',
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
            pw.SizedBox(height: 20),
          ],

          // Signature Section
          if (pmTask.technicianSignature != null && pmTask.technicianSignature!.isNotEmpty) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        height: 80,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'Technician Signature',
                            style: const pw.TextStyle(color: PdfColors.grey),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Technician: ${pmTask.assignedTechnician?.name ?? "N/A"}',
                      ),
                      if (pmTask.completedAt != null)
                        pw.Text(
                          'Date: ${_formatDate(pmTask.completedAt!)}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey)),
            ),
            child: pw.Text(
              'Generated on ${_formatDate(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate completion report PDF bytes for a specific cycle (for web or custom handling)
  static Future<Uint8List> generateCompletionReportBytesForCycle(
    PMTask pmTask,
    int cycleIndex,
  ) async {
    try {
      print('📄 PMTaskCompletionReportService: Generating report bytes for ${pmTask.id} - Cycle #$cycleIndex');
      
      if (pmTask.completionHistory == null || pmTask.completionHistory!.isEmpty) {
        throw Exception('PM task has no completion history');
      }
      
      if (cycleIndex < 0 || cycleIndex >= pmTask.completionHistory!.length) {
        throw Exception('Invalid cycle index: $cycleIndex');
      }
      
      final completion = pmTask.completionHistory![cycleIndex];
      final cycleNumber = cycleIndex + 1;
      
      final pdf = pw.Document();
      _buildPdfContentForCycle(pdf, pmTask, completion, cycleNumber);
      
      final bytes = await pdf.save();
      print('✅ PMTaskCompletionReportService: PDF generated (${bytes.length} bytes)');
      return bytes;
    } catch (e, stackTrace) {
      print('❌ PMTaskCompletionReportService: Error generating report: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate completion report PDF for a specific cycle and save to file
  static Future<String> generateCompletionReportForCycle(
    PMTask pmTask,
    int cycleIndex,
  ) async {
    try {
      print('📄 PMTaskCompletionReportService: Generating report for ${pmTask.id} - Cycle #$cycleIndex');
      
      if (pmTask.completionHistory == null || pmTask.completionHistory!.isEmpty) {
        throw Exception('PM task has no completion history');
      }
      
      if (cycleIndex < 0 || cycleIndex >= pmTask.completionHistory!.length) {
        throw Exception('Invalid cycle index: $cycleIndex');
      }
      
      final completion = pmTask.completionHistory![cycleIndex];
      final cycleNumber = cycleIndex + 1;
      
      final pdf = pw.Document();
      _buildPdfContentForCycle(pdf, pmTask, completion, cycleNumber);

      // Save PDF to file
      if (kIsWeb) {
        // For web, trigger browser download
        final bytes = await pdf.save();
        print('✅ PMTaskCompletionReportService: PDF generated for web (${bytes.length} bytes)');
        
        // Create a blob and trigger download
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = 'PMTask_${pmTask.id}_Cycle${cycleNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        // ignore: unused_local_variable
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        
        // Clean up the object URL after a short delay to ensure download starts
        Future.delayed(const Duration(milliseconds: 100), () {
          html.Url.revokeObjectUrl(url);
        });
        
        // Return a placeholder path for consistency
        return fileName;
      } else {
        // For mobile/desktop platforms
        try {
          final directory = await getApplicationDocumentsDirectory();
          final filePath =
              '${directory.path}/PMTask_${pmTask.id}_Cycle${cycleNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File(filePath);
          final bytes = await pdf.save();
          await file.writeAsBytes(bytes);

          print('✅ PMTaskCompletionReportService: Report saved to $filePath');
          return filePath;
        } catch (e, st) {
          // If getApplicationDocumentsDirectory fails, try using bytes method
          print('⚠️ PMTaskCompletionReportService: Failed to get directory, error: $e');
          print('   This might be a platform-specific issue. Please ensure path_provider is properly configured.');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      print('❌ PMTaskCompletionReportService: Error generating report: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate completion report PDF bytes (for web or custom handling)
  static Future<Uint8List> generateCompletionReportBytes(PMTask pmTask) async {
    try {
      print('📄 PMTaskCompletionReportService: Generating report bytes for ${pmTask.id}');
      
      final pdf = pw.Document();
      await _buildPdfContent(pdf, pmTask);
      
      final bytes = await pdf.save();
      print('✅ PMTaskCompletionReportService: PDF generated (${bytes.length} bytes)');
      return bytes;
    } catch (e, stackTrace) {
      print('❌ PMTaskCompletionReportService: Error generating report: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate completion report PDF and save to file
  static Future<String> generateCompletionReport(PMTask pmTask) async {
    try {
      print('📄 PMTaskCompletionReportService: Generating report for ${pmTask.id}');
      
      final pdf = pw.Document();
      await _buildPdfContent(pdf, pmTask);

      // Save PDF to file
      if (kIsWeb) {
        // For web, trigger browser download
        final bytes = await pdf.save();
        print('✅ PMTaskCompletionReportService: PDF generated for web (${bytes.length} bytes)');
        
        // Create a blob and trigger download
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = 'PMTask_${pmTask.id}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
        // ignore: unused_local_variable
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        
        // Clean up the object URL after a short delay to ensure download starts
        Future.delayed(const Duration(milliseconds: 100), () {
          html.Url.revokeObjectUrl(url);
        });
        
        // Return a placeholder path for consistency
        return fileName;
      } else {
        // For mobile/desktop platforms
        try {
          final directory = await getApplicationDocumentsDirectory();
          final filePath =
              '${directory.path}/PMTask_${pmTask.id}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File(filePath);
          final bytes = await pdf.save();
          await file.writeAsBytes(bytes);

          print('✅ PMTaskCompletionReportService: Report saved to $filePath');
          return filePath;
        } catch (e, st) {
          // If getApplicationDocumentsDirectory fails, try using bytes method
          print('⚠️ PMTaskCompletionReportService: Failed to get directory, error: $e');
          print('   This might be a platform-specific issue. Please ensure path_provider is properly configured.');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      print('❌ PMTaskCompletionReportService: Error generating report: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Build beautiful header with gradient background
  static pw.Widget _buildHeader(PMTask pmTask, int cycleNumber) {
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
                      'PREVENTIVE MAINTENANCE',
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
                  'CYCLE #$cycleNumber',
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
                  '[TASK]',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    'Task ID: ${pmTask.id}',
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
  static pw.Widget _buildSummaryCards(
    PMTask pmTask,
    Map<String, dynamic> completion,
    int cycleNumber,
  ) {
    final completedAt = _parseDateTimeFromCompletion(completion['completedAt']);
    final startedAt = _parseDateTimeFromCompletion(completion['startedAt']);
    final durationSeconds = completion['durationSeconds'] as int?;
    final totalCost = completion['totalCost'] as num?;
    
    return pw.Row(
      children: [
        // Status Card
        pw.Expanded(
          child: _buildSummaryCard(
            'Status',
            'COMPLETED',
            PdfColors.green700,
            0xe86c, // check_circle icon code point
          ),
        ),
        pw.SizedBox(width: 12),
        // Duration Card
        pw.Expanded(
          child: _buildSummaryCard(
            'Duration',
            durationSeconds != null && durationSeconds > 0
                ? formatWorkDurationSeconds(durationSeconds)
                : (startedAt != null && completedAt != null
                    ? formatWorkDurationSeconds(
                        calculateActiveDurationSeconds(
                          start: startedAt,
                          end: completedAt,
                          storedDurationSeconds: durationSeconds,
                        ),
                      )
                    : 'N/A'),
            PdfColors.blue700,
            0xe425, // timer icon code point
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
            0xe227, // attach_money icon code point
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
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 150,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isBold ? 14 : 12,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: isBold ? 14 : 12,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static String _formatFrequency(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return 'Daily';
      case PMTaskFrequency.weekly:
        return 'Weekly';
      case PMTaskFrequency.monthly:
        return 'Monthly';
      case PMTaskFrequency.quarterly:
        return 'Quarterly';
      case PMTaskFrequency.semiAnnually:
        return 'Semi-Annually';
      case PMTaskFrequency.annually:
        return 'Annually';
      case PMTaskFrequency.asNeeded:
        return 'As Needed';
    }
  }

  static String _getIconLabel(int iconCodePoint) {
    // Map icon code points to text labels
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

  static pw.Widget _buildTimelineItem(String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _parseDateTimeFromPauseHistory(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value.containsKey('_seconds')) {
      final seconds = value['_seconds'] as int;
      final nanoseconds = value['_nanoseconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanoseconds ~/ 1000000),
      );
    }
    return null;
  }

  static DateTime? _parseDateTimeFromCompletion(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value.containsKey('_seconds')) {
      final seconds = value['_seconds'] as int;
      final nanoseconds = value['_nanoseconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanoseconds ~/ 1000000),
      );
    }
    return null;
  }

  static List<Map<String, dynamic>> _parseChecklist(String checklistJson) {
    try {
      final decoded = jsonDecode(checklistJson) as List;
      return decoded.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return {'text': item.toString(), 'checked': false, 'required': false};
      }).toList();
    } catch (e, st) {
      print('⚠️ Error parsing checklist: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _parseChecklistFromCompletionData(dynamic checklistData) {
    try {
      if (checklistData == null) return [];
      
      if (checklistData is String) {
        return _parseChecklist(checklistData);
      }
      
      if (checklistData is List) {
        return checklistData.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return {'text': item.toString(), 'checked': false, 'required': false};
        }).toList();
      }
      
      return [];
    } catch (e, st) {
      print('⚠️ Error parsing checklist from completion: $e');
      return [];
    }
  }
}

