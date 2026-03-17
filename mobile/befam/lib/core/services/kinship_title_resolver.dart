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
    Map<String, MemberProfile>? membersById,
  }) {
    final directory = _memberDirectory(
      viewer: viewer,
      member: member,
      membersById: membersById,
    );
    if (viewer.id == member.id) {
      return l10n.pick(vi: 'Tôi', en: 'Me');
    }
    if (_isSpouse(viewer, member)) {
      return _spouseTitle(l10n: l10n, viewer: viewer, spouse: member);
    }

    final descendantLine = _findDescendantLine(
      fromId: viewer.id,
      targetId: member.id,
      membersById: directory,
    );
    if (descendantLine != null) {
      final side = _lineageSideFromFirstHop(
        firstHopId: descendantLine.firstHopId,
        membersById: directory,
      );
      return _descendantBloodTitle(
        l10n: l10n,
        member: member,
        depth: descendantLine.depth,
        side: side,
      );
    }

    final ancestorLine = _findAncestorLine(
      fromId: viewer.id,
      targetId: member.id,
      membersById: directory,
    );
    if (ancestorLine != null) {
      final side = _lineageSideFromFirstHop(
        firstHopId: ancestorLine.firstHopId,
        membersById: directory,
      );
      return _ancestorTitle(
        l10n: l10n,
        member: member,
        depth: ancestorLine.depth,
        side: side,
      );
    }

    final inLawRelation = _descendantInLawRelation(
      viewer: viewer,
      member: member,
      membersById: directory,
    );
    if (inLawRelation != null) {
      return _descendantInLawTitle(
        l10n: l10n,
        member: member,
        depth: inLawRelation.depth,
        bloodRelativeGender: inLawRelation.bloodRelativeGender,
      );
    }

    final role = resolveRole(viewer: viewer, member: member);
    return switch (role) {
      KinshipTitleRole.self => l10n.pick(vi: 'Tôi', en: 'Me'),
      KinshipTitleRole.spouse => _spouseTitle(
        l10n: l10n,
        viewer: viewer,
        spouse: member,
      ),
      KinshipTitleRole.sibling => l10n.pick(vi: 'Anh chị em', en: 'Sibling'),
      KinshipTitleRole.sameGenerationRelative => l10n.pick(
        vi: 'Anh chị em họ',
        en: 'Cousin',
      ),
      KinshipTitleRole.parent => _parentTitle(l10n: l10n, member: member),
      KinshipTitleRole.elderRelativeOneGeneration => l10n.pick(
        vi: 'Bác chú cô dì',
        en: 'Aunt/Uncle',
      ),
      KinshipTitleRole.grandparent => _grandparentTitle(
        l10n: l10n,
        member: member,
        side: null,
      ),
      KinshipTitleRole.greatGrandparent => l10n.pick(
        vi: 'Cụ',
        en: 'Great-grandparent',
      ),
      KinshipTitleRole.greatGreatGrandparent => l10n.pick(
        vi: 'Cụ kỵ',
        en: 'Great-great-grandparent',
      ),
      KinshipTitleRole.child => _childTitle(l10n: l10n, member: member),
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

  static Map<String, MemberProfile> _memberDirectory({
    required MemberProfile viewer,
    required MemberProfile member,
    required Map<String, MemberProfile>? membersById,
  }) {
    final directory = <String, MemberProfile>{};
    if (membersById != null && membersById.isNotEmpty) {
      directory.addAll(membersById);
    }
    directory[viewer.id] = viewer;
    directory[member.id] = member;
    return directory;
  }

  static _LineageHit? _findDescendantLine({
    required String fromId,
    required String targetId,
    required Map<String, MemberProfile> membersById,
  }) {
    final source = membersById[fromId];
    if (source == null) {
      return null;
    }
    final visited = <String>{fromId};
    final queue = <({String id, int depth, String firstHopId})>[];
    for (final childId in source.childrenIds) {
      final normalized = childId.trim();
      if (normalized.isEmpty || !visited.add(normalized)) {
        continue;
      }
      queue.add((id: normalized, depth: 1, firstHopId: normalized));
    }
    var cursor = 0;
    while (cursor < queue.length) {
      final current = queue[cursor++];
      if (current.id == targetId) {
        return _LineageHit(
          depth: current.depth,
          firstHopId: current.firstHopId,
        );
      }
      final node = membersById[current.id];
      if (node == null) {
        continue;
      }
      for (final childId in node.childrenIds) {
        final normalized = childId.trim();
        if (normalized.isEmpty || !visited.add(normalized)) {
          continue;
        }
        queue.add((
          id: normalized,
          depth: current.depth + 1,
          firstHopId: current.firstHopId,
        ));
      }
    }
    return null;
  }

  static _LineageHit? _findAncestorLine({
    required String fromId,
    required String targetId,
    required Map<String, MemberProfile> membersById,
  }) {
    final source = membersById[fromId];
    if (source == null) {
      return null;
    }
    final visited = <String>{fromId};
    final queue = <({String id, int depth, String firstHopId})>[];
    for (final parentId in source.parentIds) {
      final normalized = parentId.trim();
      if (normalized.isEmpty || !visited.add(normalized)) {
        continue;
      }
      queue.add((id: normalized, depth: 1, firstHopId: normalized));
    }
    var cursor = 0;
    while (cursor < queue.length) {
      final current = queue[cursor++];
      if (current.id == targetId) {
        return _LineageHit(
          depth: current.depth,
          firstHopId: current.firstHopId,
        );
      }
      final node = membersById[current.id];
      if (node == null) {
        continue;
      }
      for (final parentId in node.parentIds) {
        final normalized = parentId.trim();
        if (normalized.isEmpty || !visited.add(normalized)) {
          continue;
        }
        queue.add((
          id: normalized,
          depth: current.depth + 1,
          firstHopId: current.firstHopId,
        ));
      }
    }
    return null;
  }

  static _LineageSide? _lineageSideFromFirstHop({
    required String firstHopId,
    required Map<String, MemberProfile> membersById,
  }) {
    final member = membersById[firstHopId];
    if (member == null) {
      return null;
    }
    return switch (_genderCategory(member.gender)) {
      _GenderCategory.male => _LineageSide.noi,
      _GenderCategory.female => _LineageSide.ngoai,
      _GenderCategory.unknown => null,
    };
  }

  static _DescendantInLawHit? _descendantInLawRelation({
    required MemberProfile viewer,
    required MemberProfile member,
    required Map<String, MemberProfile> membersById,
  }) {
    _DescendantInLawHit? best;
    for (final spouseId in member.spouseIds) {
      final normalized = spouseId.trim();
      if (normalized.isEmpty || normalized == viewer.id) {
        continue;
      }
      final line = _findDescendantLine(
        fromId: viewer.id,
        targetId: normalized,
        membersById: membersById,
      );
      if (line != null) {
        final spouse = membersById[normalized];
        final candidate = _DescendantInLawHit(
          depth: line.depth,
          bloodRelativeGender: _genderCategory(spouse?.gender),
        );
        if (best == null || candidate.depth < best.depth) {
          best = candidate;
        }
      }
    }
    return best;
  }

  static String _spouseTitle({
    required AppLocalizations l10n,
    required MemberProfile viewer,
    required MemberProfile spouse,
  }) {
    final spouseGender = _resolvedSpouseGender(viewer: viewer, spouse: spouse);
    return switch (spouseGender) {
      _GenderCategory.male => l10n.pick(vi: 'Chồng', en: 'Husband'),
      _GenderCategory.female => l10n.pick(vi: 'Vợ', en: 'Wife'),
      _GenderCategory.unknown => l10n.pick(vi: 'Phối ngẫu', en: 'Spouse'),
    };
  }

  static String _parentTitle({
    required AppLocalizations l10n,
    required MemberProfile member,
  }) {
    return switch (_genderCategory(member.gender)) {
      _GenderCategory.male => l10n.pick(vi: 'Cha', en: 'Father'),
      _GenderCategory.female => l10n.pick(vi: 'Mẹ', en: 'Mother'),
      _GenderCategory.unknown => l10n.pick(vi: 'Phụ huynh', en: 'Parent'),
    };
  }

  static String _childTitle({
    required AppLocalizations l10n,
    required MemberProfile member,
  }) {
    return switch (_genderCategory(member.gender)) {
      _GenderCategory.male => l10n.pick(vi: 'Con trai', en: 'Son'),
      _GenderCategory.female => l10n.pick(vi: 'Con gái', en: 'Daughter'),
      _GenderCategory.unknown => l10n.pick(vi: 'Con', en: 'Child'),
    };
  }

  static String _grandparentTitle({
    required AppLocalizations l10n,
    required MemberProfile member,
    required _LineageSide? side,
  }) {
    if (side == null) {
      return switch (_genderCategory(member.gender)) {
        _GenderCategory.male => l10n.pick(vi: 'Ông', en: 'Grandfather'),
        _GenderCategory.female => l10n.pick(vi: 'Bà', en: 'Grandmother'),
        _GenderCategory.unknown => l10n.pick(vi: 'Ông bà', en: 'Grandparent'),
      };
    }
    return switch ((side, _genderCategory(member.gender))) {
      (_LineageSide.noi, _GenderCategory.male) => l10n.pick(
        vi: 'Ông nội',
        en: 'Paternal grandfather',
      ),
      (_LineageSide.noi, _GenderCategory.female) => l10n.pick(
        vi: 'Bà nội',
        en: 'Paternal grandmother',
      ),
      (_LineageSide.ngoai, _GenderCategory.male) => l10n.pick(
        vi: 'Ông ngoại',
        en: 'Maternal grandfather',
      ),
      (_LineageSide.ngoai, _GenderCategory.female) => l10n.pick(
        vi: 'Bà ngoại',
        en: 'Maternal grandmother',
      ),
      (_LineageSide.noi, _GenderCategory.unknown) => l10n.pick(
        vi: 'Ông bà nội',
        en: 'Paternal grandparent',
      ),
      (_LineageSide.ngoai, _GenderCategory.unknown) => l10n.pick(
        vi: 'Ông bà ngoại',
        en: 'Maternal grandparent',
      ),
    };
  }

  static String _descendantBloodTitle({
    required AppLocalizations l10n,
    required MemberProfile member,
    required int depth,
    required _LineageSide? side,
  }) {
    if (depth <= 0) {
      return l10n.pick(vi: 'Tôi', en: 'Me');
    }
    if (depth == 1) {
      return _childTitle(l10n: l10n, member: member);
    }
    if (depth == 2) {
      return _lineageGrandchildTitle(l10n: l10n, side: side);
    }
    if (depth == 3) {
      return _lineageGreatGrandchildTitle(l10n: l10n, side: side);
    }
    if (depth == 4) {
      return _lineageGreatGreatGrandchildTitle(l10n: l10n, side: side);
    }
    return l10n.pick(vi: 'Hậu duệ', en: 'Descendant');
  }

  static String _ancestorTitle({
    required AppLocalizations l10n,
    required MemberProfile member,
    required int depth,
    required _LineageSide? side,
  }) {
    if (depth <= 0) {
      return l10n.pick(vi: 'Tôi', en: 'Me');
    }
    if (depth == 1) {
      return _parentTitle(l10n: l10n, member: member);
    }
    if (depth == 2) {
      return _grandparentTitle(l10n: l10n, member: member, side: side);
    }
    if (depth == 3) {
      if (side == _LineageSide.noi) {
        return l10n.pick(vi: 'Cụ nội', en: 'Paternal great-grandparent');
      }
      if (side == _LineageSide.ngoai) {
        return l10n.pick(vi: 'Cụ ngoại', en: 'Maternal great-grandparent');
      }
      return l10n.pick(vi: 'Cụ', en: 'Great-grandparent');
    }
    return l10n.pick(vi: 'Cụ kỵ', en: 'Great-great-grandparent');
  }

  static String _lineageGrandchildTitle({
    required AppLocalizations l10n,
    required _LineageSide? side,
  }) {
    return switch (side) {
      _LineageSide.noi => l10n.pick(vi: 'Cháu nội', en: 'Paternal grandchild'),
      _LineageSide.ngoai => l10n.pick(
        vi: 'Cháu ngoại',
        en: 'Maternal grandchild',
      ),
      null => l10n.pick(vi: 'Cháu', en: 'Grandchild'),
    };
  }

  static String _lineageGreatGrandchildTitle({
    required AppLocalizations l10n,
    required _LineageSide? side,
  }) {
    return switch (side) {
      _LineageSide.noi => l10n.pick(
        vi: 'Chắt nội',
        en: 'Paternal great-grandchild',
      ),
      _LineageSide.ngoai => l10n.pick(
        vi: 'Chắt ngoại',
        en: 'Maternal great-grandchild',
      ),
      null => l10n.pick(vi: 'Chắt', en: 'Great-grandchild'),
    };
  }

  static String _lineageGreatGreatGrandchildTitle({
    required AppLocalizations l10n,
    required _LineageSide? side,
  }) {
    return switch (side) {
      _LineageSide.noi => l10n.pick(
        vi: 'Chít nội',
        en: 'Paternal great-great-grandchild',
      ),
      _LineageSide.ngoai => l10n.pick(
        vi: 'Chít ngoại',
        en: 'Maternal great-great-grandchild',
      ),
      null => l10n.pick(vi: 'Chít', en: 'Great-great-grandchild'),
    };
  }

  static String _descendantInLawTitle({
    required AppLocalizations l10n,
    required MemberProfile member,
    required int depth,
    required _GenderCategory bloodRelativeGender,
  }) {
    final inferredGender = _inLawGender(
      inLawGender: _genderCategory(member.gender),
      bloodRelativeGender: bloodRelativeGender,
    );
    final titleByGender = switch (inferredGender) {
      _GenderCategory.male => (
        child: l10n.pick(vi: 'Con rể', en: 'Son-in-law'),
        grandchild: l10n.pick(vi: 'Cháu rể', en: 'Grandson-in-law'),
        greatGrandchild: l10n.pick(
          vi: 'Chắt rể',
          en: 'Great-grandchild-in-law',
        ),
        greatGreatGrandchild: l10n.pick(
          vi: 'Chít rể',
          en: 'Great-great-grandchild-in-law',
        ),
      ),
      _GenderCategory.female => (
        child: l10n.pick(vi: 'Con dâu', en: 'Daughter-in-law'),
        grandchild: l10n.pick(vi: 'Cháu dâu', en: 'Granddaughter-in-law'),
        greatGrandchild: l10n.pick(
          vi: 'Chắt dâu',
          en: 'Great-grandchild-in-law',
        ),
        greatGreatGrandchild: l10n.pick(
          vi: 'Chít dâu',
          en: 'Great-great-grandchild-in-law',
        ),
      ),
      _GenderCategory.unknown => (
        child: l10n.pick(vi: 'Con thông gia', en: 'Child-in-law'),
        grandchild: l10n.pick(vi: 'Cháu thông gia', en: 'Grandchild-in-law'),
        greatGrandchild: l10n.pick(
          vi: 'Chắt thông gia',
          en: 'Great-grandchild-in-law',
        ),
        greatGreatGrandchild: l10n.pick(
          vi: 'Chít thông gia',
          en: 'Great-great-grandchild-in-law',
        ),
      ),
    };
    if (depth <= 1) {
      return titleByGender.child;
    }
    if (depth == 2) {
      return titleByGender.grandchild;
    }
    if (depth == 3) {
      return titleByGender.greatGrandchild;
    }
    if (depth == 4) {
      return titleByGender.greatGreatGrandchild;
    }
    return l10n.pick(vi: 'Thông gia hậu duệ', en: 'Descendant in-law');
  }

  static _GenderCategory _resolvedSpouseGender({
    required MemberProfile viewer,
    required MemberProfile spouse,
  }) {
    final spouseGender = _genderCategory(spouse.gender);
    if (spouseGender != _GenderCategory.unknown) {
      return spouseGender;
    }
    final viewerGender = _genderCategory(viewer.gender);
    return switch (viewerGender) {
      _GenderCategory.male => _GenderCategory.female,
      _GenderCategory.female => _GenderCategory.male,
      _GenderCategory.unknown => _GenderCategory.unknown,
    };
  }

  static _GenderCategory _inLawGender({
    required _GenderCategory inLawGender,
    required _GenderCategory bloodRelativeGender,
  }) {
    if (inLawGender != _GenderCategory.unknown) {
      return inLawGender;
    }
    return switch (bloodRelativeGender) {
      _GenderCategory.male => _GenderCategory.female,
      _GenderCategory.female => _GenderCategory.male,
      _GenderCategory.unknown => _GenderCategory.unknown,
    };
  }

  static _GenderCategory _genderCategory(String? rawGender) {
    final normalized = (rawGender ?? '').trim().toLowerCase();
    if (normalized == 'male' ||
        normalized == 'm' ||
        normalized == 'nam' ||
        normalized == 'boy' ||
        normalized == 'man') {
      return _GenderCategory.male;
    }
    if (normalized == 'female' ||
        normalized == 'f' ||
        normalized == 'nữ' ||
        normalized == 'nu' ||
        normalized == 'girl' ||
        normalized == 'woman') {
      return _GenderCategory.female;
    }
    return _GenderCategory.unknown;
  }
}

enum _LineageSide { noi, ngoai }

enum _GenderCategory { male, female, unknown }

class _LineageHit {
  const _LineageHit({required this.depth, required this.firstHopId});

  final int depth;
  final String firstHopId;
}

class _DescendantInLawHit {
  const _DescendantInLawHit({
    required this.depth,
    required this.bloodRelativeGender,
  });

  final int depth;
  final _GenderCategory bloodRelativeGender;
}
