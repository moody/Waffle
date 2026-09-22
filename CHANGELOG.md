# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `onMeasure` node field, with `Component:SetOnMeasure()` and `Component:GetOnMeasure()`, for content Waffle cannot size itself, such as text whose height depends on its width. A node that leaves its `width` or `height` `"AUTO"` is asked for the size, given the width and height already known. A node with `onMeasure` cannot have `children`.
- `Component:MarkDirty()`, which marks a node's tree dirty so the next `Layout()` runs even though no field changed. Useful for content that changed outside Waffle, such as text `onMeasure` sizes.

### Fixed

- A wrapping node with `"AUTO"` cross size is now sized the same inside a wrapping parent as inside a non-wrapping one. Before, in a wrapping ROW, a wrapping COLUMN with `width = "AUTO"` was one column wide and a wrapping node with a flexible width was one line tall, so its children overflowed.
- A node with an `"AUTO"` cross size now sizes a flexible child for the size the child ends up with. Before, a wrapping node with `height = "AUTO"` and a flexible width was one line tall, and so was the node around it.
- A wrapping node's own `padding` is now left out of the width its `"AUTO"` height wraps against, so its children no longer overflow it.

## [0.11.0] - 2026-09-20

### Added

- `Component:IsVisible()`: returns `true` if a node's own `visibility` is `"VISIBLE"` or unset, in any case. It ignores an ancestor's `visibility` and whether the frame is actually shown.

### Changed

- **Breaking:** `onLayout` receives this node's frame again as its first argument (`onLayout(frame, width, height)`), not its component. If you need the component, keep a reference to it, or look it up from the root with `FindByKey()`.
- **Breaking:** `direction`, `align`, `alignSelf`, and `justify` now throw an error on an unrecognized value, where before it silently fell back to a default. `SetDirection()`, `SetAlign()`, `SetAlignSelf()`, and `SetJustify()` throw for one too. Still case insensitive.

### Fixed

- A wrapping node with `height = "AUTO"` (or a wrapping COLUMN with `width = "AUTO"`) now counts the lines its actual width produces when that width is stretched by its parent or flexed with `grow`. Before, only an explicit or percentage width was counted, so the node reported a single line's height while its children wrapped past it. It also holds through nested `"AUTO"` containers.

## [0.10.0] - 2026-09-20

### Added

- `visibility` node field, with `Component:SetVisibility()` and `Component:GetVisibility()`. `"INVISIBLE"` hides a node's frame but keeps its space in the layout, so its siblings do not reflow. `"GONE"` excludes it from the layout entirely, and `"VISIBLE"` is the default. Case insensitive, and any other value throws an error.

### Changed

- **Breaking:** `hidden`, `SetHidden()`, and `GetHidden()` are replaced by `visibility`, `SetVisibility()`, and `GetVisibility()`. `visibility = "GONE"` behaves exactly as `hidden = true` did. Replace `hidden = true` with `visibility = "GONE"`, `component:SetHidden(true)` with `component:SetVisibility("GONE")`, `component:SetHidden(false)` with `component:SetVisibility("VISIBLE")`, and `component:GetHidden()` with `component:GetVisibility()`. A leftover `hidden` field in a node table is ignored, so that node is shown.

## [0.9.0] - 2026-09-20

### Added

- `Component:WhenFrameReady(callback)`: calls a function once with a node's frame, immediately if the frame already exists, otherwise right after Waffle creates it and before it is parented, sized, or shown. For setup that needs the frame, such as `HookScript()`. Callbacks run in registration order.

## [0.8.1] - 2026-09-09

### Changed

- `WaffleFrameShape` and `WafflePoint` annotations are removed; `WaffleFrame` goes back to a plain `table` alias. A bare `table` alone already stops LuaCATS from diffing against a real widget, making the separate strict shape unnecessary.

## [0.8.0] - 2026-09-07

### Added

- A getter for every field that already has a setter (e.g. `GetWidth()`, `GetGrow()`, `GetPadding()`), returning the raw value most recently given, `nil` if unset.
- `Component:GetSize()`: returns `width`/`height` together, the same values `SetWidth()`/`SetHeight()` (or `SetSize()`) were last given.

### Changed

- `WaffleFrame` (the type of `frame`/`frameFactory`/`GetFrame()`) no longer requires an exact match against its documented shape; any table is accepted. That shape is still available under its own name, `WaffleFrameShape`.
- **Breaking:** `Hide()`/`Show()` are replaced by `SetHidden()`, and `IsHidden()` by `GetHidden()`, matching every other field's own setter/getter pair. Replace `component:Hide()` with `component:SetHidden(true)`, `component:Show()` with `component:SetHidden(false)`, and `component:IsHidden()` with `component:GetHidden()`.
- **Breaking:** `GetChild(key)` renamed to `FindByKey(key)`. It always searched the whole tree by `key`, not just this node's own children, unlike `GetChildren()`; the old name read as if it were scoped the same way. Behavior is unchanged, replace `component:GetChild(key)` with `component:FindByKey(key)`.

