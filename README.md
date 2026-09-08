# Waffle 🧇 (0.8.0)

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
   local _, Addon = ...
   local Waffle = Addon.Waffle
   ```

## Usage

**Composing a layout.** `Waffle:Flex(node)` positions `node.children` in a row or column within `node.frame`, and returns a component. `direction` (`"ROW"` or `"COLUMN"`, defaults to `"ROW"`) decides which physical axis is main and which is cross: a ROW's main axis is horizontal (`width`), its cross axis vertical (`height`); a COLUMN flips that. Nothing runs until `Layout()` is called on it.

```lua
Waffle:Flex({
  frame = frame,
  direction = "COLUMN",
  width = 400,
  height = 300,
  gap = 8,
  padding = 8,
  children = {
    -- Header: fixed height, title flexes to fill the leftover space, button stays put.
    {
      frame = header,
      direction = "ROW",
      height = 24,
      children = {
        { frame = title },
        { frame = closeButton, width = 24 },
      }
    },
    -- Body: a nested row, splitting the rest of the column between a fixed sidebar
    -- and flexible content.
    {
      frame = body,
      direction = "ROW",
      gap = 8,
      children = {
        { frame = sidebar, width = 100 },
        { frame = content },
      }
    },
  }
}):Layout()
```

Every field used above, and every other one Waffle supports (`"AUTO"`/percentage sizing, `grow`/`shrink`, `align`/`justify`, `wrap`, `minWidth`/`maxWidth`, and more), works the same on any node and is documented with a runnable example in [Node](#node) below.

**The fluent API.** The same tree, composed step by step instead of as one large table. `AddRow`/`AddColumn`/`AddChild` each return a component scoped to what they just added; `Layout()` only needs to be called once, and works the same from any node in the tree:

```lua
local root = Waffle:Flex({ frame = frame, direction = "COLUMN", width = 400, height = 300, gap = 8, padding = 8 })

local header = root:AddRow({ frame = CreateFrame("Frame"), height = 24 })
header:AddChild({ frame = title })
header:AddChild({ frame = closeButton, width = 24 })

local body = root:AddRow({ frame = CreateFrame("Frame"), gap = 8 })
body:AddChild({ frame = sidebar, key = "sidebar", width = 100 })
body:AddChild({ frame = content })

