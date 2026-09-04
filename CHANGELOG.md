# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `grow`/`SetGrow()` (any node): a flexible child's own share of its parent's leftover main-axis space, relative to its equally-flexible siblings. Default `1`, matching the previous always-even split; `grow = 0` claims none of the leftover. No effect on a node with its own explicit main-axis `width`/`height`, or on the root. `justify` now only matters when nothing among its children has a positive `grow` share, not merely when nothing is flexible.
- `minWidth`/`maxWidth`/`minHeight`/`maxHeight` and their setters (any node): a floor or ceiling on a node's own flexible size, whether that's its flexed main-axis share or a `STRETCH`-ed cross-axis size. No effect on a node with its own explicit `width`/`height`, `"AUTO"`, or non-`STRETCH` alignment. Errors if a node's own min is greater than its max. On the main axis, if clamping leaves every flexible child on a line without any more space to claim, `justify` distributes whatever's left, the same as when nothing on that line is flexible at all.

## [0.3.0] - 2026-09-03

### Added

- `align`/`SetAlign()` (container) and `alignSelf`/`SetAlignSelf()` (any node, overriding the parent's `align`): cross-axis alignment, `"STRETCH"` (default, unchanged behavior), `"START"`, `"CENTER"`, or `"END"`. Anything other than `STRETCH` requires the node's own cross-axis dimension, errors otherwise, alignment never falls back to stretching.
- `justify`/`SetJustify()` (container): main-axis distribution of leftover space, `"START"` (default, unchanged behavior), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only has anything to distribute when nothing among the children is flexible, a flexible child already consumes all the leftover space.
- `"AUTO"`, accepted by `width`/`height`: computes that dimension from this node's own children instead of a fixed number, a sum along a node's own main axis (plus `gap`/`padding`) or a max along its cross axis (plus `padding`), since children stack one after another along the main axis but share the same band along the cross axis. Works on the root too, on either axis. Every visible child needs its own number or `"AUTO"`, a flexible child errors.
- `wrap`/`SetWrap()` (container): overflowing children start a new line instead of continuing past the main axis size. Each line gets its own cross-size (the same max-over-children formula as cross-axis `"AUTO"`) and stacks after the previous one, `gap` between lines too. `align`/`justify` apply per line, independently, not once across the whole container. Combined with cross-axis `"AUTO"`, that dimension sums every line's own max instead of one flat max over every child regardless of line. Default `false`, unchanged behavior.

### Changed

- **Breaking:** `size`/`SetSize()` renamed to `width`; `crossSize`/`SetCrossSize()` renamed to `height`. Both are now genuinely physical (always horizontal/vertical, regardless of `direction`), rather than always meaning "main axis"/"cross axis". A node's own main-axis dimension within its parent is still whichever one that parent's `direction` puts on that axis (`width` for a ROW parent, `height` for a COLUMN one); the other one is its cross-axis size, same roles as before, just renamed.
- The root passed to `Waffle:Flex()` no longer has its own type (`WaffleFlexRootNode` is gone); it shares `WaffleFlexNode` with every other node, `width`/`height` included, and needs both explicitly (one as `"AUTO"` if that's its own main axis), same requirement it already had before this change.
- `defaultFrameFactory` is no longer root-exclusive. Any node can declare one, applying to everything below it and overriding whatever's inherited from further up the tree. Never applies to the node that declares it, root included, the root now needs its own `frame`/`frameFactory` too, `defaultFrameFactory` alone is no longer enough to resolve it.
- Improved `Layout()` performance for containers using `"AUTO"` sizing or `wrap`, especially deeply nested or heavily wrapped trees, by eliminating redundant recomputation within a single call.

### Fixed

- `GetChildren()` returned children in visual `order`, not declaration order as documented, once any child had a non-default `order` and `Layout()` had run. Now consistently returns declaration order.

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