### Fixed

- A hidden node now hides every already-resolved frame in its own subtree, not just its own frame. Previously a frame that was already resolved anywhere inside a hidden node's subtree, whether from `AddChild()`/`AttachComponent()` or a declarative `children` table, stayed visible, wherever it was last positioned, until that node was shown.

## [0.7.0] - 2026-09-07

### Added

- `Component:SetDefaultFrameFactory()`: sets or clears a node's own `defaultFrameFactory` after construction. Only affects a descendant still waiting on a factory to resolve its frame.
- `Component:SetDirection()`: sets a node's own main axis after construction. Previously only settable via `Waffle:Flex()`/`AddChild()`/`AddRow()`/`AddColumn()`.
- `Component:SetKey()`: sets or clears a node's own `key` after construction. Never marks the tree dirty, unlike every other setter.
- `Component:SetOnLayout()`: sets or clears a node's own `onLayout` after construction. Previously only settable declaratively.
- `Component:SetSize(width, height)`: sets `width`/`height` together, equivalent to `SetWidth()`/`SetHeight()`. Omitting either argument passes nil, resetting that dimension instead of leaving it unchanged.

### Changed

- **Breaking:** `onLayout` now fires once an entire `Layout()` pass is resolved and its dirty flag already cleared, not while it's still running. Firing order is unchanged: bottom-up, children before parents, root last. Mutating a different node from inside `onLayout` now reliably marks its own tree dirty again, scheduling a future `Layout()` call, instead of that mark being silently discarded by this same call's own dirty-clear.

## [0.6.0] - 2026-09-06

### Added

- `Component:AttachComponent(component)`: grafts an already-composed component into this node's children, as-is, instead of building a new one from a declarative table. Its own direction, size, and structure are unchanged. Errors if `component` already belongs to a different one, same as `AddChild`.
- `Component:Detach()`: detaches a component from its current owner without needing to already hold that owner, the same as calling `DetachComponent()` on it. Always returns itself, whether or not it actually had an owner to release, so it composes directly into a single call that moves a component into a different tree.

### Changed

- **Breaking:** `WaffleFlexComponentContainer` and `WaffleFlexComponentLeaf` are merged into one `WaffleFlexComponent`. Whether a node has children was already just a fact about it, not a fixed type; every method (`AddChild`, `SetGap`, etc.) is now available on every component regardless. `IsContainer()` is removed, having no meaning left to report: check `#component:GetChildren() > 0` instead if needed.
- **Breaking:** `RemoveChild()` renamed to `DetachComponent()`, and now takes/describes a `component`, matching the type it always actually took. Behavior is unchanged.
- **Breaking:** `onLayout` receives this node's own component instead of its frame, as its first argument (`onLayout(component, width, height)`, not `onLayout(frame, width, height)`). Use `component:GetFrame()` to get the frame; the component also reaches anywhere else in the tree with `GetChild`, letting a callback react to what was just resolved by adjusting a sibling.

## [0.5.0] - 2026-09-06

### Added

- `direction` accepts `"ROW_REVERSE"`/`"COLUMN_REVERSE"` (any node): the same main axis as `"ROW"`/`"COLUMN"`, but children lay out starting from the opposite edge. `order` still sorts first, the `_REVERSE` variants only flip which edge that sorted sequence starts from.
- `width`/`height` accept a percentage string (`"50%"`), sizing relative to the parent's own width/height instead of a fixed number. No effect on `minWidth`/`maxWidth`, same as any other fixed size. Errors without a parent whose own size is already resolved: the root, or a parent whose own main axis is itself still being computed from `"AUTO"`.
- `shrink`/`SetShrink()` (any node): an overflowing child's own share of its parent's main-axis deficit, weighted by this value times the child's own size, not the value alone. Default `1`; `shrink = 0` never gives up any of a child's own stated size. `minWidth`/`minHeight` floors how far a child shrinks, the same as it already floors a flexible child's own share; `maxWidth`/`maxHeight` has no effect, a child only ever shrinks down from its own stated size, never up past it. No effect on a flexible node, or on the root.
- `lineGap`/`SetLineGap()` (container): space between wrapped lines, independent of `gap` between the children within each one. Falls back to `gap` when unset. No effect unless `wrap` actually produces more than one line.

### Changed

- Reduced memory allocation on repeated `Layout()` calls for `wrap`/cross-axis-`"AUTO"` trees, previously a real, if bounded and fully garbage-collected, memory sawtooth on heavier trees.

## [0.4.0] - 2026-09-04

### Added

