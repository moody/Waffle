# Waffle 🧇

**W**oW **A**ddon **F**lexible **F**rame **L**ayout **E**ngine

Waffle is a flex layout library for World of Warcraft addons, inspired by [CSS Flexbox](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout/Basic_concepts_of_flexbox).

## Features

- Row/column flex layout with fixed and flexible sizing, gap, and padding, no manual `SetPoint` math
- Shrink-to-fit sizing (`width`/`height` accepting `"AUTO"`), so a container can size itself from its own children instead of a fixed number
- Wrapping (`wrap`), so children that would overflow the main axis start a new line instead, each line sized and aligned independently
- A fluent API (`AddRow`, `AddColumn`, `AddChild`) for composing nested layouts, or a fully declarative table if you'd rather write it that way
- `Layout()` is a pure recompute of the current tree, not a one-time construction step, call it again any time state changes and the layout needs to catch up
- An optional frame factory so you don't have to `CreateFrame` every wrapper container yourself
- Annotated with [LuaCATS](https://luals.github.io/wiki/annotations/) for autocomplete and inline documentation in editors
- No dependencies

## Installation

1. **Add the library**: Copy `src/waffle.lua` into your addon, and add it to your TOC file so it loads with the rest of your addon.

2. **Access it**: Waffle attaches itself to your addon's table, available through the varargs `...` in any file:

   ```lua
   local ADDON_NAME, Addon = ...
   local Waffle = Addon.Waffle
   ```

## Usage

**Composing declaratively.** `Waffle:Flex(node)` positions `node.children` in a row or column within `node.frame`, and returns a container. `direction` (`"ROW"` or `"COLUMN"`, defaults to `"ROW"`) decides which physical axis is main and which is cross: a ROW's main axis is horizontal (`width`), its cross axis vertical (`height`); a COLUMN flips that. Nothing runs until `Layout()` is called on it.

```lua
Waffle:Flex({
  frame = frame,
  width = 400,
  height = 300,
  children = {
    { frame = sidebar, width = 100 },
    { frame = content },
  }
}):Layout()
```

A node's own `width`/`height` always mean the same physical thing regardless of `direction`. Whichever one is this node's own main axis within its parent takes exactly that much space along it, splitting whatever's left over evenly with any other flexible siblings that omit theirs; here that's `content` getting the full 300 left after `sidebar`'s 100. The other one is this node's cross-axis size, see alignment below.

**Shrink-to-fit sizing.** `width`/`height` also accept `"AUTO"` instead of a fixed number, computing that dimension from a node's own children instead: a sum along its own main axis (plus `gap`/`padding`), or a max along its cross axis (plus `padding`), since children stack one after another along the main axis but share the same band along the cross axis. Every visible child needs its own number or `"AUTO"` of its own; a flexible child has nothing to measure yet and errors.

```lua
Waffle:Flex({
  frame = frame,
  direction = "ROW",
  width = "AUTO", -- sums icon and label, plus gap/padding
  height = "AUTO", -- maxes over the same two instead
  gap = 8,
  padding = 4,
  children = {
    { frame = icon, width = 24, height = 24 },
    { frame = label, width = 80, height = 16 },
  }
}):Layout()
```

**Distributing leftover main-axis space.** `justify`, set on a container, controls how it spreads out leftover main-axis space among its children, when there is any: `"START"` (the default, unchanged), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only matters when nothing is flexible, a flexible child already consumes all the leftover space, leaving nothing for `justify` to distribute:

```lua
Waffle:Flex({
  frame = frame,
  width = 400,
  height = 40,
  justify = "SPACE_BETWEEN", -- three fixed-size buttons, spread across the full row
  children = {
    { frame = cancelButton, width = 80 },
    { frame = helpButton, width = 80 },
    { frame = okButton, width = 80 },
  }
}):Layout()
```

**Aligning children on the cross axis.** `align`, also set on a container, controls how it aligns its own children along the cross axis: `"STRETCH"` (the default, fills it), `"START"`, `"CENTER"`, or `"END"`. Any child can override it for itself with its own `alignSelf`. Alignment other than `STRETCH` requires that child's own cross-axis dimension (`height`, for a ROW parent), it isn't derived from anything, so give one or expect an error:

```lua
Waffle:Flex({
  frame = frame,
  width = 400,
  height = 100,
  align = "CENTER", -- every child centers within the row's height by default
  children = {
    { frame = icon, height = 32 },
    { frame = label, height = 20, alignSelf = "END" }, -- overrides to hug the bottom instead
  }
}):Layout()
```

The root needs both `width` and `height` given, unlike an ordinary child (see [`Waffle:Flex(node)`](#waffleflexnode) for why).

**Wrapping.** `wrap`, set on a container, makes overflowing children start a new line instead of continuing past the main axis size. Each line gets its own cross-size, computed the same way as cross-axis `"AUTO"` (a max over that line's own children), and stacks after the previous one; `align`/`justify` apply per line, independently, not once across the whole container. Combined with cross-axis `"AUTO"` on the container itself, that dimension sums every line's own cross-size instead of maxing across every child directly.

```lua
Waffle:Flex({
  frame = frame,
  width = 100,
  height = 200,
  wrap = true,
  gap = 8,
  children = {
    { frame = icon1, width = 32, height = 32 },
    { frame = icon2, width = 32, height = 32 },
    { frame = icon3, width = 32, height = 32 }, -- doesn't fit next to icon1/icon2, starts a new line
    { frame = icon4, width = 32, height = 32 },
  }
}):Layout()
```

**Nesting.** A child with its own `children` becomes a nested container, laid out within its own resolved width/height once the parent knows it.

```lua
Waffle:Flex({
  frame = frame,
  width = 400,
  height = 300,
  direction = "COLUMN",
  children = {
    { frame = header, height = 40 },
    {
      frame = body,
      children = {
        { frame = sidebar, width = 100 },
        { frame = content },
      }
    },
  }
}):Layout()
```

**The fluent API.** The same tree, composed fluently instead of as one large nested table. `AddRow`/`AddColumn` append a nested container and return a new container scoped to it; `Layout()` only needs to be called once, and works the same regardless of which node in the tree you call it from.

```lua
local root = Waffle:Flex({ frame = frame, width = 400, height = 300, direction = "COLUMN" })
root:AddChild({ frame = header, height = 40 })

local body = root:AddRow({ frame = CreateFrame("Frame") })
body:AddChild({ frame = sidebar, width = 100 })
body:AddChild({ frame = content })

root:Layout()
```

**Frame factory.** Give a node a `defaultFrameFactory` and any descendant below it that omits both `frame` and its own `frameFactory` gets one automatically, reaching every level of nesting below that point. Handy when most of a layout is just plain positioning boxes, so you don't have to `CreateFrame` each one by hand:

```lua
local root = Waffle:Flex({
  frame = frame,
  width = 400,
  height = 300,
  direction = "COLUMN",
  defaultFrameFactory = function(parent) return CreateFrame("Frame", nil, parent) end
})
root:AddChild({ frame = header, height = 40 })

local body = root:AddRow() -- no frame given, defaultFrameFactory makes one
body:AddChild({ frame = sidebar, width = 100 })
body:AddChild({ frame = content })

root:Layout()
```

A child that needs to be more than an empty box, say one card in a list with its own text, can provide its own `frameFactory` instead, scoped to that child only; its own nested children still fall back to `defaultFrameFactory`. `parent` matters here for `$parent` name substitution: `CreateFrame` resolves it into the parent's actual name at creation time, so it only works if the real parent is passed in immediately, not reparented later:

```lua
body:AddChild({
  frameFactory = function(parent)
    local card = CreateFrame("Frame", "$parent_Card", parent)
    card.text = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.text:SetPoint("CENTER")
    card.text:SetText("Hello")
    return card
  end
})
```

**Reacting to resolved size.** `onLayout` fires with a child's own frame and its resolved width/height, after its `children` (if any) are laid out. Useful for anything Waffle doesn't handle automatically, like keeping a `ScrollFrame`'s scroll child in sync: WoW doesn't resize it to fit the visible area on its own, so its width needs to be set explicitly or wrapped content overflows it:

```lua
root:AddChild({
  frame = scrollFrame,
  onLayout = function(frame, width, height)
    frame.scrollChild:SetWidth(width)
  end
})
```

`onLayout` re-fires on every `Layout()` call, so keep it idempotent, safe to run again and again, not just once.

**Calling `Layout()` again.** Nothing about `Layout()` is one-time, it's a pure recompute of whatever's currently composed. Call it again any time state changes, from any node in the tree, not just the root, it always resolves and lays out the whole tree from its actual current root. A call is a no-op unless something changed since the last one, so it's cheap to call from an `OnUpdate` handler every frame. `IsDirty()` tells you whether a call would actually do anything, without triggering one.

## API

### `Waffle:Flex(node)`

Starts composing a container and returns it. `node` is the root of the tree, the same shape as any other node, except it has no parent to supply a cross axis: it needs both `width` and `height` given, each directly or as `"AUTO"`. `node.children` can be given directly for a fully declarative style. Nothing runs until `Layout()` is called.

### Node

Every node in the tree, whether it's the one passed to `Waffle:Flex()` or a child added via `AddChild`/`AddRow`/`AddColumn`/`children`, shares the same shape, `WaffleFlexNode`:

- **`frame`** — An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
- **`frameFactory`** — Creates this node's own frame, once. Receives the resolved parent as an argument. Cannot be given together with `frame`. If it uses `$parent` name substitution, the parent must be passed in immediately here, not reparented later, substitution happens at creation time.
- **`direction`** — `"ROW"` or `"COLUMN"`. Defaults to `"ROW"`. Applies to this node's own children, if it has any.
- **`gap`** / **`padding`** — Space between/around this node's own children, if it has any. Can also be toggled after the fact with `SetGap()`/`SetPadding()`.
- **`align`** — How this node aligns its own children along the cross axis, if it has any: `"STRETCH"` (default), `"START"`, `"CENTER"`, or `"END"`. Overridden per-child by that child's own `alignSelf`. Can also be toggled after the fact with `SetAlign()`.
- **`alignSelf`** — Overrides the parent's `align` for this node specifically. Requires this node's own cross-axis dimension if not `"STRETCH"`. No effect on the root, nothing above it to align it within. Can also be toggled after the fact with `SetAlignSelf()`.
- **`justify`** — How this node distributes leftover main-axis space among its own children, if it has any: `"START"` (default), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only matters when none of those children are flexible. Can also be toggled after the fact with `SetJustify()`.
- **`wrap`** — Overflowing children start a new line instead of continuing past the main axis size. Each line gets its own cross-size (a max over its own children) and stacks after the previous one, `gap` between lines too. Default `false`. Can also be toggled after the fact with `SetWrap()`.
- **`children`** — Can be given directly for a fully declarative style, instead of `AddChild`/`AddRow`/`AddColumn`; a node written directly into this table is still tracked and protected against double-attachment the same way.
- **`hidden`** — Excludes this node from the layout flow entirely. Can also be toggled after the fact with `Hide()`/`Show()`.
- **`key`** — Registers this node for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key isn't validated against, the first match found wins.
- **`order`** — Visual position among siblings, independent of declaration order. Defaults to `0`; siblings with equal `order` keep their declaration order. No effect on the root, nothing above it to reorder it among. Can also be toggled after the fact with `SetOrder()`.
- **`width`** — This node's own physical width, always horizontal, regardless of `direction`. Used directly as a fixed size, whether that's this node's own main-axis size within its parent (a ROW parent) or its cross-axis size (a COLUMN parent; required if resolved to a non-`STRETCH` alignment there, ignored, falling back to stretching, when `STRETCH`). Omitted, flexes/stretches instead, whichever applies. `"AUTO"` computes it from this node's own children instead: a sum of their own `width` (plus `gap`/`padding`) along this node's own main axis (`direction` is `ROW`), or a max of them (plus `padding`) along its cross axis; every visible child needs its own number or `"AUTO"`, a flexible child errors. Can also be toggled after the fact with `SetWidth()`.
- **`height`** — This node's own physical height, always vertical. Same as `width` in every other respect, `"AUTO"` sums along the main axis when `direction` is `COLUMN`, maxes along the cross axis otherwise. Can also be toggled after the fact with `SetHeight()`.
- **`onLayout`** — Called with this node's frame and resolved width/height, after its `children` (if any) are laid out. Re-fires on every `Layout()` call, keep it idempotent.
- **`defaultFrameFactory`** — Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`. Does not apply to this node; even the tree's actual root needs its own `frame`/`frameFactory`, nothing above it to inherit a fallback from.

### Container

- **`Container:AddChild(child)`** — Appends a child as-is, returning its wrapper: a container if `child` already has its own `children`, a leaf otherwise. Errors if `child` already belongs to a different container, call `RemoveChild()` on that one first to move it here. No-ops if `child` is already this container's own.
- **`Container:AddRow(child?)`** / **`Container:AddColumn(child?)`** — Appends a new ROW/COLUMN container as a child, returning a new container scoped to it. Errors if `child` already belongs to a different container, call `RemoveChild()` on that one first to move it here. No-ops if `child` is already this container's own.
- **`Container:GetChildren()`** — Returns every one of this container's children, wrapped, in declaration order. Container-only. Doesn't recurse into grandchildren.
- **`Container:RemoveChild(child)`** — Removes `child` from this container's children entirely, detaching it (and its own children, if it's itself a container) from the tree rather than excluding it from layout the way `Hide()` does. Doesn't touch `child`'s own frame. Container-only. Returns `true` if `child` was actually found and removed.
- **`Container:Clear()`** — Removes every child from this container, same as calling `RemoveChild` on each one. Container-only. No-ops if already empty.
- **`Container:Layout()`** — Runs the layout for the tree containing this node, starting from its actual current root. Works from any container or leaf, not just the root container. No-ops unless something changed since the last call.
- **`Container:IsDirty()`** — Returns `true` if this node's tree has changed since its last `Layout()` call. Works from a container or a leaf.
- **`Container:GetChild(key)`** — Looks up a child anywhere in the tree by the `key` it was given. Works from the root or any nested container/leaf. Errors if no child was registered under `key`.
- **`Container:GetFrame()`** — Returns this node's frame. Works from a container or a leaf. `nil` if not resolved yet, e.g. a `frameFactory` not yet laid out.
- **`Container:IsContainer()`** — Returns `true` if this node is a container. Works from a container or a leaf.
- **`Container:Hide()`** — Takes this node out of the layout flow entirely, its siblings reflow to fill the space, and hides its own frame. Its position in the tree is preserved, `Show()` brings it back, no re-inserting needed. Works from a container or a leaf. No-ops if already hidden.
- **`Container:Show()`** — Reverses `Hide()`. Works from a container or a leaf. No-ops if not currently hidden.
- **`Container:SetWidth(width?)`** — Sets this node's own physical width. Works from a container or a leaf. Pass `nil` to let it flex/stretch instead (whichever applies), or `"AUTO"` to compute it from this node's own children (a sum along its main axis, a max along its cross axis). No-ops if already that value.
- **`Container:SetHeight(height?)`** — Sets this node's own physical height. Same as `SetWidth()` in every other respect, the vertical axis instead.
- **`Container:SetGap(gap?)`** — Sets the space between this container's children. Container-only. No-ops if already that gap.
- **`Container:SetPadding(padding?)`** — Sets the space between this container's edge and its children, on all four sides. Container-only. No-ops if already that padding.
- **`Container:SetAlign(align?)`** — Sets how this container aligns its own children along the cross axis by default. Container-only. Pass `nil` to reset to the default (`"STRETCH"`). No-ops if already that alignment.
- **`Container:SetAlignSelf(alignSelf?)`** — Sets how this node aligns itself within its parent along the cross axis, overriding the parent's own `align`. Works on any container or leaf. Pass `nil` to go back to inheriting it. No-ops if already that alignment.
- **`Container:SetJustify(justify?)`** — Sets how this container distributes leftover main-axis space among its own children. Container-only. Pass `nil` to reset to the default (`"START"`). No-ops if already that value.
- **`Container:SetWrap(wrap?)`** — Sets whether this container's overflowing children wrap onto a new line. Container-only. Pass `nil` to reset to the default (`false`). No-ops if already that value.
- **`Container:SetOrder(order?)`** — Sets this node's visual position among its siblings, independent of declaration order. Works on any container or leaf. Pass `nil` to reset to the default (`0`). No-ops if already that order.

## Testing

Waffle includes a test suite under `test/`, run against Lua 5.1:

```bash
./run-tests.sh
```

Tests run automatically via GitHub Actions on every push and pull request to `main`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a history of what's changed.
