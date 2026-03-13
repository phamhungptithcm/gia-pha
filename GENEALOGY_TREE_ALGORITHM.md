# GENEALOGY TREE ALGORITHM
## Rendering and Query Strategy for 50k+ Nodes

This document explains how to model, query, build, and render very large genealogy trees efficiently.

## 1. Problem Statement

A genealogy tree is a graph-like structure with:
- parent-child relationships
- spouse links
- sibling groups derived from parents

At clan scale, the total number of members may exceed what a mobile canvas can render at once.
Firestore is not optimized for recursive graph traversal.

Therefore:
- the client must not fetch node-by-node recursively
- the UI must not render the entire graph expanded
- the system must build view-specific subgraphs

## 2. Design Goals

- handle 50k+ members across a clan
- render a focused subtree interactively
- provide fast navigation to ancestors and descendants
- support search-to-focus
- avoid layout thrashing on mobile

## 3. Canonical Data Inputs

Data sources:
- `members`
- `relationships`

Preferred canonical edge:
- `relationships` collection with `parent_child` and `spouse`

Denormalized helpers:
- `parentIds`
- `childrenIds`
- `spouseIds`

## 4. Read Model Strategy

### 4.1 Never load all nodes for initial view

Initial tree entry points should come from:
- searched member
- current logged-in member
- branch root
- founder / clan root

### 4.2 Tree Query Modes

Support multiple query modes:

#### Mode A: Focus Member View
Load:
- focused member
- parents up to configurable depth
- children up to configurable depth
- spouse
- siblings optional

#### Mode B: Branch Root View
Load:
- branch entry member(s)
- descendants to depth N
- collapse remaining descendants behind "load more"

#### Mode C: Ancestor View
Load:
- member and all ancestors to root or max depth

#### Mode D: Descendant View
Load:
- member and descendants to depth N

## 5. Graph Construction

Build in-memory structures:

```text
Map<MemberId, MemberNode>
Map<MemberId, List<MemberId>> parentMap
Map<MemberId, List<MemberId>> childMap
Map<MemberId, List<MemberId>> spouseMap
```

Where `MemberNode` contains:
- raw member profile
- display fields
- cached generation
- flags for expansion state

## 6. Traversal Algorithms

### 6.1 Ancestor BFS

Use breadth-first traversal upwards with a depth limit.

Pseudo:
```text
queue = [(focusMemberId, 0)]
while queue not empty:
  current, depth = pop()
  if depth > maxDepth: continue
  add current
  for parent in parentMap[current]:
    push(parent, depth + 1)
```

### 6.2 Descendant BFS

Same pattern using `childMap`.

### 6.3 Sibling Discovery

To find siblings:
- collect parents of current member
- collect all children of those parents
- remove current member

### 6.4 Cycle Detection

Parent-child edges must form a DAG in genealogical context.
Before adding a parent-child edge:
- run bounded DFS/BFS from proposed child downward
- if proposed parent is reachable from child descendants, reject

## 7. Layout Strategy

### 7.1 Recommended visual strategy

Use a layered tree layout:
- ancestors above
- focus member in center
- descendants below
- spouses placed horizontally adjacent
- siblings grouped horizontally within same generation row

### 7.2 Do not use full auto-layout for 50k nodes

Global graph layout is too expensive and not useful on mobile.
Instead:
- layout only visible nodes
- recompute layout for current viewport subtree

### 7.3 Layout Model

Each visible node has:
- `x`
- `y`
- `width`
- `height`
- `row`
- `column`

Rows represent generation distance from focus:
- ancestors: negative rows
- focus: row 0
- descendants: positive rows

Spouse nodes share the same row.

## 8. Virtualization Strategy

For very large trees:
- visible node count should stay under a practical limit such as 100 to 300 nodes
- collapsed groups represent hidden descendants
- only materialize nodes when expanded
- use viewport clipping so only visible widgets/paint objects are drawn

Recommended:
- render with `CustomPainter` or custom render object for connectors
- overlay interactive node widgets only for visible nodes

## 9. Expansion Strategy

Each node maintains:
- `isAncestorsExpanded`
- `isDescendantsExpanded`
- `hasMoreAncestors`
- `hasMoreDescendants`

On expansion:
- fetch next edge set if not locally cached
- update adjacency structures
- rebuild visible layout only

## 10. Caching Strategy

### Client cache layers
- member profile cache
- relation adjacency cache
- subtree snapshot cache keyed by focus member + depth + mode

### Invalidations
Invalidate relevant subtree cache when:
- relationship changes
- member moved branch
- member name/profile changed only if display cache uses it

## 11. Search-to-Focus Flow

1. user searches member
2. search returns lightweight results
3. user selects member
4. app loads focus-member tree query
5. tree centers on selected member
6. user expands ancestors or descendants as needed

## 12. Generation Computation

Generation may be precomputed from known roots but can be imperfect in partial data.
Use:
- stored `generation` if present
- fallback relative generation from current focus view

For visualization, relative generation is enough:
- focus row 0
- parent row -1
- child row +1

## 13. Conflict and Data Quality Handling

Real genealogy data may be incomplete or inconsistent.

Cases:
- unknown parent
- missing spouse counterpart
- duplicate member
- conflicting birth order
- invalid cycles from manual entry

Approach:
- visualize incomplete links gracefully
- log validation warnings
- block only hard-invalid operations such as cycles

## 14. Suggested Data APIs for Tree Loading

### API 1: loadTreeFocus
Input:
- clanId
- focusMemberId
- ancestorDepth
- descendantDepth
- includeSiblings

Output:
- member docs
- relationship docs
- summary counts for hidden branches

### API 2: expandDescendants
Input:
- focusMemberId
- targetMemberId
- nextDepth

### API 3: expandAncestors
Input:
- focusMemberId
- targetMemberId
- nextDepth

These can be implemented client-side from Firestore or via callable Cloud Functions for heavy clans.

## 15. Complexity Notes

Let:
- V = visible nodes
- E = visible edges

Target complexity per render:
- traversal: O(V + E)
- layout: O(V log V) or better
- drawing: O(V + E)

Avoid:
- O(N^2) sibling alignment passes across full clan size

## 16. Testing Strategy

Test cases:
- simple linear ancestry
- two parents with multiple children
- spouse links
- incomplete parents
- multi-branch descendants
- cycle attempt rejection
- 1k visible node synthetic dataset
- 50k member metadata search and focused load scenario

## 17. Recommended MVP Limits

- default initial ancestor depth: 2
- default initial descendant depth: 2
- max auto-expanded visible nodes: 120
- require explicit expand when hidden descendants > threshold

## 18. Future Enhancements

- server-generated tree snapshot documents
- branch subtree materialization
- relationship confidence scoring
- timeline-linked genealogy events
