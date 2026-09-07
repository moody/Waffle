# Waffle 🧇 (0.7.0)

**W**oW **A**ddon **F**lexible **F**rame **L**ayout **E**ngine

Waffle is a flex layout library for World of Warcraft addons, inspired by [CSS Flexbox](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout/Basic_concepts_of_flexbox).

## Features

- Row/column flex layout, plus reversed variants of each, with fixed and flexible sizing, gap, and padding, no manual `SetPoint` math
- Shrink-to-fit sizing (`width`/`height` accepting `"AUTO"`), so a container can size itself from its own children instead of a fixed number
- Percentage sizing (`width`/`height` accepting `"50%"`), sized relative to the parent instead of a fixed number
- Wrapping (`wrap`), so children that would overflow the main axis start a new line instead, each line sized and aligned independently
- Independent line spacing (`lineGap`), so wrapped lines can be spaced apart differently than the children within each one
- Weighted growth (`grow`), so a flexible child can claim a bigger or smaller share of leftover space than its equally-flexible siblings
- Weighted shrinking (`shrink`), so overflowing children give up a bigger or smaller share of the deficit than their equally-shrinkable siblings, instead of overflowing
- Size floors and ceilings (`minWidth`/`maxWidth`/`minHeight`/`maxHeight`), so a flexible child's share of leftover space never shrinks below or grows past a bound you set
- Per-side padding (`paddingTop`/`paddingRight`/`paddingBottom`/`paddingLeft`), overriding the uniform `padding` on whichever sides you need to differ
- Per-child margin (`margin`/`marginTop`/`marginRight`/`marginBottom`/`marginLeft`), so one child can get extra space around it beyond the container's own `gap`
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

**Percentage sizing.** `width`/`height` also accept a percentage string like `"50%"` instead of a fixed number, sized relative to the parent's own width/height (after its own padding) instead. Errors without a parent whose own size is already resolved: the root, or a parent whose own main axis is itself still being computed from `"AUTO"`. Has no effect on `minWidth`/`maxWidth`, same as any other fixed size.

```lua
Waffle:Flex({
  frame = frame,
  width = 300,
  height = 40,
  children = {
    { frame = sidebar, width = "30%" }, -- 90, thirty percent of 300
    { frame = content },                -- takes the rest: 210
  }
}):Layout()
```

**Per-side padding.** `padding` applies to all four sides by default; `paddingTop`/`paddingRight`/`paddingBottom`/`paddingLeft` each override it for one side only, any side left unset still falls back to `padding`. `"AUTO"` sizing on either axis sums in whichever pair of sides applies there:

```lua
Waffle:Flex({
  frame = frame,
  width = 400,
  height = 100,
  padding = 10,
  paddingBottom = 30, -- taller gap below the content than the other three sides
  children = {
    { frame = content },
  }
}):Layout()
```

**Per-child margin.** `margin`/`marginTop`/`marginRight`/`marginBottom`/`marginLeft` work the same way as `padding`'s own shorthand and per-side overrides, but on the node itself rather than a container's edge, and independent of the container's own `gap`. On the main axis it adds to the space this node consumes, coming out of a flexible sibling's own share; on the cross axis it insets a `STRETCH`-ed size, or shifts a `CENTER`/`END`-aligned one:

```lua
Waffle:Flex({
  frame = frame,
  width = 300,
  height = 40,
  children = {
    { frame = icon, width = 40, marginRight = 12 }, -- extra gap after just this child
    { frame = label },
  }
}):Layout()
```

**Weighting flexible children.** `grow` gives a flexible child a bigger or smaller share of the leftover main-axis space than its equally-flexible siblings, instead of the default even split. A child with `grow = 2` gets twice as much of the leftover space as a sibling left at the default (`1`); `grow = 0` claims none of it. Has no effect on a child with its own explicit `width`/`height`, only a flexible child has any leftover space to share in the first place:

```lua
Waffle:Flex({
  frame = frame,
  width = 300,
  height = 40,
  children = {
    { frame = sidebar },            -- grow 1 (default), gets 100
    { frame = content, grow = 2 },  -- gets 200, twice sidebar's share
  }
}):Layout()
```

**Shrinking overflowing children.** `shrink` is `grow`'s complement: when children's own sizes together overflow the main axis, `shrink` gives an overflowing child a bigger or smaller share of that deficit than its equally-shrinkable siblings, weighted by each one's own size as well as `shrink`, instead of everything just overflowing. `shrink = 0` never gives up any of a child's own stated size; `minWidth`/`minHeight` floors how far any child shrinks, the same way it already floors a flexible child's own share:

```lua
Waffle:Flex({
  frame = frame,
  width = 200,
  height = 40,
  children = {
    { frame = icon, width = 150 },   -- shrinks to 120, the bigger share
    { frame = label, width = 100 },  -- shrinks to 80
  }
}):Layout()
```

**Constraining flexible children.** `minWidth`/`maxWidth` put a floor or ceiling on a node's own flexible size, a plain number rather than anything relative; `minHeight`/`maxHeight` do the same for the vertical axis. On a node's main axis, that's its flexible share of leftover space, and whatever a clamped child doesn't claim goes to its still-flexible siblings instead. On its cross axis, that's a `STRETCH`-ed size instead, clamped independently of any sibling. Has no effect on a child with its own explicit `width`/`height`, or under non-`STRETCH` alignment, both already have their own explicit cross size with nothing left to clamp:

```lua
Waffle:Flex({
  frame = frame,
  width = 300,
  height = 40,
  children = {
    { frame = sidebar, maxWidth = 80 },  -- would be 150 at an even split, capped to 80
    { frame = content },                 -- takes the rest: 220
  }
}):Layout()
```

**Distributing leftover main-axis space.** `justify`, set on a container, controls how it spreads out leftover main-axis space among its children, when there is any: `"START"` (the default, unchanged), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only matters when nothing has a positive `grow` share, something already claims the leftover space, leaving nothing for `justify` to distribute. A `minWidth`/`maxWidth` clamp counts too: if every flexible child on a line ends up clamped, whatever's still unclaimed goes to `justify` the same as if nothing on that line were flexible at all:

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

**Line gap.** `lineGap`, set on a container, spaces wrapped lines apart independently of `gap` between the children within each one. Falls back to `gap` when unset, same as before this field existed:

```lua
Waffle:Flex({
  frame = frame,
  width = 100,
  height = 200,
  wrap = true,
  gap = 8,      -- between icons on the same line
  lineGap = 24, -- between the two lines themselves
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

**Attaching an existing component.** `AttachComponent` grafts an already-composed component, built independently with its own `Waffle:Flex()` call, into another container's children as-is. Its own direction, size, and structure carry over unchanged, unlike `AddRow`/`AddColumn`, which force a fresh node's direction. Useful for composing a widget's own tree separately, then joining it into a caller's tree once it's ready:

```lua
local sidebar = Waffle:Flex({ frame = sidebarFrame, direction = "COLUMN", width = 100, height = 300 })
sidebar:AddChild({ frame = sidebarHeader, height = 40 })
sidebar:AddChild({ frame = sidebarBody })

local root = Waffle:Flex({ frame = frame, width = 400, height = 300, direction = "ROW" })
root:AttachComponent(sidebar)
root:AddChild({ frame = content })

root:Layout()
```

**Detaching a specific child.** `DetachComponent` removes a specific child from this container, validating that it's actually attached here first: it only succeeds if `component` really is one of this container's own children, returning `false` instead of detaching it from wherever it actually is otherwise. Useful when an operation depends on that assumption being true, not just on getting the component out of the tree:

```lua
local root = Waffle:Flex({ frame = frame, width = 400, height = 300, direction = "ROW" })
local sidebar = root:AddChild({ frame = sidebarFrame, width = 100 })
root:AddChild({ frame = content })
root:Layout()

