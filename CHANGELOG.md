# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `crossSize`/`SetCrossSize()`: a fixed size along the cross axis (height for `ROW`, width for `COLUMN`), overriding the previously-unconditional stretch. Omitted, a node still stretches to fill it, same as before.

### Changed

- `defaultFrameFactory` is no longer root-exclusive. Any node can declare one, applying to everything below it and overriding whatever's inherited from further up the tree. Never applies to the node that declares it, root included, the root now needs its own `frame`/`frameFactory` too, `defaultFrameFactory` alone is no longer enough to resolve it.

## [0.2.0] - 2026-09-01

### Added

- `frameFactory` split into a per-child scoped version, falling back to the root's `defaultFrameFactory`.
- Key-based child lookup, `GetChild(key)`, including declarative `key` fields and duplicate-key tolerance (first match wins).
- `IsDirty()`, on any node, reporting whether its tree has changed since the last `Layout()` call.
- `Hide()`/`Show()` for excluding a node from the layout flow entirely.
- `SetSize()`/`SetGap()`/`SetPadding()` setters.
- `order`/`SetOrder()` for reordering siblings independent of declaration order.
- `RemoveChild()`/`Clear()` for detaching children.
- `GetFrame()` for retrieving a node's resolved frame.
- `GetChildren()` for walking a container's direct children.
- `IsContainer()` for telling a container and a leaf apart.
- Ownership tracking (`NodeParent`): `AddChild()`/`AddRow()`/`AddColumn()` now error if a node already belongs to a different container, catching accidental double-attachment. Covers purely declarative `children` trees too, not just the fluent API.
- Moving a node to a different container, or even an entirely different `Waffle:Flex()` tree, via `RemoveChild()` then `AddChild()`.

### Changed

- `GetChild`'s keyed cache replaced with a live tree walk.
- Internal state wrapped into one internal table instead of loose top-level locals.
- The root passed to `Waffle:Flex()` is no longer a special shape, it shares `WaffleFlexNode` with every other node in the tree. `frame`, `frameFactory`, `key`, `hidden`, and `onLayout` all now work identically for the root as for any child.
- `hidden`/`Hide()`/`Show()` now actually take the root's own frame down and back up; previously inert there.
- `onLayout` no longer replaces `children` being laid out, both fire, `onLayout` after `children` are resolved, not instead of them.
- `AddChild()` now returns a container wrapper, not always a leaf, when the given node already has its own `children`.
- `Layout()` moved off `WaffleFlexComponentContainer` onto the shared `WaffleFlexComponent`, callable from any node in the tree, not just the root. It resolves and lays out the tree's actual current root, regardless of which node it's called on.
- Frame resolution (`frame`/`frameFactory`/`defaultFrameFactory`) extracted into one shared `resolveFrame()`, used identically for the root and every child, instead of duplicated logic.
- `flexLayout()` no longer builds a throwaway table on every recursive call, takes `node`/`frame`/`width`/`height`/`defaultFrameFactory` directly.
- Test suite reorganized under `test/flex/`, split further where a file had grown to cover more than one concern (e.g. `on-layout-tests.lua` split out of `nesting-tests.lua`).

### Fixed

- A wrapper held from before its node was moved into a different tree used to stay stale: mutating it, or calling `Layout()` on it, would silently operate on an orphaned, conflicting copy of the old tree instead of the node's actual current one. Wrappers no longer cache their root at construction, it's derived live by walking up through `NodeParent`, so a moved node's wrapper is always correct.

## [0.1.0] - 2026-08-30

### Added

- Initial `Waffle:Flex()` implementation: row/column layout with fixed and flexible sizing, gap, and padding.
- A child with its own `children` becomes a nested container automatically, no `onLayout` needed.
- `onLayout`, firing with a child's own resolved frame, width, and height, for anything beyond simple `children` recursion.
- A fluent builder API (`AddRow`/`AddColumn`/`AddChild`) for composing layouts programmatically, alongside the declarative table style.
- `Layout()` as a pure recompute of the current tree, re-callable any time state changes.
- An optional `frameFactory`, inherited down the tree unless a child overrides it, so you don't have to `CreateFrame` every wrapper container yourself.
- Annotated with LuaCATS for autocomplete and inline documentation in editors.
- CI running the test suite on push/PR.