root:Layout()
```

`AttachComponent` grafts an already-built component (its own separate `Waffle:Flex()` tree) into another one as-is; `Detach()` pulls a component out of wherever it currently is, so the two compose directly into a single call that moves one into a different tree entirely:

```lua
otherRoot:AttachComponent(root:GetChild("sidebar"):Detach())
```

Every method used above, and every other one Waffle supports (`GetChild`, `SetHidden`, every other setter/getter, and more), works the same on any node and is documented with a runnable example in [Component](#component) below.

**Reacting to resolved size.** `onLayout` fires with a node's own component and its resolved width/height, once the whole tree is laid out. Useful for anything Waffle doesn't handle automatically, like keeping a `ScrollFrame`'s scroll child in sync (WoW doesn't resize it to fit the visible area on its own):

```lua
root:AddChild({
  frame = scrollFrame,
  onLayout = function(component, width, height)
    local frame = component:GetFrame()
    frame.scrollChild:SetWidth(width)
    local slider = component:GetChild("slider")
    slider:SetHidden(frame.scrollChild:GetHeight() <= height)
  end
})
root:AddChild({ frame = sliderFrame, key = "slider", width = 20 })
```

**Calling `Layout()` again.** Nothing about `Layout()` is one-time, it's a pure recompute of whatever's currently composed. Call it again any time state changes, from any node in the tree, not just the root, it always resolves and lays out the whole tree from its actual current root. A call is a no-op unless something changed since the last one, so it's cheap to call from an `OnUpdate` handler every frame. `IsDirty()` tells you whether a call would actually do anything, without triggering one.

## API

### `Waffle:Flex(node)`

Starts composing a container and returns it. `node` is the root of the tree, the same shape as any other node, except it has no parent to supply a cross axis: it needs both `width` and `height` given, each directly or as `"AUTO"`. `node.children` can be given directly for a fully declarative style. Nothing runs until `Layout()` is called.

### Node

Every node in the tree, whether it's the one passed to `Waffle:Flex()` or a child added via `AddChild`/`AddRow`/`AddColumn`/`children`, shares the same shape, `WaffleFlexNode`:

```lua
--- @type WaffleFlexNode
local node = {
  -- An already-built frame, handed over as-is. Cannot be given together with frameFactory.
  -- Not changeable after construction.
  frame = CreateFrame("Frame"),

  -- Creates this node's own frame, once. Receives the resolved parent as an argument.
  -- Cannot be given together with frame. If it uses $parent name substitution, the parent
  -- must be passed in immediately here, not reparented later, substitution happens at
  -- creation time. Not changeable after construction.
  frameFactory = function(parent)
    return CreateFrame("Frame", "$parent_ChildFrame", parent)
  end,

  -- Creates a frame for any descendant that gives neither frame nor its own frameFactory.
  -- Does not apply to this node; even the root needs its own frame/frameFactory, nothing
  -- above it to inherit a fallback from. SetDefaultFrameFactory() toggles it after the fact;
  -- an already-resolved descendant's own frame is unaffected either way.
  defaultFrameFactory = function(parent)
    return CreateFrame("Frame", nil, parent)
  end,

  -- Can be given directly for a fully declarative style, instead of
  -- AddChild/AddRow/AddColumn; a node written directly into this table is still
  -- tracked and protected against double-attachment the same way.
  children = {
    { frame = CreateFrame("Frame") },
  },

  -- "ROW", "COLUMN", "ROW_REVERSE", or "COLUMN_REVERSE". Defaults to "ROW".
  -- Applies to this node's own children, if it has any. The _REVERSE variants keep the
  -- same main axis, just flip which edge is main-start; order still sorts first.
  -- Can also be toggled after the fact with SetDirection().
  direction = "ROW",

  -- This node's own physical width, always horizontal, regardless of direction. Used
  -- directly as a fixed size, whether that's this node's own main-axis size within its
  -- parent (a ROW parent) or its cross-axis size (a COLUMN parent; required if resolved
  -- to a non-STRETCH alignment there, ignored, falling back to stretching, when
  -- STRETCH). Omitted, flexes/stretches instead, whichever applies. "AUTO" computes
  -- it from this node's own children instead: a sum of their own width (plus
  -- gap/padding) along this node's own main axis (direction is ROW), or a max of
  -- them (plus padding) along its cross axis; every visible child needs its own number
  -- or "AUTO", a flexible child errors. A percentage string ("50%") sizes it relative
  -- to the parent's own width instead, erroring without one already resolved (the root,
  -- or a parent whose own width is itself still being computed from "AUTO").
  -- Can also be toggled after the fact with SetWidth().
  width = 200,

  -- This node's own physical height, always vertical. Same as width in every other
  -- respect, "AUTO" sums along the main axis when direction is COLUMN, maxes along
  -- the cross axis otherwise, a percentage sizes it relative to the parent's own height.
  -- Can also be toggled after the fact with SetHeight().
  height = 100,

  -- This node's own share of its parent's leftover main-axis space, relative to its
  -- equally-flexible siblings. Defaults to 1. No effect on a node with its own explicit
  -- main-axis width/height, or on the root. Can also be toggled after the fact with
  -- SetGrow().
  grow = 1,

  -- This node's own share of its parent's main-axis deficit, when its siblings' own sizes
  -- don't all fit, weighted by this value times this node's own main-axis size, not the
  -- value alone. Defaults to 1. No effect on a flexible node (nothing stated to reduce),
  -- or on the root. Can also be toggled after the fact with SetShrink().
  shrink = 1,

  -- How this node aligns its own children along the cross axis, if it has any:
  -- "STRETCH" (default), "START", "CENTER", or "END". Overridden per-child by
  -- that child's own alignSelf. Can also be toggled after the fact with SetAlign().
  align = "STRETCH",

  -- Overrides the parent's align for this node specifically. Requires this node's own
  -- cross-axis dimension if not "STRETCH". No effect on the root, nothing above it to
  -- align it within. Can also be toggled after the fact with SetAlignSelf().
  alignSelf = "STRETCH",

  -- How this node distributes leftover main-axis space among its own children, if it has
  -- any: "START" (default), "CENTER", "END", "SPACE_BETWEEN", "SPACE_AROUND", or
  -- "SPACE_EVENLY". Only matters when none of those children have a positive grow
  -- share. Can also be toggled after the fact with SetJustify().
  justify = "START",

  -- Overflowing children start a new line instead of continuing past the main axis size.
  -- Each line gets its own cross-size (a max over its own children) and stacks after the
  -- previous one, lineGap between lines too. Default false. Can also be toggled after
  -- the fact with SetWrap().
  wrap = false,

  -- Space between this node's own children, if it has any. Can also be toggled after the
  -- fact with SetGap().
  gap = 8,

  -- Space between wrapped lines only, instead of gap. Falls back to gap when unset.
  -- No effect unless wrap actually produces more than one line. Can also be toggled
  -- after the fact with SetLineGap().
  lineGap = 8,

  -- Space around this node's own children, if it has any. Can also be toggled after the
  -- fact with SetPadding().
  padding = 8,

  -- Overrides padding for the top side only. Falls back to padding if not given.
  -- Can also be toggled after the fact with SetPaddingTop().
  paddingTop = 8,

  -- Overrides padding for the right side only. Falls back to padding if not given.
  -- Can also be toggled after the fact with SetPaddingRight().
  paddingRight = 8,

  -- Overrides padding for the bottom side only. Falls back to padding if not given.
  -- Can also be toggled after the fact with SetPaddingBottom().
  paddingBottom = 8,

  -- Overrides padding for the left side only. Falls back to padding if not given.
  -- Can also be toggled after the fact with SetPaddingLeft().
  paddingLeft = 8,

  -- Space around this node itself, on all four sides, independent of the container's own
  -- gap. Defaults to 0. Can also be toggled after the fact with SetMargin().
  margin = 0,

  -- Overrides margin for the top side only. Falls back to margin if not given.
  -- Can also be toggled after the fact with SetMarginTop().
  marginTop = 0,

  -- Overrides margin for the right side only. Falls back to margin if not given.
  -- Can also be toggled after the fact with SetMarginRight().
  marginRight = 0,

  -- Overrides margin for the bottom side only. Falls back to margin if not given.
  -- Can also be toggled after the fact with SetMarginBottom().
  marginBottom = 0,

  -- Overrides margin for the left side only. Falls back to margin if not given.
  -- Can also be toggled after the fact with SetMarginLeft().
  marginLeft = 0,

  -- A floor on this node's own width: its flexible main-axis share, if width is
  -- main; a STRETCH-ed cross-axis size, if cross. No effect on an explicit width,
  -- "AUTO", or non-STRETCH alignment. Errors if greater than maxWidth. Can also be
  -- toggled after the fact with SetMinWidth().
  minWidth = 50,

  -- A ceiling on this node's own width, the same way minWidth is a floor. Errors if
  -- less than minWidth. Can also be toggled after the fact with SetMaxWidth().
  maxWidth = 300,

  -- Same as minWidth, for height. Can also be toggled after the fact with
  -- SetMinHeight().
  minHeight = 50,

  -- Same as maxWidth, for height. Can also be toggled after the fact with
  -- SetMaxHeight().
  maxHeight = 300,

  -- Excludes this node from the layout flow entirely. Can also be toggled after the
  -- fact with SetHidden(). Layout() hides its own frame and every already-resolved
  -- frame in its subtree. An ancestor's own hidden hides this node's frame the same
  -- way; GetHidden() still only reports this node's own hidden, never an ancestor's.
  hidden = false,

  -- Registers this node for lookup via GetChild(key) from anywhere in the tree. A
  -- duplicate key isn't validated against, the first match found wins. Can also be
  -- toggled after the fact with SetKey(), which never marks the tree dirty, there's
  -- nothing to recompute.
  key = "sidebar",

  -- Visual position among siblings, independent of declaration order. Defaults to 0;
  -- siblings with equal order keep their declaration order. No effect on the root,
  -- nothing above it to reorder it among. Can also be toggled after the fact with
  -- SetOrder().
  order = 0,

  -- Called with this node's own component and resolved width/height, once the whole
  -- Layout() pass is resolved and clean. Re-fires on every Layout() call, keep it
  -- idempotent. Mutating a different node from here schedules a future Layout() call,
  -- the same as any other setter. Can also be toggled after the fact with
  -- SetOnLayout().
  onLayout = function(component, width, height) end,
}
```

### Component

Every component, whether returned by `Waffle:Flex()`, `AddChild`, `AddRow`, `AddColumn`, `AttachComponent`, `Detach`, `GetChild`, or `GetChildren`, shares the same shape, `WaffleFlexComponent`. Whether a node has children is a fact about it, not a fixed type, so every method below works the same regardless of whether the node it's called on currently has any.

```lua
local component = Waffle:Flex(node)

