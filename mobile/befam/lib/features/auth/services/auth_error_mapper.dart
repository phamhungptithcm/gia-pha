import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorMapper {
  const AuthErrorMapper._();

  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-phone-number' =>
          'Enter a valid phone number, including the country code if needed.',
        'invalid-verification-code' =>
          'That code does not match. Check the OTP and try again.',
        'session-expired' =>
          'The verification session expired. Request a new OTP to continue.',
        'network-request-failed' =>
          'Network connection failed. Check your internet connection and try again.',
        'too-many-requests' =>
          'Too many authentication attempts were made. Please wait a moment and try again.',
        'quota-exceeded' =>
          'OTP quota has been reached for now. Please try again later.',
        'user-not-found' =>
          'We could not find a matching family record for that information yet.',
        'operation-not-allowed' =>
          'This sign-in method is not enabled for the current Firebase project.',
        _ =>
          error.message ?? 'Authentication could not be completed right now.',
      };
    }

    if (error is FormatException) {
      return error.message.toString();
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return 'Something went wrong while preparing sign-in. Please try again.';
  }
}
