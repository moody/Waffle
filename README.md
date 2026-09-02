# Waffle 🧇

**W**oW **A**ddon **F**lexible **F**rame **L**ayout **E**ngine

Waffle is a flex layout library for World of Warcraft addons, inspired by [CSS Flexbox](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout/Basic_concepts_of_flexbox).

## Features

- Row/column flex layout with fixed and flexible sizing, gap, and padding, no manual `SetPoint` math
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

**Composing declaratively.** `Waffle:Flex(options)` positions `options.children` in a row or column within `options.frame`, and returns a container. Nothing runs until `Layout()` is called on it.

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

`direction` defaults to `"ROW"`. A node's own physical `width`/`height` always mean the same thing regardless of `direction`: whichever one is this node's own main axis within its parent (`width` for a ROW parent, `height` for a COLUMN one) takes exactly that much space along it, splitting whatever's left over evenly with any other flexible siblings that omit theirs; here that's `content` getting the full 300 left after `sidebar`'s 100. The other one is this node's cross-axis size, see alignment below.

**Aligning children on the cross axis.** `align`, set on a container, controls how it aligns its own children along the cross axis: `"STRETCH"` (the default, fills it), `"START"`, `"CENTER"`, or `"END"`. Any child can override it for itself with its own `alignSelf`. Alignment other than `STRETCH` requires that child's own cross-axis dimension (`height`, for a ROW parent), it isn't derived from anything, so give one or expect an error:

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

**Distributing leftover main-axis space.** `justify`, also set on a container, controls how it spreads out leftover main-axis space among its children, when there is any: `"START"` (the default, unchanged), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only matters when nothing is flexible, a flexible child already consumes all the leftover space, leaving nothing for `justify` to distribute:

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

The root is a node like any other: `frame`, `frameFactory`, `key`, `hidden`, and `onLayout` all work the same way they do for a child, and a root's own `frameFactory` just has no parent to receive as an argument, since nothing sits above it. The one real difference is `width`/`height`: an ordinary child only needs its own main-axis dimension, its parent supplies the cross axis; the root has no parent to supply anything, so it needs both, given directly or computed via `"AUTO"` (only legal along its own main axis, given its own `direction`).

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

**Frame factory.** Give a node a `defaultFrameFactory` and any descendant below it that omits both `frame` and its own `frameFactory` gets one automatically, reaching every level of nesting below that point. Handy for wrapper containers that don't need to be anything but a positioning box. It receives the frame's resolved parent as an argument.

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

A child can also provide its own `frameFactory` instead of `frame`, for building content inline. Scoped to that child only, its own nested children still fall back to `defaultFrameFactory`. Here, `parent` matters for `$parent` name substitution: `CreateFrame` resolves `$parent` into the parent's actual name at creation time, which only works if the real parent is passed in immediately rather than reparented later:

```lua
root:AddChild({
  frameFactory = function(parent)
    local card = CreateFrame("Frame", "$parent_Card", parent)
    card.text = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.text:SetText("Hello")
    return card
  end
})
```

**Reacting to resolved size.** `onLayout` fires with a child's own frame and its resolved width/height, after its `children` (if any) are laid out. Use it for anything a plain `children` tree cannot express on its own.

```lua
root:AddChild({
  frame = content,
  onLayout = function(frame, width, height)
    frame.scrollChild:SetWidth(width)
  end
})
```

`onLayout` re-fires on every `Layout()` call, so keep it idempotent, safe to run again and again, not just once.

**Calling `Layout()` again.** Nothing about `Layout()` is one-time, it's a pure recompute of whatever's currently composed. Add another child with `AddChild`/`AddRow`/`AddColumn`, remove one with `RemoveChild()`/`Clear()`, hide or show one with `Hide()`/`Show()`, resize or respace one with `SetWidth()`/`SetHeight()`/`SetGap()`/`SetPadding()`, then call `Layout()` again to bring the frames in line, from any node in the tree, not just the root, it always resolves and lays out the whole tree from its actual current root. A call is a no-op unless something changed since the last one, so it's cheap to call from an `OnUpdate` handler every frame. `IsDirty()` tells you whether a call would actually do anything, without triggering one.

**Looking up a child by key.** Give a child a `key` when adding it, and retrieve it later with `GetChild(key)`, from the root container or from any other container or leaf in the tree, they all share the same lookup. An unregistered key throws an error; a duplicate key doesn't, the first match found wins. Keep your keys unique!

```lua
root:AddChild({ frame = content, key = "content" })

-- from anywhere else with a reference into this tree:
local contentLeaf = root:GetChild("content")
```

