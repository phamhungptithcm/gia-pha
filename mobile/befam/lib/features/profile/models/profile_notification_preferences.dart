class ProfileNotificationPreferences {
  const ProfileNotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.eventReminders = true,
    this.scholarshipUpdates = true,
    this.fundTransactions = true,
    this.systemNotices = true,
    this.quietHoursEnabled = false,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool eventReminders;
  final bool scholarshipUpdates;
  final bool fundTransactions;
  final bool systemNotices;
  final bool quietHoursEnabled;

  factory ProfileNotificationPreferences.fromJson(Map<String, dynamic> json) {
    return ProfileNotificationPreferences(
      pushEnabled: _readBool(json, 'pushEnabled', defaultValue: true),
      emailEnabled: _readBool(json, 'emailEnabled', defaultValue: false),
      eventReminders: _readBool(json, 'eventReminders', defaultValue: true),
      scholarshipUpdates: _readBool(
        json,
        'scholarshipUpdates',
        defaultValue: true,
      ),
      fundTransactions: _readBool(json, 'fundTransactions', defaultValue: true),
      systemNotices: _readBool(json, 'systemNotices', defaultValue: true),
      quietHoursEnabled: _readBool(
        json,
        'quietHoursEnabled',
        defaultValue: false,
      ),
    );
  }

  ProfileNotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? eventReminders,
    bool? scholarshipUpdates,
    bool? fundTransactions,
    bool? systemNotices,
    bool? quietHoursEnabled,
  }) {
    return ProfileNotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      eventReminders: eventReminders ?? this.eventReminders,
      scholarshipUpdates: scholarshipUpdates ?? this.scholarshipUpdates,
      fundTransactions: fundTransactions ?? this.fundTransactions,
      systemNotices: systemNotices ?? this.systemNotices,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'eventReminders': eventReminders,
      'scholarshipUpdates': scholarshipUpdates,
      'fundTransactions': fundTransactions,
      'systemNotices': systemNotices,
      'quietHoursEnabled': quietHoursEnabled,
    };
  }
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required bool defaultValue,
}) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  return defaultValue;
}