-- Tree composition

-- Appends node as a child as-is, returning its own component. Errors if node already
-- belongs to a different component, call DetachComponent() on that one first to move it
-- here. No-ops if node is already this node's own.
local child = component:AddChild({ frame = CreateFrame("Frame") })

-- Appends a new ROW/COLUMN child, returning a new component scoped to it. Errors if node
-- already belongs to a different component, call DetachComponent() on that one first to
-- move it here. No-ops if node is already this node's own.
local row = component:AddRow()
local column = component:AddColumn()

-- Grafts an already-composed component into this node's children, as-is: its own
-- direction, size, and structure are unchanged, unlike AddRow/AddColumn. Errors if
-- component already belongs to a different one, call DetachComponent() on that one first
-- to move it here. No-ops if component is already this node's own.
local built = Waffle:Flex({ frame = CreateFrame("Frame"), width = 100, height = 50 })
component:AttachComponent(built)

-- Detaches this component from its current owner, if it has one, the same as calling
-- DetachComponent() on that owner. Always returns itself, whether or not it actually had
-- an owner to release.
child:Detach()

-- Removes component from this node's own children entirely, detaching it (and its own
-- children, if it has any) from the tree rather than excluding it from layout the way
-- SetHidden(true) does. Doesn't touch component's own frame. Only succeeds if component
-- really is this node's own child; returns false, without detaching it, if it's attached
-- elsewhere.
local detached = component:DetachComponent(row)