**Hiding and showing a child.** `Hide()` takes a child out of the layout flow entirely, its siblings reflow to fill the space. `Show()` brings it back. Its position in the tree is preserved either way, no re-inserting needed.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, width = 100 })

sidebarLeaf:Hide()
root:Layout() -- content now gets the full width, sidebar's frame is hidden

sidebarLeaf:Show()
root:Layout() -- sidebar is back, content shrinks to make room again
```

`hidden = true` can also be given up front, declaratively, instead of calling `Hide()` after the fact.

**Getting a frame back, walking a container's children, and telling them apart.** `GetFrame()` returns a node's frame, `nil` if it hasn't been resolved yet (a `frameFactory` not yet laid out). `GetChildren()` returns every one of a container's direct children, wrapped, in declaration order, without recursing into grandchildren. `IsContainer()` tells you which kind of node you're holding. Useful together for walking a tree and handling each child differently, e.g. recursing into containers while pooling leaf frames before `Clear()` discards them:

```lua
for _, child in ipairs(root:GetChildren()) do
  if child:IsContainer() then
    --- @cast child WaffleFlexComponentContainer
    -- recurse, e.g. walk child:GetChildren() the same way
  else
    local frame = child:GetFrame()
    if frame then pool:Release(frame) end
  end
end
root:Clear()
```

**Removing a child.** `RemoveChild(child)` detaches a child from the tree entirely, not excluding it from layout the way `Hide()` does, returning whether it was actually found and removed. `Clear()` removes every child at once. Neither touches the removed child's own frame, only Waffle's own tracking of it.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, width = 100 })

root:RemoveChild(sidebarLeaf)
root:Layout() -- content gets the full width, sidebar's frame is untouched

root:Clear()
root:Layout() -- root has no children left at all
```

**Moving a child to a different container.** A node can only belong to one container's children at a time, whether it got there through `AddChild()`/`AddRow()`/`AddColumn()` or was just written directly into a `children` table. Adding a node that's still attached elsewhere throws. `RemoveChild()` it from its current container first, then add it wherever it goes next, even a completely different `Waffle:Flex()` tree, it reparents cleanly.

```lua
local sidebarOptions = { frame = sidebar, width = 100 }
local sidebarLeaf = leftPanel:AddChild(sidebarOptions)
leftPanel:Layout()

leftPanel:RemoveChild(sidebarLeaf)
rightPanel:AddChild(sidebarOptions) -- moved into a different tree entirely
rightPanel:Layout()
```

**Mutating width, height, gap, and padding.** `SetWidth()`/`SetHeight()` work on any container or leaf; `SetGap()`/`SetPadding()` only make sense on a container, since only a container has children to space out. All four no-op if given the same value they already have.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, width = 100 })

sidebarLeaf:SetWidth(150) -- sidebar grows along the main axis, content shrinks to make room
root:Layout()

sidebarLeaf:SetHeight(40) -- sidebar stops stretching along the cross axis, sized to 40 instead
root:Layout()

root:SetGap(20) -- more space between the root's own children
root:Layout()
```

**Reordering a child.** `order` controls visual position among siblings, independent of the order they were declared or added in. Defaults to `0`; siblings with equal `order` keep their declaration order. Works on any container or leaf.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, width = 100 }) -- added first
root:AddChild({ frame = content })

sidebarLeaf:SetOrder(1) -- moves after content, despite being added first
root:Layout()
```

`order` can also be given up front, declaratively, instead of calling `SetOrder()` after the fact.

## API

