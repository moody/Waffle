# Waffle

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

**Frame factory.** Omit `frame` on a child and Waffle creates one for it via `frameFactory`, inherited down the whole tree unless a child overrides it. Handy for wrapper containers that don't need to be anything but a positioning box.

```lua
local root = Waffle:Flex({
  parent = frame,
  width = 400,
  height = 300,
  direction = "COLUMN",
  frameFactory = function() return CreateFrame("Frame") end
})
root:AddChild({ frame = header, size = 40 })

local body = root:AddRow() -- no frame given, frameFactory makes one
body:AddChild({ frame = sidebar, size = 100 })
body:AddChild({ frame = content })

root:Layout()
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

## API

- **`Waffle:Flex(options)`** — Starts composing a container, returns a `WaffleFlexBuilder`. `options.children` can be given directly for a fully declarative style. Nothing runs until `Layout()` is called.
- **`Builder:AddChild(child)`** — Appends a child as-is, a leaf frame or a manually composed subtree via its own `children`/`onLayout`. Returns the same builder.
- **`Builder:AddRow(child?)`** / **`Builder:AddColumn(child?)`** — Appends a new ROW/COLUMN container as a child, returning a new builder scoped to it.
- **`Builder:Layout()`** — Runs the layout for everything composed so far. Call only on the root builder, nested containers are laid out automatically as part of it. Safe to call again later.

The options (`WaffleFlexOptions`) passed to `Waffle:Flex()` accept:

- **`parent`** — The frame `children` are positioned within.
- **`width`** / **`height`** — The container's available size.
- **`children`** — Can be given directly for a fully declarative style, instead of `AddChild`/`AddRow`/`AddColumn`.
- **`direction`** — `"ROW"` or `"COLUMN"`. Defaults to `"ROW"`.
- **`gap`** / **`padding`** — Space between/around children.
- **`frameFactory`** — Creates a default frame for any child that omits `frame`.

A child (`WaffleFlexChild`), whether given via `options.children` or `AddChild`/`AddRow`/`AddColumn`, accepts the same `direction`, `gap`, `padding`, and `frameFactory` as above (they apply to the nested container this child becomes), plus:

- **`frame`** — The frame to position. Omit to create one via `frameFactory`.
- **`size`** — Fixed size along the main axis. Omitted children split the remaining space evenly.
- **`onLayout`** — Called with this child's frame and resolved width/height, once assigned.

## Testing

Waffle includes a test suite under `test/`, run against Lua 5.1:

```bash
./run-tests.sh
```

Tests run automatically via GitHub Actions on every push and pull request to `main`.
