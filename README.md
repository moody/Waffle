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

**Composing declaratively.** `Waffle:Flex(options)` positions `options.children` in a row or column within `options.parent`, and returns a container. Nothing runs until `Layout()` is called on it.

```lua
Waffle:Flex({
  parent = frame,
  width = 400,
  height = 300,
  children = {
    { frame = sidebar, size = 100 },
    { frame = content },
  }
}):Layout()
```

`direction` defaults to `"ROW"`. Children stretch to fill the cross axis. A child with `size` takes exactly that much space along the main axis; a child without one splits whatever's left over evenly with any other flexible siblings, here that's `content` getting the full 300 left after `sidebar`'s 100.

**Nesting.** A child with its own `children` becomes a nested container, laid out within its own resolved width/height once the parent knows it.

```lua
Waffle:Flex({
  parent = frame,
  width = 400,
  height = 300,
  direction = "COLUMN",
  children = {
    { frame = header, size = 40 },
    {
      frame = body,
      children = {
        { frame = sidebar, size = 100 },
        { frame = content },
      }
    },
  }
}):Layout()
```

**The fluent API.** The same tree, composed fluently instead of as one large nested table. `AddRow`/`AddColumn` append a nested container and return a new container scoped to it; `Layout()` only needs to be called once, on the root.

```lua
local root = Waffle:Flex({ parent = frame, width = 400, height = 300, direction = "COLUMN" })
root:AddChild({ frame = header, size = 40 })

local body = root:AddRow({ frame = CreateFrame("Frame") })
body:AddChild({ frame = sidebar, size = 100 })
body:AddChild({ frame = content })

root:Layout()
```

**Frame factory.** Give the root a `defaultFrameFactory` and any child that omits both `frame` and its own `frameFactory` gets one automatically, reaching every level of nesting. Handy for wrapper containers that don't need to be anything but a positioning box. It receives the frame's resolved parent as an argument.

```lua
local root = Waffle:Flex({
  parent = frame,
  width = 400,
  height = 300,
  direction = "COLUMN",
  defaultFrameFactory = function(parent) return CreateFrame("Frame", nil, parent) end
})
root:AddChild({ frame = header, size = 40 })

local body = root:AddRow() -- no frame given, defaultFrameFactory makes one
body:AddChild({ frame = sidebar, size = 100 })
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

**Reacting to resolved size.** `onLayout` fires with a child's own frame and its resolved width/height, right after they're assigned. Use it instead of `children` for anything beyond "just recurse."

```lua
root:AddChild({
  frame = content,
  onLayout = function(frame, width, height)
    frame.scrollChild:SetWidth(width)
  end
})
```

`onLayout` re-fires on every `Layout()` call, so keep it idempotent, safe to run again and again, not just once.

**Calling `Layout()` again.** Nothing about `Layout()` is one-time, it's a pure recompute of whatever's currently composed. Add another child with `AddChild`/`AddRow`/`AddColumn`, remove one with `RemoveChild()`/`Clear()`, hide or show one with `Hide()`/`Show()`, resize or respace one with `SetSize()`/`SetGap()`/`SetPadding()`, then call `Layout()` again on the same root container to bring the frames in line. A call is a no-op unless something changed since the last one, so it's cheap to call from an `OnUpdate` handler every frame.

**Looking up a child by key.** Give a child a `key` when adding it, and retrieve it later with `GetChild(key)`, from the root container or from any other container or leaf in the tree, they all share the same lookup. An unregistered key throws an error; a duplicate key doesn't, the first match found wins. Keep your keys unique!

```lua
root:AddChild({ frame = content, key = "content" })

-- from anywhere else with a reference into this tree:
local contentLeaf = root:GetChild("content")
```

**Hiding and showing a child.** `Hide()` takes a child out of the layout flow entirely, its siblings reflow to fill the space. `Show()` brings it back. Its position in the tree is preserved either way, no re-inserting needed.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, size = 100 })

sidebarLeaf:Hide()
root:Layout() -- content now gets the full width, sidebar's frame is hidden

sidebarLeaf:Show()
root:Layout() -- sidebar is back, content shrinks to make room again
```

`hidden = true` can also be given up front, declaratively, instead of calling `Hide()` after the fact.

**Removing a child.** `RemoveChild(child)` detaches a child from the tree entirely, not just excluding it from layout the way `Hide()` does, returning whether it was actually found and removed. `Clear()` removes every child at once. Neither touches the removed child's own frame, only Waffle's own tracking of it.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, size = 100 })

root:RemoveChild(sidebarLeaf)
root:Layout() -- content gets the full width, sidebar's frame is untouched

root:Clear()
root:Layout() -- root has no children left at all
```

**Mutating size, gap, and padding.** `SetSize()` works on any container or leaf; `SetGap()`/`SetPadding()` only make sense on a container, since only a container has children to space out. All three no-op if given the same value they already have.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, size = 100 })

sidebarLeaf:SetSize(150) -- sidebar grows, content shrinks to make room
root:Layout()

root:SetGap(20) -- more space between the root's own children
root:Layout()
```