root:DetachComponent(sidebar) -- true, sidebar really is root's own child
```

**Detaching a component.** `Detach()` removes a component from its current owner, wherever that owner actually is, without needing to already hold it. Always returns the same component, whether or not it actually had an owner to release, so it composes directly into a single call that moves it straight into a different tree:

```lua
local root = Waffle:Flex({ frame = frame, width = 400, height = 300, direction = "ROW" })
root:AddChild({ frame = sidebarFrame, key = "sidebar", width = 100 })
root:AddChild({ frame = content })
root:Layout()

-- Later, move the sidebar into a different tree entirely:
local otherRoot = Waffle:Flex({ frame = otherFrame, width = 400, height = 300, direction = "ROW" })
otherRoot:AttachComponent(root:GetChild("sidebar"):Detach())
otherRoot:Layout()
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

**Reacting to resolved size.** `onLayout` fires with this node's own component, already wrapped, and its resolved width/height, once the whole `Layout()` pass is resolved and clean, not while it's still running. Useful for anything Waffle doesn't handle automatically, like keeping a `ScrollFrame`'s scroll child in sync (WoW doesn't resize it to fit the visible area on its own) or reacting to what was just resolved by adjusting a sibling, since the component works the same as any other and reaches anywhere else in the tree with `GetChild`. Mutating a different node from here is safe, it schedules a future `Layout()` call the same as calling a setter from anywhere else:

```lua
root:AddChild({
  frame = scrollFrame,
  onLayout = function(component, width, height)
    local frame = component:GetFrame()
    frame.scrollChild:SetWidth(width)
    local slider = component:GetChild("slider")
    if frame.scrollChild:GetHeight() > height then slider:Show() else slider:Hide() end
  end
})
root:AddChild({ frame = sliderFrame, key = "slider", width = 20 })
```

`onLayout` re-fires on every `Layout()` call, so keep it idempotent, safe to run again and again, not just once. Every node's own `onLayout` fires bottom-up: children before parents, root last.

**Calling `Layout()` again.** Nothing about `Layout()` is one-time, it's a pure recompute of whatever's currently composed. Call it again any time state changes, from any node in the tree, not just the root, it always resolves and lays out the whole tree from its actual current root. A call is a no-op unless something changed since the last one, so it's cheap to call from an `OnUpdate` handler every frame. `IsDirty()` tells you whether a call would actually do anything, without triggering one.

## API

### `Waffle:Flex(node)`

Starts composing a container and returns it. `node` is the root of the tree, the same shape as any other node, except it has no parent to supply a cross axis: it needs both `width` and `height` given, each directly or as `"AUTO"`. `node.children` can be given directly for a fully declarative style. Nothing runs until `Layout()` is called.

### Node

Every node in the tree, whether it's the one passed to `Waffle:Flex()` or a child added via `AddChild`/`AddRow`/`AddColumn`/`children`, shares the same shape, `WaffleFlexNode`:

- **`frame`** — An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
- **`frameFactory`** — Creates this node's own frame, once. Receives the resolved parent as an argument. Cannot be given together with `frame`. If it uses `$parent` name substitution, the parent must be passed in immediately here, not reparented later, substitution happens at creation time.
- **`direction`** — `"ROW"`, `"COLUMN"`, `"ROW_REVERSE"`, or `"COLUMN_REVERSE"`. Defaults to `"ROW"`. Applies to this node's own children, if it has any. The `_REVERSE` variants keep the same main axis, just flip which edge is main-start; `order` still sorts first. Can also be toggled after the fact with `SetDirection()`.
- **`gap`** / **`padding`** — Space between/around this node's own children, if it has any. Can also be toggled after the fact with `SetGap()`/`SetPadding()`.
- **`paddingTop`** / **`paddingRight`** / **`paddingBottom`** / **`paddingLeft`** — Overrides `padding` for that one side. Falls back to `padding` for any side not given. Can also be toggled after the fact with `SetPaddingTop()`/`SetPaddingRight()`/`SetPaddingBottom()`/`SetPaddingLeft()`.
- **`align`** — How this node aligns its own children along the cross axis, if it has any: `"STRETCH"` (default), `"START"`, `"CENTER"`, or `"END"`. Overridden per-child by that child's own `alignSelf`. Can also be toggled after the fact with `SetAlign()`.
- **`alignSelf`** — Overrides the parent's `align` for this node specifically. Requires this node's own cross-axis dimension if not `"STRETCH"`. No effect on the root, nothing above it to align it within. Can also be toggled after the fact with `SetAlignSelf()`.
- **`justify`** — How this node distributes leftover main-axis space among its own children, if it has any: `"START"` (default), `"CENTER"`, `"END"`, `"SPACE_BETWEEN"`, `"SPACE_AROUND"`, or `"SPACE_EVENLY"`. Only matters when none of those children have a positive `grow` share. Can also be toggled after the fact with `SetJustify()`.
- **`grow`** — This node's own share of its parent's leftover main-axis space, relative to its equally-flexible siblings. Defaults to `1`. No effect on a node with its own explicit main-axis `width`/`height`, or on the root. Can also be toggled after the fact with `SetGrow()`.
- **`shrink`** — This node's own share of its parent's main-axis deficit, when its siblings' own sizes don't all fit, weighted by this value times this node's own main-axis size, not the value alone. Defaults to `1`. No effect on a flexible node (nothing stated to reduce), or on the root. Can also be toggled after the fact with `SetShrink()`.
- **`minWidth`** / **`maxWidth`** — A floor/ceiling on this node's own `width`: its flexible main-axis share, if `width` is main; a `STRETCH`-ed cross-axis size, if cross. No effect on an explicit `width`, `"AUTO"`, or non-`STRETCH` alignment. Errors if `minWidth` is greater than `maxWidth`. Can also be toggled after the fact with `SetMinWidth()`/`SetMaxWidth()`.
- **`minHeight`** / **`maxHeight`** — Same as `minWidth`/`maxWidth`, for `height`. Can also be toggled after the fact with `SetMinHeight()`/`SetMaxHeight()`.
- **`wrap`** — Overflowing children start a new line instead of continuing past the main axis size. Each line gets its own cross-size (a max over its own children) and stacks after the previous one, `lineGap` between lines too. Default `false`. Can also be toggled after the fact with `SetWrap()`.
- **`lineGap`** — Space between wrapped lines only, instead of `gap`. Falls back to `gap` when unset. No effect unless `wrap` actually produces more than one line. Can also be toggled after the fact with `SetLineGap()`.
- **`children`** — Can be given directly for a fully declarative style, instead of `AddChild`/`AddRow`/`AddColumn`; a node written directly into this table is still tracked and protected against double-attachment the same way.
- **`hidden`** — Excludes this node from the layout flow entirely. Can also be toggled after the fact with `Hide()`/`Show()`.
- **`key`** — Registers this node for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key isn't validated against, the first match found wins.
- **`order`** — Visual position among siblings, independent of declaration order. Defaults to `0`; siblings with equal `order` keep their declaration order. No effect on the root, nothing above it to reorder it among. Can also be toggled after the fact with `SetOrder()`.
- **`margin`** — Space around this node itself, on all four sides, independent of the container's own `gap`. Defaults to `0`. Can also be toggled after the fact with `SetMargin()`.
- **`marginTop`** / **`marginRight`** / **`marginBottom`** / **`marginLeft`** — Overrides `margin` for that one side. Falls back to `margin` for any side not given. Can also be toggled after the fact with `SetMarginTop()`/`SetMarginRight()`/`SetMarginBottom()`/`SetMarginLeft()`.
- **`width`** — This node's own physical width, always horizontal, regardless of `direction`. Used directly as a fixed size, whether that's this node's own main-axis size within its parent (a ROW parent) or its cross-axis size (a COLUMN parent; required if resolved to a non-`STRETCH` alignment there, ignored, falling back to stretching, when `STRETCH`). Omitted, flexes/stretches instead, whichever applies. `"AUTO"` computes it from this node's own children instead: a sum of their own `width` (plus `gap`/`padding`) along this node's own main axis (`direction` is `ROW`), or a max of them (plus `padding`) along its cross axis; every visible child needs its own number or `"AUTO"`, a flexible child errors. A percentage string (`"50%"`) sizes it relative to the parent's own width instead, erroring without one already resolved (the root, or a parent whose own width is itself still being computed from `"AUTO"`). Can also be toggled after the fact with `SetWidth()`.
- **`height`** — This node's own physical height, always vertical. Same as `width` in every other respect, `"AUTO"` sums along the main axis when `direction` is `COLUMN`, maxes along the cross axis otherwise, a percentage sizes it relative to the parent's own height. Can also be toggled after the fact with `SetHeight()`.
- **`onLayout`** — Called with this node's own component and resolved width/height, once the whole `Layout()` pass is resolved and clean. Re-fires on every `Layout()` call, keep it idempotent. Mutating a different node from here schedules a future `Layout()` call, the same as any other setter. Can also be toggled after the fact with `SetOnLayout()`.
- **`defaultFrameFactory`** — Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`. Does not apply to this node; even the tree's actual root needs its own `frame`/`frameFactory`, nothing above it to inherit a fallback from.

### Component

Every component, whether returned by `Waffle:Flex()`, `AddChild`, `AddRow`, `AddColumn`, `AttachComponent`, `Detach`, `GetChild`, or `GetChildren`, shares the same shape, `WaffleFlexComponent`. Whether a node has children is a fact about it, not a fixed type, so every method below works the same regardless of whether the node it's called on currently has any.

#### Tree composition

- **`Component:AddChild(node)`** — Appends `node` as a child as-is, returning its own component. Errors if `node` already belongs to a different component, call `DetachComponent()` on that one first to move it here. No-ops if `node` is already this node's own.
- **`Component:AddRow(node?)`** / **`Component:AddColumn(node?)`** — Appends a new ROW/COLUMN child, returning a new component scoped to it. Errors if `node` already belongs to a different component, call `DetachComponent()` on that one first to move it here. No-ops if `node` is already this node's own.
- **`Component:AttachComponent(component)`** — Grafts an already-composed component into this node's children, as-is: its own direction, size, and structure are unchanged, unlike `AddRow`/`AddColumn`. Errors if `component` already belongs to a different one, call `DetachComponent()` on that one first to move it here. No-ops if `component` is already this node's own.
- **`Component:Detach()`** — Detaches this component from its current owner, if it has one, the same as calling `DetachComponent()` on that owner. Always returns itself, whether or not it actually had an owner to release.
- **`Component:DetachComponent(component)`** — Removes `component` from this node's own children entirely, detaching it (and its own children, if it has any) from the tree rather than excluding it from layout the way `Hide()` does. Doesn't touch `component`'s own frame. Returns `true` if `component` was actually found and detached.
- **`Component:Clear()`** — Removes every child from this node, same as calling `DetachComponent` on each one. No-ops if already empty.

#### Layout

- **`Component:Layout()`** — Runs the layout for the tree containing this node, starting from its actual current root. Works from any node in the tree, not just the root. No-ops unless something changed since the last call.

#### Queries

- **`Component:GetChild(key)`** — Looks up a child anywhere in the tree by the `key` it was given. Errors if no child was registered under `key`.
- **`Component:GetChildren()`** — Returns every one of this node's own children, wrapped, in declaration order. Doesn't recurse into grandchildren. Empty if it has none.
- **`Component:GetFrame()`** — Returns this node's frame. `nil` if not resolved yet, e.g. a `frameFactory` not yet laid out.
- **`Component:IsDirty()`** — Returns `true` if this node's tree has changed since its last `Layout()` call.

#### Visibility

- **`Component:Hide()`** — Takes this node out of the layout flow entirely, its siblings reflow to fill the space, and hides its own frame. Its position in the tree is preserved, `Show()` brings it back, no re-inserting needed. No-ops if already hidden.
- **`Component:Show()`** — Reverses `Hide()`. No-ops if not currently hidden.

#### Setters

- **`Component:SetDirection(direction?)`** — Sets this node's own main axis for its own children. Pass `nil` to reset to the default (`"ROW"`). No-ops if already that value.
- **`Component:SetWidth(width?)`** — Sets this node's own physical width. Pass `nil` to let it flex/stretch instead (whichever applies), `"AUTO"` to compute it from this node's own children (a sum along its main axis, a max along its cross axis), or a percentage string (`"50%"`) to size it relative to the parent. No-ops if already that value.
- **`Component:SetHeight(height?)`** — Sets this node's own physical height. Same as `SetWidth()` in every other respect, the vertical axis instead.
- **`Component:SetGrow(grow?)`** — Sets this node's own share of its parent's leftover main-axis space. Pass `nil` to reset to the default (`1`). No-ops if already that value.
- **`Component:SetShrink(shrink?)`** — Sets this node's own share of its parent's main-axis deficit. Pass `nil` to reset to the default (`1`). No-ops if already that value.
- **`Component:SetAlign(align?)`** — Sets how this node aligns its own children along the cross axis by default. Pass `nil` to reset to the default (`"STRETCH"`). No-ops if already that alignment.
- **`Component:SetAlignSelf(alignSelf?)`** — Sets how this node aligns itself within its parent along the cross axis, overriding the parent's own `align`. Pass `nil` to go back to inheriting it. No-ops if already that alignment.
- **`Component:SetJustify(justify?)`** — Sets how this node distributes leftover main-axis space among its own children. Pass `nil` to reset to the default (`"START"`). No-ops if already that value.
- **`Component:SetWrap(wrap?)`** — Sets whether this node's overflowing children wrap onto a new line. Pass `nil` to reset to the default (`false`). No-ops if already that value.
- **`Component:SetGap(gap?)`** — Sets the space between this node's own children. No-ops if already that gap.
- **`Component:SetLineGap(lineGap?)`** — Sets the space between this node's own wrapped lines, instead of `SetGap()`. Pass `nil` to fall back to `SetGap()`'s own value. No-ops if already that value.
- **`Component:SetPadding(padding?)`** — Sets the space between this node's edge and its own children, on all four sides. No-ops if already that padding.
- **`Component:SetPaddingTop(paddingTop?)`** / **`Component:SetPaddingRight(paddingRight?)`** / **`Component:SetPaddingBottom(paddingBottom?)`** / **`Component:SetPaddingLeft(paddingLeft?)`** — Overrides `SetPadding()` for one side. Pass `nil` to revert to it. No-ops if already that value.
- **`Component:SetMargin(margin?)`** — Sets the space around this node itself, on all four sides. Pass `nil` to reset to the default (`0`). No-ops if already that value.
- **`Component:SetMarginTop(marginTop?)`** / **`Component:SetMarginRight(marginRight?)`** / **`Component:SetMarginBottom(marginBottom?)`** / **`Component:SetMarginLeft(marginLeft?)`** — Overrides `SetMargin()` for one side. Pass `nil` to revert to it. No-ops if already that value.
- **`Component:SetMinWidth(minWidth?)`** / **`Component:SetMaxWidth(maxWidth?)`** — Sets a floor/ceiling on this node's own `width`. Pass `nil` to remove it. No-ops if already that value.
- **`Component:SetMinHeight(minHeight?)`** / **`Component:SetMaxHeight(maxHeight?)`** — Same as `SetMinWidth()`/`SetMaxWidth()`, for `height`.
- **`Component:SetOrder(order?)`** — Sets this node's visual position among its siblings, independent of declaration order. Pass `nil` to reset to the default (`0`). No-ops if already that order.
- **`Component:SetOnLayout(onLayout?)`** — Sets the callback fired once this node's own `Layout()` pass is resolved and clean. Pass `nil` to remove it. No-ops if already that value.

## Testing

Waffle includes a test suite under `test/`, run against Lua 5.1:

```bash
./run-tests.sh
```

Tests run automatically via GitHub Actions on every push and pull request to `main`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a history of what's changed.