-- Removes every child from this node, same as calling DetachComponent on each one.
component:Clear()

-- Layout

-- Runs the layout for the tree containing this node, starting from its actual current
-- root. Works from any node in the tree, not just the root. No-ops unless something
-- changed since the last call.
component:Layout()

-- Queries

-- Looks up a child anywhere in the tree by the key it was given. Errors if no child was
-- registered under key.
local sidebar = component:GetChild("sidebar")

-- Returns every one of this node's own children, wrapped, in declaration order. Doesn't
-- recurse into grandchildren. Empty if it has none.
local children = component:GetChildren()

-- Returns this node's frame. nil if not resolved yet, e.g. a frameFactory not yet laid out.
local frame = component:GetFrame()

-- Returns true if this node's tree has changed since its last Layout() call.
local isDirty = component:IsDirty()

-- Setters and Getters

-- Every setter below is a no-op unless the value actually changes (SetKey is the one
-- exception, see below), and has a matching getter immediately below it, returning the
-- raw value it was given, nil if unset. frame/frameFactory (see Node above) are the only
-- exceptions: frame has no setter (GetFrame() still works); frameFactory has neither, not
-- changeable after construction.

-- Sets a frame factory for any descendant that gives neither frame nor its own
-- frameFactory. Pass nil to remove it. An already-resolved descendant's own frame is
-- unaffected either way, only one still waiting on a factory picks up the change.
component:SetDefaultFrameFactory(function(parent) return CreateFrame("Frame", nil, parent) end)
local defaultFrameFactory = component:GetDefaultFrameFactory()

-- Sets this node's own main axis for its own children. Pass nil to reset to the default
-- (ROW).
component:SetDirection("COLUMN")
local direction = component:GetDirection()

-- Sets this node's own physical width. Pass nil to let it flex/stretch instead (whichever
-- applies), "AUTO" to compute it from this node's own children (a sum along its main
-- axis, a max along its cross axis), or a percentage string ("50%") to size it relative
-- to the parent.
component:SetWidth(200)
local width = component:GetWidth()

-- Sets this node's own physical height. Same as SetWidth() in every other respect, the
-- vertical axis instead.
component:SetHeight(100)
local height = component:GetHeight()

-- Sets width and height together, equivalent to SetWidth()/SetHeight(). Omitting either
-- argument passes nil, resetting that dimension instead of leaving it unchanged.
component:SetSize(200, 100)

-- Returns width and height together, the same values SetWidth()/SetHeight() (or SetSize())
-- were last given.
local width, height = component:GetSize()

