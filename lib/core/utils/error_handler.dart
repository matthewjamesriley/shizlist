/// Utility class for handling and formatting errors
class ErrorHandler {
  ErrorHandler._();

  /// Check if an error is a network/connection error
  static bool isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socketexception') ||
        errorStr.contains('errno = 7') ||
        errorStr.contains('errno=7') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no address associated') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('connection timed out') ||
        errorStr.contains('no internet');
  }

  /// Get a user-friendly error message
  /// [error] - the caught exception
  /// [fallbackMessage] - message to show for non-network errors (e.g., "Failed to save")
  static String getUserMessage(dynamic error, {String? fallbackMessage}) {
    if (isNetworkError(error)) {
      return 'No internet connection. Please try again.';
    }
    return fallbackMessage ?? 'Something went wrong. Please try again.';
  }
}

