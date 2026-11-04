class Validation {
  static String? commonValidation({
    required String? input,
    required String label,
    int? length,
    required bool isReq,
  }) {
    if (isReq) {
      if (input != null) {
        if (input.isEmpty) {
          return "$label is required";
        }
        if (length != null) {
          if (input.length < length) {
            return "$label must be at least $length characters long";
          }
        }
      }
    }
    return null;
  }

  static String? validEmail({required String? input, bool isReq = false}) {
    final value = input?.trim() ?? '';

    // Required validation
    if (isReq && value.isEmpty) {
      return 'Email is required';
    }

    // Skip further validation if empty & not required
    if (value.isEmpty) {
      return null;
    }

    // Space validation
    if (value.contains(' ')) {
      return 'Email should not contain spaces';
    }

    // Email format validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email address';
    }

    return null;
  }

  static String? validUrl({required String input, bool? isReq}) {
    if (isReq ?? false) {
      if (input.isEmpty) {
        return 'Url is required';
      }
    }
    if (input.isNotEmpty) {
      if (!RegExp(r'^(http|https)://[^\s/$.?#].[^\s]*$').hasMatch(input)) {
        return 'Invalid url';
      }
    }
    return null;
  }

  static String? passwordValidation({
    required String? input,
    required bool isReq,
  }) {
    if (input != null) {
      if (input.length < 8) {
        return "Must be at least 8 characters long";
      }

      if (!RegExp(r'[A-Z]').hasMatch(input)) {
        return "Must contain at least one uppercase letter";
      }

      if (!RegExp(r'[a-z]').hasMatch(input)) {
        return "Must contain at least one lowercase letter";
      }

      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(input)) {
        return "Must contain at least one special character";
      }

      if (!RegExp(r'\d').hasMatch(input)) {
        return "Must contain at least one number";
      }
    }

    return null;
  }

  static String? validAddress({required String input, bool isReq = false}) {
    if (isReq && input.isEmpty) {
      return 'Address is required';
    }

    if (input.isNotEmpty) {
      if (input.length > 150) {
        return 'Address is too long (max 150 characters)';
      }

      if (!RegExp(r'^[a-zA-Z0-9\s,.\-#/]+$').hasMatch(input)) {
        return 'Invalid characters in address';
      }
    }

    return null;
  }

  static String? validMobileNumber({
    required String? input,
    bool isReq = false,
  }) {
    final value = input?.trim() ?? '';

    // Required validation
    if (isReq && value.isEmpty) {
      return 'Mobile number is required';
    }

    // Skip if empty & not required
    if (value.isEmpty) {
      return null;
    }

    // Space validation
    if (value.contains(' ')) {
      return 'Mobile number should not contain spaces';
    }

    // Digits only
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Mobile number must contain only digits';
    }

    // Length validation
    if (value.length != 10) {
      return 'Mobile number must be 10 digits';
    }

    // Indian mobile validation
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Invalid mobile number';
    }

    return null;
  }

  static String? validName({
    required String? input,
    String label = 'Name',
    bool isReq = true,
  }) {
    if (isReq && (input == null || input.isEmpty)) {
      return '$label is required';
    }

    if (input != null && input.isNotEmpty) {
      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(input)) {
        return '$label must contain only alphabets';
      }
    }

    return null;
  }

  static String? validGstVat({required String? input, bool isReq = false}) {
    if (isReq && (input == null || input.isEmpty)) {
      return 'GST/VAT number is required';
    }

    if (input != null && input.isNotEmpty) {
      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(input)) {
        return 'GST/VAT must contain only alphanumeric characters';
      }
    }

    return null;
  }

  static String? validPostalCode({required String? input, bool isReq = false}) {
    if (isReq && (input == null || input.isEmpty)) {
      return 'Postal code is required';
    }

    if (input != null && input.isNotEmpty) {
      // Indian postal code validation: 6 digits, first digit cannot be 0
      if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(input)) {
        return 'Invalid Indian postal code (must be 6 digits)';
      }
    }

    return null;
  }
}
