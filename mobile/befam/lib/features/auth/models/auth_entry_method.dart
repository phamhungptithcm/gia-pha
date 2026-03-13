enum AuthEntryMethod { phone, child }

extension AuthEntryMethodX on AuthEntryMethod {
  String get summaryLabel {
    return switch (this) {
      AuthEntryMethod.phone => 'Phone login',
      AuthEntryMethod.child => 'Child access',
    };
  }

  String get entryTitle {
    return switch (this) {
      AuthEntryMethod.phone => 'Sign in with a phone number',
      AuthEntryMethod.child => 'Sign in with a child identifier',
    };
  }
}
