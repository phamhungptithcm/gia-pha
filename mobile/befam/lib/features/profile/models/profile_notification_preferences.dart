class ProfileNotificationPreferences {
  const ProfileNotificationPreferences({
    this.eventReminders = true,
    this.scholarshipUpdates = true,
    this.fundTransactions = true,
    this.systemNotices = true,
  });

  final bool eventReminders;
  final bool scholarshipUpdates;
  final bool fundTransactions;
  final bool systemNotices;

  ProfileNotificationPreferences copyWith({
    bool? eventReminders,
    bool? scholarshipUpdates,
    bool? fundTransactions,
    bool? systemNotices,
  }) {
    return ProfileNotificationPreferences(
      eventReminders: eventReminders ?? this.eventReminders,
      scholarshipUpdates: scholarshipUpdates ?? this.scholarshipUpdates,
      fundTransactions: fundTransactions ?? this.fundTransactions,
      systemNotices: systemNotices ?? this.systemNotices,
    );
  }
}