- `grow`/`SetGrow()` (any node): a flexible child's own share of its parent's leftover main-axis space, relative to its equally-flexible siblings. Default `1`, matching the previous always-even split; `grow = 0` claims none of the leftover. No effect on a node with its own explicit main-axis `width`/`height`, or on the root. `justify` now only matters when nothing among its children has a positive `grow` share, not merely when nothing is flexible.
- `minWidth`/`maxWidth`/`minHeight`/`maxHeight` and their setters (any node): a floor or ceiling on a node's own flexible size, whether that's its flexed main-axis share or a `STRETCH`-ed cross-axis size. No effect on a node with its own explicit `width`/`height`, `"AUTO"`, or non-`STRETCH` alignment. Errors if a node's own min is greater than its max. On the main axis, if clamping leaves every flexible child on a line without any more space to claim, `justify` distributes whatever's left, the same as when nothing on that line is flexible at all.
- `paddingTop`/`paddingRight`/`paddingBottom`/`paddingLeft` and their setters (container): override `padding` for one side only, falling back to it for any side not given. `"AUTO"` sizing on either axis sums in the matching pair instead of `padding` uniformly on both ends.
- `margin`/`marginTop`/`marginRight`/`marginBottom`/`marginLeft` and their setters (any node): space around a node itself, independent of the container's own `gap`. On the main axis, adds to the space this node consumes, coming out of a flexible sibling's own share the same way an explicit size would; it also counts toward whether the node still fits on the current line under `wrap`. On the cross axis, insets a `STRETCH`-ed size, or centers/end-aligns the node's own margin box rather than just its content under `CENTER`/`END`. `"AUTO"` sizing on either axis includes each child's own margin along with its size.

## [0.3.0] - 2026-09-03

### Added

- `align`/`SetAlign()` (container) and `alignSelf`/`SetAlignSelf()` (any node, overriding the parent's `align`): cross-axis alignment, `"STRETCH"` (default, unchanged behavior), `"START"`, `"CENTER"`, or `"END"`. Anything other than `STRETCH` requires the node's own cross-axis dimension, errors otherwise, alignment never falls back to stretching.
- `justify`/`SetJustify()` (container): main-axis distribution of leftover space, `"START"` (default, unchanged behavior), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only has anything to distribute when nothing among the children is flexible, a flexible child already consumes all the leftover space.
- `"AUTO"`, accepted by `width`/`height`: computes that dimension from this node's own children instead of a fixed number, a sum along a node's own main axis (plus `gap`/`padding`) or a max along its cross axis (plus `padding`), since children stack one after another along the main axis but share the same band along the cross axis. Works on the root too, on either axis. Every visible child needs its own number or `"AUTO"`, a flexible child errors.
- `wrap`/`SetWrap()` (container): overflowing children start a new line instead of continuing past the main axis size. Each line gets its own cross-size (the same max-over-children formula as cross-axis `"AUTO"`) and stacks after the previous one, `gap` between lines too. `align`/`justify` apply per line, independently, not once across the whole container. Combined with cross-axis `"AUTO"`, that dimension sums every line's own max instead of one flat max over every child regardless of line. Default `false`, unchanged behavior.

### Changed

- **Breaking:** `size`/`SetSize()` renamed to `width`, now genuinely physical (always horizontal, regardless of `direction`) instead of always meaning the main-axis dimension. `height`/`SetHeight()` is new: a node's own physical, vertical size, previously fixed to always stretch across the cross axis with no way to override it. A node's own main-axis dimension within its parent is still whichever one that parent's `direction` puts on that axis (`width` for a ROW parent, `height` for a COLUMN one); the other one is its cross-axis size.
- The root passed to `Waffle:Flex()` no longer has its own type (`WaffleFlexRootNode` is gone); it shares `WaffleFlexNode` with every other node, `width`/`height` included, and needs both explicitly (one as `"AUTO"` if that's its own main axis), same requirement it already had before this change.
- `defaultFrameFactory` is no longer root-exclusive. Any node can declare one, applying to everything below it and overriding whatever's inherited from further up the tree. Never applies to the node that declares it, root included, the root now needs its own `frame`/`frameFactory` too, `defaultFrameFactory` alone is no longer enough to resolve it.

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
- Ownership tracking: `AddChild()`/`AddRow()`/`AddColumn()` now error if a node already belongs to a different container, catching accidental double-attachment. Covers purely declarative `children` trees too, not just the fluent API.
- Moving a node to a different container, or even an entirely different `Waffle:Flex()` tree, via `RemoveChild()` then `AddChild()`.

### Changed

- The root passed to `Waffle:Flex()` is no longer a special shape, it shares `WaffleFlexNode` with every other node in the tree. `frame`, `frameFactory`, `key`, `hidden`, and `onLayout` all now work identically for the root as for any child.
- `onLayout` no longer replaces `children` being laid out, both fire, `onLayout` after `children` are resolved, not instead of them.
- `AddChild()` now returns a wrapper for the appended child, a container if it has its own `children`, a leaf otherwise, instead of the same builder it was called on.
- `Layout()` is callable from any node in the tree, not just the root; it resolves and lays out the tree's actual current root regardless of which node it's called on.
- Frame resolution (`frame`/`frameFactory`/`defaultFrameFactory`) now behaves identically for the root and every child, instead of following separate, duplicated logic.
- Reduced memory allocation during `Layout()`, previously one throwaway table per node in the tree on every call.

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
