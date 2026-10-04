// Security Utilities for Input Sanitization and Validation
//
// Provides comprehensive security functions to prevent common vulnerabilities:
// - XSS (Cross-Site Scripting)
// - SQL Injection
// - Path Traversal
// - Email validation
// - Password strength validation
// - Input sanitization
//
// Usage:
// ```dart
// // Sanitize user input
// final safe = SecurityUtils.sanitizeInput(userInput);
//
// // Validate email
// if (SecurityUtils.isValidEmail(email)) {
//   // Process email
// }
//
// // Check password strength
// final strength = SecurityUtils.getPasswordStrength(password);
// ```

import 'package:flutter/foundation.dart';

/// Password strength levels
enum PasswordStrength {
  weak,
  fair,
  good,
  strong,
  veryStrong,
}

/// Security utilities for input validation and sanitization
class SecurityUtils {
  SecurityUtils._();

  // ========================================
  // INPUT SANITIZATION
  // ========================================

  /// Sanitize text input by removing potentially dangerous characters
  ///
  /// Removes or escapes characters commonly used in attacks:
  /// - Script tags
  /// - HTML entities
  /// - SQL special characters
  ///
  /// Example:
  /// ```dart
  /// final userInput = '<script>alert("XSS")</script>';
  /// final safe = SecurityUtils.sanitizeInput(userInput);
  /// // Returns: 'scriptalert("XSS")/script'
  /// ```
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;

    var sanitized = input;

    // Remove script tags
    sanitized = sanitized.replaceAll(
      RegExp('<script[^>]*>.*?</script>', caseSensitive: false),
      '',
    );

    // Remove iframe tags
    sanitized = sanitized.replaceAll(
      RegExp('<iframe[^>]*>.*?</iframe>', caseSensitive: false),
      '',
    );

    // Remove on* event handlers (onclick, onerror, etc.)
    sanitized = sanitized.replaceAll(
      RegExp(r'''\s*on\w+\s*=\s*["'][^"']*["']''', caseSensitive: false),
      '',
    );

    // Escape HTML entities
    sanitized = sanitized
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');