- **`Waffle:Flex(options)`** — Starts composing a container, returns a `WaffleFlexComponentContainer`. `options.children` can be given directly for a fully declarative style. Nothing runs until `Layout()` is called.
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
- **`Container:Hide()`** — Takes this node out of the layout flow entirely, its siblings reflow to fill the space, and hides its own frame. Works from a container or a leaf. No-ops if already hidden.
- **`Container:Show()`** — Reverses `Hide()`. Works from a container or a leaf. No-ops if not currently hidden.
- **`Container:SetWidth(width?)`** — Sets this node's own physical width. Works from a container or a leaf. Pass `nil` to let it flex/stretch instead (whichever applies), or `"AUTO"` to compute it from this node's own children (only legal when `width` is this node's own main axis, given its own `direction`). No-ops if already that value.
- **`Container:SetHeight(height?)`** — Sets this node's own physical height. Same as `SetWidth()` in every other respect, the vertical axis instead.
- **`Container:SetGap(gap?)`** — Sets the space between this container's children. Container-only. No-ops if already that gap.
- **`Container:SetPadding(padding?)`** — Sets the space between this container's edge and its children, on all four sides. Container-only. No-ops if already that padding.
- **`Container:SetAlign(align?)`** — Sets how this container aligns its own children along the cross axis by default. Container-only. Pass `nil` to reset to the default (`"STRETCH"`). No-ops if already that alignment.
- **`Container:SetAlignSelf(alignSelf?)`** — Sets how this node aligns itself within its parent along the cross axis, overriding the parent's own `align`. Works on any container or leaf. Pass `nil` to go back to inheriting it. No-ops if already that alignment.
- **`Container:SetJustify(justify?)`** — Sets how this container distributes leftover main-axis space among its own children. Container-only. Pass `nil` to reset to the default (`"START"`). No-ops if already that value.
- **`Container:SetOrder(order?)`** — Sets this node's visual position among its siblings, independent of declaration order. Works on any container or leaf. Pass `nil` to reset to the default (`0`). No-ops if already that order.

A child (`WaffleFlexNode`), whether given via `options.children` or `AddChild`/`AddRow`/`AddColumn`, accepts:

- **`frame`** — An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
- **`frameFactory`** — Creates this child's own frame, once. Receives the resolved parent as an argument. Cannot be given together with `frame`.
- **`direction`** — `"ROW"` or `"COLUMN"`. Defaults to `"ROW"`. Applies to the nested container this child becomes, if it has `children`.
- **`gap`** / **`padding`** — Space between/around this child's children, if it has any. Can also be toggled after the fact with `SetGap()`/`SetPadding()`.
- **`align`** — How this child aligns its own children along the cross axis, if it has any: `"STRETCH"` (default), `"START"`, `"CENTER"`, or `"END"`. Overridden per-child by that child's own `alignSelf`. Can also be toggled after the fact with `SetAlign()`.
- **`alignSelf`** — Overrides the parent's `align` for this child specifically. Requires this child's own cross-axis dimension if not `"STRETCH"`. Can also be toggled after the fact with `SetAlignSelf()`.
- **`justify`** — How this child distributes leftover main-axis space among its own children, if it has any: `"START"` (default), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only matters when none of those children are flexible. Can also be toggled after the fact with `SetJustify()`.
- **`children`** — Can be given directly for a fully declarative style, instead of `AddChild`/`AddRow`/`AddColumn`.
- **`hidden`** — Excludes this child from the layout flow entirely. Can also be toggled after the fact with `Hide()`/`Show()`.
- **`key`** — Registers this child for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key isn't validated against, the first match found wins.
- **`order`** — Visual position among siblings, independent of declaration order. Defaults to `0`; siblings with equal `order` keep their declaration order. Can also be toggled after the fact with `SetOrder()`.
- **`width`** — This node's own physical width, always horizontal, regardless of `direction`. Used directly as a fixed size, whether that's this node's own main-axis size within its parent (a ROW parent) or its cross-axis size (a COLUMN parent; required if resolved to a non-`STRETCH` alignment there, ignored, falling back to stretching, when `STRETCH`). Omitted, flexes/stretches instead, whichever applies. `"AUTO"` computes it as the sum of this node's own children's own `width` (plus `gap`/`padding`), only legal when `width` is this node's own main axis (`direction` is `ROW`); every visible child needs its own number or `"AUTO"`, a flexible child errors, there's no space yet to split. Can also be toggled after the fact with `SetWidth()`.
- **`height`** — This node's own physical height, always vertical. Same as `width` in every other respect; `"AUTO"` only legal when `direction` is `COLUMN`. Can also be toggled after the fact with `SetHeight()`.
- **`onLayout`** — Called with this child's frame and resolved width/height, after its `children` (if any) are laid out.
- **`defaultFrameFactory`** — Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`. Does not apply to this node; even the tree's actual root needs its own `frame`/`frameFactory`, nothing above it to inherit a fallback from.

The root passed to `Waffle:Flex()` is a node like any other, no separate type, `width`/`height` included. `alignSelf`/`order` have no effect there, there's nothing above the root to align or reorder among siblings; everything else, `align`/`justify`/`hidden`/`onLayout`/`defaultFrameFactory` included, still applies, same as for any child, `align`/`justify` in particular work exactly the same as they do anywhere else, since both are about how a node treats its own children, not how it's treated by a parent. The one real difference: an ordinary child only needs its own main-axis dimension, its parent supplies the cross axis; the root has no parent to supply anything, so it needs both `width` and `height` given, one of them as `"AUTO"` if that's its own main axis.

## Testing

Waffle includes a test suite under `test/`, run against Lua 5.1:

```bash
./run-tests.sh
```

Tests run automatically via GitHub Actions on every push and pull request to `main`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a history of what's changed.
