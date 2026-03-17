import '../../features/member/models/member_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';

enum KinshipTitleRole {
  self,
  spouse,
  sibling,
  sameGenerationRelative,
  parent,
  elderRelativeOneGeneration,
  grandparent,
  greatGrandparent,
  greatGreatGrandparent,
  child,
  youngerRelativeOneGeneration,
  grandchild,
  greatGrandchild,
  greatGreatGrandchild,
  descendant,
}

class KinshipTitleResolver {
  const KinshipTitleResolver._();

  static String resolve({
    required AppLocalizations l10n,
    required MemberProfile viewer,
    required MemberProfile member,
  }) {
    final role = resolveRole(viewer: viewer, member: member);
    return switch (role) {
      KinshipTitleRole.self => l10n.pick(vi: 'Tôi', en: 'Me'),
      KinshipTitleRole.spouse => l10n.pick(vi: 'Vợ/Chồng', en: 'Spouse'),
      KinshipTitleRole.sibling => l10n.pick(vi: 'Anh/Chị/Em', en: 'Sibling'),
      KinshipTitleRole.sameGenerationRelative => l10n.pick(
        vi: 'Anh/Chị/Em họ',
        en: 'Cousin',
      ),
      KinshipTitleRole.parent => l10n.pick(vi: 'Cha/Mẹ', en: 'Parent'),
      KinshipTitleRole.elderRelativeOneGeneration => l10n.pick(
        vi: 'Bác/Chú/Cô/Dì',
        en: 'Aunt/Uncle',
      ),
      KinshipTitleRole.grandparent => l10n.pick(
        vi: 'Ông/Bà',
        en: 'Grandparent',
      ),
      KinshipTitleRole.greatGrandparent => l10n.pick(
        vi: 'Cụ/Cố',
        en: 'Great-grandparent',
      ),
      KinshipTitleRole.greatGreatGrandparent => l10n.pick(
        vi: 'Cụ kỵ',
        en: 'Great-great-grandparent',
      ),
      KinshipTitleRole.child => l10n.pick(vi: 'Con', en: 'Child'),
      KinshipTitleRole.youngerRelativeOneGeneration => l10n.pick(
        vi: 'Cháu',
        en: 'Niece/Nephew',
      ),
      KinshipTitleRole.grandchild => l10n.pick(vi: 'Cháu', en: 'Grandchild'),
      KinshipTitleRole.greatGrandchild => l10n.pick(
        vi: 'Chắt',
        en: 'Great-grandchild',
      ),
      KinshipTitleRole.greatGreatGrandchild => l10n.pick(
        vi: 'Chít',
        en: 'Great-great-grandchild',
      ),
      KinshipTitleRole.descendant => l10n.pick(vi: 'Hậu duệ', en: 'Descendant'),
    };
  }

  static KinshipTitleRole resolveRole({
    required MemberProfile viewer,
    required MemberProfile member,
  }) {
    if (viewer.id == member.id) {
      return KinshipTitleRole.self;
    }
    if (_isSpouse(viewer, member)) {
      return KinshipTitleRole.spouse;
    }
    if (_isSibling(viewer, member)) {
      return KinshipTitleRole.sibling;
    }

    final relativeGeneration = member.generation - viewer.generation;
    switch (relativeGeneration) {
      case -1:
        return _isDirectParent(viewer, member)
            ? KinshipTitleRole.parent
            : KinshipTitleRole.elderRelativeOneGeneration;
      case -2:
        return KinshipTitleRole.grandparent;
      case -3:
        return KinshipTitleRole.greatGrandparent;
      case 0:
        return KinshipTitleRole.sameGenerationRelative;
      case 1:
        return _isDirectChild(viewer, member)
            ? KinshipTitleRole.child
            : KinshipTitleRole.youngerRelativeOneGeneration;
      case 2:
        return KinshipTitleRole.grandchild;
      case 3:
        return KinshipTitleRole.greatGrandchild;
      case 4:
        return KinshipTitleRole.greatGreatGrandchild;
      default:
        if (relativeGeneration < -4) {
          return KinshipTitleRole.greatGreatGrandparent;
        }
        return KinshipTitleRole.descendant;
    }
  }

  static bool _isSpouse(MemberProfile viewer, MemberProfile member) {
    return viewer.spouseIds.contains(member.id) ||
        member.spouseIds.contains(viewer.id);
  }

  static bool _isDirectParent(MemberProfile viewer, MemberProfile member) {
    return viewer.parentIds.contains(member.id);
  }

  static bool _isDirectChild(MemberProfile viewer, MemberProfile member) {
    return viewer.childrenIds.contains(member.id);
  }

  static bool _isSibling(MemberProfile viewer, MemberProfile member) {
    if (viewer.parentIds.isEmpty || member.parentIds.isEmpty) {
      return false;
    }
    final viewerParents = viewer.parentIds.toSet();
    return member.parentIds.any(viewerParents.contains);
  }
}