    return sanitized;
  }

  /// Sanitize HTML by removing dangerous elements but preserving safe formatting
  ///
  /// Allows: <b>, <i>, <u>, <p>, <br>, <strong>, <em>
  /// Removes: <script>, <iframe>, event handlers, etc.
  static String sanitizeHTML(String html) {
    if (html.isEmpty) return html;

    var sanitized = html;

    // Remove dangerous tags
    final dangerousTags = [
      'script',
      'iframe',
      'object',
      'embed',
      'applet',
      'meta',
      'link',
      'style',
      'base',
    ];

    for (final tag in dangerousTags) {
      sanitized = sanitized.replaceAll(
        RegExp('<$tag[^>]*>.*?</$tag>', caseSensitive: false),
        '',
      );
      sanitized = sanitized.replaceAll(
        RegExp('<$tag[^>]*/?>', caseSensitive: false),
        '',
      );
    }

    // Remove event handlers
    sanitized = sanitized.replaceAll(
      RegExp(r'''\s*on\w+\s*=\s*["'][^"']*["']''', caseSensitive: false),
      '',
    );

    // Remove javascript: protocol
    sanitized = sanitized.replaceAll(
      RegExp('javascript:', caseSensitive: false),
      '',
    );

    return sanitized;
  }

  /// Sanitize SQL input to prevent SQL injection
  ///
  /// **Note:** This is a basic sanitizer. Always use parameterized queries!
  static String sanitizeSQL(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll("'", "''") // Escape single quotes
        .replaceAll(';', '') // Remove semicolons
        .replaceAll('--', '') // Remove SQL comments
        .replaceAll('/*', '')
        .replaceAll('*/', '');
  }

  /// Sanitize file path to prevent path traversal attacks
  ///
  /// Removes: ../, ..\, absolute paths
  static String sanitizeFilePath(String path) {
    if (path.isEmpty) return path;

    var sanitized = path;

    // Remove path traversal attempts
    sanitized = sanitized.replaceAll('../', '');
    sanitized = sanitized.replaceAll(r'..\', '');

    // Remove absolute paths (Unix and Windows)
    if (sanitized.startsWith('/') || sanitized.contains(':')) {
      sanitized = sanitized.replaceAll(RegExp(r'^[a-zA-Z]:\\?'), '');
      sanitized = sanitized.replaceAll(RegExp('^/+'), '');
    }

    // Remove null bytes
    sanitized = sanitized.replaceAll('\x00', '');

    return sanitized;
  }

  // ========================================
  // EMAIL VALIDATION
  // ========================================

  /// Validate email address format
  ///
  /// Checks:
  /// - Valid email format
  /// - No dangerous characters
  /// - Reasonable length
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    if (email.length > 254) return false; // RFC 5321

    // RFC 5322 compliant regex
    final emailRegex = RegExp(
      r'''^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$''',
    );

    return emailRegex.hasMatch(email);
  }

  /// Get email validation error message
  static String? getEmailError(String email) {
    if (email.isEmpty) return 'Email is required';
    if (email.length > 254) return 'Email is too long';
    if (!isValidEmail(email)) return 'Invalid email format';
    return null;
  }

  // ========================================
  // PASSWORD VALIDATION
  // ========================================

  /// Check password strength
  ///
  /// Returns:
  /// - weak: < 8 chars
  /// - fair: 8+ chars
  /// - good: 8+ chars + numbers
  /// - strong: 8+ chars + numbers + special chars
  /// - veryStrong: 12+ chars + numbers + special + mixed case
  static PasswordStrength getPasswordStrength(String password) {
    if (password.length < 8) return PasswordStrength.weak;

    var score = 0;

    // Length
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Contains lowercase
    if (password.contains(RegExp('[a-z]'))) score++;

    // Contains uppercase
    if (password.contains(RegExp('[A-Z]'))) score++;

    // Contains numbers
    if (password.contains(RegExp('[0-9]'))) score++;

    // Contains special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score >= 6) return PasswordStrength.veryStrong;
    if (score >= 5) return PasswordStrength.strong;
    if (score >= 3) return PasswordStrength.good;
    if (score >= 2) return PasswordStrength.fair;
    return PasswordStrength.weak;
  }

  /// Validate password meets minimum requirements
  ///
  /// Requirements:
  /// - At least 8 characters
  /// - At least one number
  /// - At least one letter
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp('[0-9]'))) return false;
    if (!password.contains(RegExp('[a-zA-Z]'))) return false;
    return true;
  }

  /// Get password validation error message
  static String? getPasswordError(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!password.contains(RegExp('[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!password.contains(RegExp('[a-zA-Z]'))) {
      return 'Password must contain at least one letter';
    }
    return null;
  }

  /// Get password strength description
  static String getPasswordStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }

  // ========================================
  // PHONE NUMBER VALIDATION
  // ========================================

  /// Validate phone number (basic international format)
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;

    // Remove common formatting characters
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Check if it's a valid international number
    // Allows: +1234567890 or 1234567890 (7-15 digits)
    final phoneRegex = RegExp(r'^\+?[1-9]\d{6,14}$');

    return phoneRegex.hasMatch(cleaned);
  }

  // ========================================
  // URL VALIDATION
  // ========================================

  /// Validate URL format
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e, st) {
      return false;
    }
  }

  /// Sanitize URL to prevent javascript: and data: protocols
  static String sanitizeUrl(String url) {
    if (url.isEmpty) return url;

    final lower = url.toLowerCase();

    // Block dangerous protocols
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('vbscript:')) {
      return '';
    }

    // Only allow http and https
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return 'https://$url';
    }

    return url;
  }

  // ========================================
  // NUMERIC VALIDATION
  // ========================================

  /// Validate if string is a valid number
  static bool isValidNumber(String input) {
    if (input.isEmpty) return false;
    return double.tryParse(input) != null;
  }

  /// Validate if string is a valid integer
  static bool isValidInteger(String input) {
    if (input.isEmpty) return false;
    return int.tryParse(input) != null;
  }

  /// Sanitize numeric input (remove non-numeric characters)
  static String sanitizeNumericInput(String input, {bool allowDecimal = true}) {
    if (input.isEmpty) return input;

    if (allowDecimal) {
      return input.replaceAll(RegExp('[^0-9.]'), '');
    } else {
      return input.replaceAll(RegExp('[^0-9]'), '');
    }
  }

  // ========================================
  // RATE LIMITING HELPERS
  // ========================================

  static final Map<String, DateTime> _rateLimits = {};

  /// Check if action is rate limited
  ///
  /// Example:
  /// ```dart
  /// if (SecurityUtils.isRateLimited('login:user@example.com', Duration(minutes: 5))) {
  ///   // Too many attempts
  ///   return;
  /// }
  /// ```
  static bool isRateLimited(String key, Duration duration) {
    final now = DateTime.now();

    if (_rateLimits.containsKey(key)) {
      final lastAttempt = _rateLimits[key]!;
      final difference = now.difference(lastAttempt);

      if (difference < duration) {
        return true; // Still rate limited
      }
    }

    _rateLimits[key] = now;
    return false; // Not rate limited
  }

  /// Clear rate limit for a key
  static void clearRateLimit(String key) {
    _rateLimits.remove(key);
  }

  /// Clear all rate limits (useful for testing)
  static void clearAllRateLimits() {
    _rateLimits.clear();
  }

  // ========================================
  // GENERAL VALIDATION
  // ========================================

  /// Validate required field
  static bool isRequired(String? input) =>
      input != null && input.trim().isNotEmpty;

  /// Validate minimum length
  static bool hasMinLength(String input, int minLength) =>
      input.length >= minLength;

  /// Validate maximum length
  static bool hasMaxLength(String input, int maxLength) =>
      input.length <= maxLength;

  /// Validate string contains only alphanumeric characters
  static bool isAlphanumeric(String input) =>
      RegExp(r'^[a-zA-Z0-9]+$').hasMatch(input);

  /// Validate string contains only letters
  static bool isAlpha(String input) => RegExp(r'^[a-zA-Z]+$').hasMatch(input);

  // ========================================
  // LOGGING & MONITORING
  // ========================================

  /// Log security event (for monitoring)
  static void logSecurityEvent(String event, {Map<String, dynamic>? details}) {
    if (kDebugMode) {
      debugPrint('ðŸ”’ [SECURITY] $event');
      if (details != null) {
        debugPrint('  Details: $details');
      }
    }

    // In production, send to analytics/monitoring
    // AnalyticsIntegrationService.logEvent('security_event', {
    //   'event': event,
    //   ...?details,
    // });
  }
}