-- Sets this node's own share of its parent's leftover main-axis space. Pass nil to reset
-- to the default (1).
child:SetGrow(2)
local grow = child:GetGrow()

-- Sets this node's own share of its parent's main-axis deficit. Pass nil to reset to the
-- default (1).
child:SetShrink(0)
local shrink = child:GetShrink()

-- Sets how this node aligns its own children along the cross axis by default. Pass nil to
-- reset to the default (STRETCH).
component:SetAlign("CENTER")
local align = component:GetAlign()

-- Sets how this node aligns itself within its parent along the cross axis, overriding the
-- parent's own align. Pass nil to go back to inheriting it.
child:SetAlignSelf("END")
local alignSelf = child:GetAlignSelf()

-- Sets how this node distributes leftover main-axis space among its own children. Pass
-- nil to reset to the default (START).
component:SetJustify("SPACE_BETWEEN")
local justify = component:GetJustify()

-- Sets whether this node's overflowing children wrap onto a new line. Pass nil to reset
-- to the default (false).
component:SetWrap(true)
local wrap = component:GetWrap()

-- Sets the space between this node's own children. Pass nil to reset to the default (0).
component:SetGap(8)
local gap = component:GetGap()

-- Sets the space between this node's own wrapped lines, instead of SetGap(). Pass nil to
-- fall back to SetGap()'s own value.
component:SetLineGap(16)
local lineGap = component:GetLineGap()

-- Sets the space between this node's edge and its own children, on all four sides. Pass
-- nil to reset to the default (0).
component:SetPadding(8)
local padding = component:GetPadding()

-- Overrides SetPadding() for one side. Pass nil to revert to it.
component:SetPaddingTop(4)
component:SetPaddingRight(4)
component:SetPaddingBottom(4)
component:SetPaddingLeft(4)
local paddingTop = component:GetPaddingTop()
local paddingRight = component:GetPaddingRight()
local paddingBottom = component:GetPaddingBottom()
local paddingLeft = component:GetPaddingLeft()

-- Sets the space around this node itself, on all four sides. Pass nil to reset to the
-- default (0).
child:SetMargin(4)
local margin = child:GetMargin()

-- Overrides SetMargin() for one side. Pass nil to revert to it.
child:SetMarginTop(2)
child:SetMarginRight(2)
child:SetMarginBottom(2)
child:SetMarginLeft(2)
local marginTop = child:GetMarginTop()
local marginRight = child:GetMarginRight()
local marginBottom = child:GetMarginBottom()
local marginLeft = child:GetMarginLeft()

-- Sets a floor/ceiling on this node's own width. Pass nil to remove it.
child:SetMinWidth(50)
child:SetMaxWidth(300)
local minWidth = child:GetMinWidth()
local maxWidth = child:GetMaxWidth()

-- Same as SetMinWidth()/SetMaxWidth(), for height.
child:SetMinHeight(50)
child:SetMaxHeight(300)
local minHeight = child:GetMinHeight()
local maxHeight = child:GetMaxHeight()

-- Sets whether this node is excluded from the layout flow entirely; its siblings reflow
-- to fill the space, and Layout() hides its own frame and every already-resolved frame
-- in its subtree. An ancestor's own hidden hides this node's frame the same way, without
-- changing this node's own hidden. Pass nil to reset to the default (false).
child:SetHidden(true)

-- Returns this node's own hidden, never an ancestor's: a node whose ancestor is hidden
-- still returns nil/false here, even though its own frame is hidden too.
local hidden = child:GetHidden()

-- Sets this node's own key, for lookup via GetChild(key). Pass nil to remove it. Unlike
-- every other setter, never marks the tree dirty: GetChild always searches live, there's
-- nothing to recompute.
child:SetKey("sidebar")
local key = child:GetKey()

-- Sets this node's visual position among its siblings, independent of declaration order.
-- Pass nil to reset to the default (0).
child:SetOrder(1)
local order = child:GetOrder()

-- Sets the callback fired once this node's own Layout() pass is resolved and clean. Pass
-- nil to remove it.
component:SetOnLayout(function(comp, width, height) end)
local onLayout = component:GetOnLayout()
```

## Testing

Waffle includes a test suite under `test/`, run against Lua 5.1:

```bash
./run-tests.sh
```

Tests run automatically via GitHub Actions on every push and pull request to `main`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a history of what's changed.
