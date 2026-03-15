import assert from 'node:assert/strict';
import test from 'node:test';

import {
  normalizeMemberRelationshipArrays,
  reconcileMemberArrays,
} from '../genealogy/relationship-reconciliation';

test('relationship reconciliation contract: parent_child create updates arrays canonically', () => {
  const result = reconcileMemberArrays({
    action: 'create',
    relationshipType: 'parent_child',
    personAId: 'parent_1',
    personBId: 'child_1',
    personAArrays: normalizeMemberRelationshipArrays({
      childrenIds: ['child_2', 'child_1'],
    }),
    personBArrays: normalizeMemberRelationshipArrays({
      parentIds: ['parent_2'],
    }),
  });

  assert.deepEqual(result.personAArrays.childrenIds, ['child_1', 'child_2']);
  assert.deepEqual(result.personBArrays.parentIds, ['parent_1', 'parent_2']);
});

test('relationship reconciliation contract: spouse delete removes only target id', () => {
  const result = reconcileMemberArrays({
    action: 'delete',
    relationshipType: 'spouse',
    personAId: 'm_1',
    personBId: 'm_2',
    personAArrays: normalizeMemberRelationshipArrays({
      spouseIds: ['m_2', 'm_3'],
    }),
    personBArrays: normalizeMemberRelationshipArrays({
      spouseIds: ['m_1', 'm_4'],
    }),
  });

  assert.deepEqual(result.personAArrays.spouseIds, ['m_3']);
  assert.deepEqual(result.personBArrays.spouseIds, ['m_4']);
});
