# Waffle 🧇

**W**oW **A**ddon **F**lexible **F**rame **L**ayout **E**ngine

Waffle is a flex layout library for World of Warcraft addons, inspired by [CSS Flexbox](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout/Basic_concepts_of_flexbox).

## Features

- Row/column flex layout with fixed and flexible sizing, gap, and padding, no manual `SetPoint` math
- A fluent builder API (`AddRow`, `AddColumn`, `AddChild`) for composing nested layouts, or a fully declarative table if you'd rather write it that way
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

**Composing declaratively.** `Waffle:Flex(options)` positions `options.children` in a row or column within `options.parent`, and returns a builder. Nothing runs until `Layout()` is called on it.

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

`direction` defaults to `"ROW"`, same as CSS Flexbox. Children stretch to fill the cross axis. A child with `size` takes exactly that much space along the main axis; a child without one splits whatever's left over evenly with any other flexible siblings, here that's `content` getting the full 300 left after `sidebar`'s 100.

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

**The builder API.** The same tree, composed fluently instead of as one large nested table. `AddRow`/`AddColumn` append a nested container and return a new builder scoped to it; `Layout()` only needs to be called once, on the root.

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

**Calling `Layout()` again.** Nothing about `Layout()` is one-time, it's a pure recompute of whatever's currently composed. Add another child with `AddChild`/`AddRow`/`AddColumn`, then call `Layout()` again on the same root builder to bring the frames in line. Removing children and mutating an existing one's `gap`/`padding` aren't first-class yet, that's still ahead.

**Looking up a child by key.** Give a child a `key` when adding it, and retrieve it later with `GetChild(key)`, from the root builder or from any other builder or handle in the tree, they all share the same lookup. Duplicate or invalid keys will throw an error.

```lua
root:AddChild({ frame = content, key = "content" })

-- from anywhere else with a reference into this tree:
local contentHandle = root:GetChild("content")
```

## API

- **`Waffle:Flex(options)`** — Starts composing a container, returns a `WaffleFlexContainerBuilder`. `options.children` can be given directly for a fully declarative style. Nothing runs until `Layout()` is called.
- **`Builder:AddChild(child)`** — Appends a child as-is, a leaf frame or a manually composed subtree via its own `children`/`onLayout`. Returns a handle to it.
- **`Builder:AddRow(child?)`** / **`Builder:AddColumn(child?)`** — Appends a new ROW/COLUMN container as a child, returning a new builder scoped to it.
- **`Builder:Layout()`** — Runs the layout for everything composed so far. Call only on the root builder, nested containers are laid out automatically as part of it. Safe to call again later.
- **`Builder:GetChild(key)`** — Looks up a child anywhere in the tree by the `key` it was given. Works from the root or any nested builder/handle. Errors if no child was registered under `key`.

The options (`WaffleFlexOptions`) passed to `Waffle:Flex()` accept:

- **`parent`** — The frame `children` are positioned within.
- **`width`** / **`height`** — The container's available size.
- **`children`** — Can be given directly for a fully declarative style, instead of `AddChild`/`AddRow`/`AddColumn`.
- **`direction`** — `"ROW"` or `"COLUMN"`. Defaults to `"ROW"`.
- **`gap`** / **`padding`** — Space between/around children.
- **`defaultFrameFactory`** — Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`. Reaches every level, receives the resolved parent as an argument.

A child (`WaffleFlexChild`), whether given via `options.children` or `AddChild`/`AddRow`/`AddColumn`, accepts the same `direction`, `gap`, and `padding` as above (they apply to the nested container this child becomes), plus:

- **`frame`** — An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
- **`frameFactory`** — Creates this child's own frame, once. Receives the resolved parent as an argument. Cannot be given together with `frame`.
- **`key`** — Registers this child for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key errors.
- **`size`** — Fixed size along the main axis. Omitted children split the remaining space evenly.
- **`onLayout`** — Called with this child's frame and resolved width/height, once assigned.

## Testing

Waffle includes a test suite under `test/`, run against Lua 5.1:

```bash
./run-tests.sh
```

Tests run automatically via GitHub Actions on every push and pull request to `main`.