**Reordering a child.** `order` controls visual position among siblings, independent of the order they were declared or added in. Defaults to `0`; siblings with equal `order` keep their declaration order. Works on any container or leaf.

```lua
local sidebarLeaf = root:AddChild({ frame = sidebar, size = 100 }) -- added first
root:AddChild({ frame = content })

sidebarLeaf:SetOrder(1) -- moves after content, despite being added first
root:Layout()
```

`order` can also be given up front, declaratively, instead of calling `SetOrder()` after the fact.

## API

- **`Waffle:Flex(options)`** — Starts composing a container, returns a `WaffleFlexComponentContainer`. `options.children` can be given directly for a fully declarative style. Nothing runs until `Layout()` is called.
- **`Container:AddChild(child)`** — Appends a child as-is, a leaf frame or a manually composed subtree via its own `children`/`onLayout`. Returns its leaf.
- **`Container:AddRow(child?)`** / **`Container:AddColumn(child?)`** — Appends a new ROW/COLUMN container as a child, returning a new container scoped to it.
- **`Container:RemoveChild(child)`** — Removes `child` from this container's own children entirely, detaching it (and its own children, if it's itself a container) from the tree rather than just excluding it from layout. Doesn't touch `child`'s own frame. Container-only. Returns `true` if `child` was actually found and removed.
- **`Container:Clear()`** — Removes every child from this container, same as calling `RemoveChild` on each one. Container-only. No-ops if already empty.
- **`Container:Layout()`** — Runs the layout for everything composed so far. Call only on the root container, nested containers are laid out automatically as part of it. Safe to call again later; no-ops unless something changed since the last call.
- **`Container:GetChild(key)`** — Looks up a child anywhere in the tree by the `key` it was given. Works from the root or any nested container/leaf. Errors if no child was registered under `key`.
- **`Container:GetFrame()`** — Returns this node's own frame. Works from a container or a leaf. `nil` if not resolved yet, e.g. a `frameFactory` that hasn't been laid out for the first time.
- **`Container:Hide()`** — Takes this node out of the layout flow entirely, its siblings reflow to fill the space. Works from a container or a leaf. No-ops if already hidden.
- **`Container:Show()`** — Reverses `Hide()`. Works from a container or a leaf. No-ops if not currently hidden.
- **`Container:SetSize(size?)`** — Sets the fixed size this node takes up within its own parent. Works from a container or a leaf. Pass `nil` to remove a fixed size and let it flex again. No-ops if already that size.
- **`Container:SetGap(gap?)`** — Sets the space between this container's own children. Container-only. No-ops if already that gap.
- **`Container:SetPadding(padding?)`** — Sets the space between this container's edge and its children, on all four sides. Container-only. No-ops if already that padding.
- **`Container:SetOrder(order?)`** — Sets this node's visual position among its siblings, independent of declaration order. Works on any container or leaf. Pass `nil` to reset to the default (`0`). No-ops if already that order.

The options (`WaffleFlexNodeParent`) passed to `Waffle:Flex()` accept:

- **`parent`** — The frame `children` are positioned within.
- **`width`** / **`height`** — The container's available size.
- **`children`** — Can be given directly for a fully declarative style, instead of `AddChild`/`AddRow`/`AddColumn`.
- **`direction`** — `"ROW"` or `"COLUMN"`. Defaults to `"ROW"`.
- **`gap`** / **`padding`** — Space between/around children. Can also be toggled after the fact with `SetGap()`/`SetPadding()`.
- **`defaultFrameFactory`** — Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`. Reaches every level, receives the resolved parent as an argument.

A child (`WaffleFlexNodeChild`), whether given via `options.children` or `AddChild`/`AddRow`/`AddColumn`, accepts the same `direction`, `gap`, and `padding` as above (they apply to the nested container this child becomes), plus:

- **`frame`** — An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
- **`frameFactory`** — Creates this child's own frame, once. Receives the resolved parent as an argument. Cannot be given together with `frame`.
- **`hidden`** — Excludes this child from the layout flow entirely. Can also be toggled after the fact with `Hide()`/`Show()`.
- **`key`** — Registers this child for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key isn't validated against, the first match found wins.
- **`order`** — Visual position among siblings, independent of declaration order. Defaults to `0`; siblings with equal `order` keep their declaration order. Can also be toggled after the fact with `SetOrder()`.
- **`size`** — Fixed size along the main axis. Omitted children split the remaining space evenly. Can also be toggled after the fact with `SetSize()`.
- **`onLayout`** — Called with this child's frame and resolved width/height, once assigned.

## Testing

Waffle includes a test suite under `test/`, run against Lua 5.1:

```bash
./run-tests.sh
```

Tests run automatically via GitHub Actions on every push and pull request to `main`.
