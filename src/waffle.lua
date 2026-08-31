-- =============================================================================
-- Waffle: 0.2.0 - https://github.com/moody/Waffle
-- =============================================================================

local _, Addon = ...
Addon.Waffle = {}

--- @class Waffle
local Waffle = Addon.Waffle

-- =============================================================================
-- LuaCATS Annotations
-- =============================================================================

--- @alias WafflePoint "TOPLEFT" | "TOP" | "TOPRIGHT" | "LEFT" | "CENTER" | "RIGHT" | "BOTTOMLEFT" | "BOTTOM" | "BOTTOMRIGHT"

--- @class WaffleFrame
--- @field ClearAllPoints fun(self: WaffleFrame)
--- @field SetHeight fun(self: WaffleFrame, height: integer)
--- @field SetParent fun(self: WaffleFrame, parent: WaffleFrame)
--- @field SetPoint fun(self: WaffleFrame, point: WafflePoint, parent: WaffleFrame, relativePoint: WafflePoint, offsetX: integer, offsetY: integer)
--- @field SetWidth fun(self: WaffleFrame, width: integer)

--- @alias WaffleFlexDirection "ROW" | "COLUMN"

--- A single child of a `Flex` container.
--- @class WaffleFlexChild
--- @field frame? WaffleFrame An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
--- @field frameFactory? fun(parent: WaffleFrame): WaffleFrame Creates this child's own frame, once. Cannot be given together with `frame`.
--- @field key? string Registers this child for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key errors.
--- @field size? integer Fixed size along the main axis (width for `ROW`, height for `COLUMN`). Omitted children split the remaining space evenly.
--- @field children? WaffleFlexChild[] Makes this child a nested `Flex` container.
--- @field direction? WaffleFlexDirection Default `ROW`.
--- @field gap? integer Gap between children, once this becomes a nested container.
--- @field padding? integer Padding around children, once this becomes a nested container.
--- @field onLayout? fun(frame: WaffleFrame, width: integer, height: integer) Called with this child's frame and resolved width/height, once assigned. Use instead of `children` for anything beyond simple recursion.

--- @class WaffleFlexOptions
--- @field parent WaffleFrame
--- @field direction? WaffleFlexDirection Default `ROW`.
--- @field width integer The container's available width.
--- @field height integer The container's available height.
--- @field children? WaffleFlexChild[]
--- @field gap? integer Space between consecutive children. Default `0`.
--- @field padding? integer Space between the container's edge and its children, on all four sides. Default `0`.
--- @field defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`.

-- =============================================================================
-- Local Functions
-- =============================================================================

--- Positions `options.children` in a row or column within `options.parent`.
--- Children stretch to fill the cross axis (height for `ROW`, width for `COLUMN`).
--- @param options WaffleFlexOptions
local function flexLayout(options)
  options.parent:SetWidth(options.width)
  options.parent:SetHeight(options.height)

  local children = options.children
  local gap = options.gap or 0
  local padding = options.padding or 0
  local isRow = (options.direction or "ROW"):upper() == "ROW"

  local mainSize = (isRow and options.width or options.height) - (padding * 2)
  local crossSize = (isRow and options.height or options.width) - (padding * 2)

  -- Sum fixed sizes and count flexible children to find out how much space
  -- is left over, then split it evenly among the flexible ones.
  local fixedTotal = 0
  local flexCount = 0
  for _, child in ipairs(children) do
    if child.size then
      fixedTotal = fixedTotal + child.size
    else
      flexCount = flexCount + 1
    end
  end

  local totalGap = gap * math.max(#children - 1, 0)
  local remaining = mainSize - fixedTotal - totalGap
  local flexSize = flexCount > 0 and math.max(remaining / flexCount, 0) or 0

  local mainOffset = padding
  for _, child in ipairs(children) do
    assert(not (child.frame and child.frameFactory),
      "Waffle: child cannot have both `frame` and `frameFactory`")

    local frame = child.frame
    if not frame then
      local factory = child.frameFactory or options.defaultFrameFactory
      assert(factory, "Waffle: child has no `frame` and no `frameFactory`/`defaultFrameFactory` was provided")
      frame = factory(options.parent)
      child.frame = frame
      child.frameFactory = nil
    end

    frame:ClearAllPoints()
    frame:SetParent(options.parent)

    local size = child.size or flexSize
    local width, height

    if isRow then
      width, height = size, crossSize
      frame:SetPoint("TOPLEFT", options.parent, "TOPLEFT", mainOffset, -padding)
    else
      width, height = crossSize, size
      frame:SetPoint("TOPLEFT", options.parent, "TOPLEFT", padding, -mainOffset)
    end

    frame:SetWidth(width)
    frame:SetHeight(height)

    if child.onLayout then
      child.onLayout(frame, width, height)
    elseif child.children then
      flexLayout({
        parent = frame,
        width = width,
        height = height,
        direction = child.direction,
        gap = child.gap,
        padding = child.padding,
        defaultFrameFactory = options.defaultFrameFactory,
        children = child.children,
      })
    end

    mainOffset = mainOffset + size + gap
  end
end

-- =============================================================================
-- FlexLeafHandle
-- =============================================================================

--- Returned by `AddChild`. A handle to a single leaf child; can't have
--- children of its own.
--- @class WaffleFlexLeafHandle
--- @field package node WaffleFlexChild
--- @field package root WaffleFlexContainerBuilder
local FlexLeafHandle = {}
FlexLeafHandle.__index = FlexLeafHandle

--- @param node WaffleFlexChild
--- @param root WaffleFlexContainerBuilder
--- @return WaffleFlexLeafHandle
local function newFlexLeafHandle(node, root)
  local handle = setmetatable({ node = node, root = root }, FlexLeafHandle)
  if node.key then
    assert(not root.keyed[node.key], "Waffle: duplicate key '" .. node.key .. "'")
    root.keyed[node.key] = handle
  end
  return handle
end

--- Looks up a child anywhere in the tree by the `key` it was given when
--- added. Works from any builder or handle in the tree. Errors if no
--- child was registered under `key`.
--- @param key string
--- @return WaffleFlexContainerBuilder | WaffleFlexLeafHandle
function FlexLeafHandle:GetChild(key)
  local found = self.root.keyed[key]
  assert(found, "Waffle: no child registered under key '" .. key .. "'")
  return found
end

-- =============================================================================
-- FlexContainerBuilder
-- =============================================================================

--- Returned by `Waffle:Flex()`. Composes a container's children fluently;
--- nothing runs until `Layout()` is called on the root builder.
--- @class WaffleFlexContainerBuilder
--- @field package node WaffleFlexOptions | WaffleFlexChild
--- @field package root WaffleFlexContainerBuilder
--- @field package keyed table<string, WaffleFlexContainerBuilder | WaffleFlexLeafHandle>
--- @field package isDirty boolean Root only. Set by builder methods; cleared by `Layout()`.
local FlexContainerBuilder = {}
FlexContainerBuilder.__index = FlexContainerBuilder

--- Constructs a container builder for `node`, and recursively creates
--- builders/handles for its children as necessary.
--- @param node WaffleFlexOptions | WaffleFlexChild
--- @param root? WaffleFlexContainerBuilder Omit for the root itself.
--- @return WaffleFlexContainerBuilder
local function newFlexContainerBuilder(node, root)
  node.children = node.children or {}
  local builder = setmetatable({ node = node }, FlexContainerBuilder)
  builder.root = root or builder
  if not root then
    builder.keyed = {}
    builder.isDirty = true
  end
  if node.key then
    assert(not builder.root.keyed[node.key], "Waffle: duplicate key '" .. node.key .. "'")
    builder.root.keyed[node.key] = builder
  end
  for _, child in ipairs(node.children) do
    if child.children then
      newFlexContainerBuilder(child, builder.root)
    else
      newFlexLeafHandle(child, builder.root)
    end
  end
  return builder
end

--- Looks up a child anywhere in the tree by the `key` it was given when
--- added. Works from any builder or handle in the tree. Errors if no
--- child was registered under `key`.
--- @param key string
--- @return WaffleFlexContainerBuilder | WaffleFlexLeafHandle
function FlexContainerBuilder:GetChild(key)
  local found = self.root.keyed[key]
  assert(found, "Waffle: no child registered under key '" .. key .. "'")
  return found
end

--- Appends a child as-is, returning a handle to it.
--- @param child WaffleFlexChild
--- @return WaffleFlexLeafHandle
function FlexContainerBuilder:AddChild(child)
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return newFlexLeafHandle(child, self.root)
end

--- Appends a new ROW container as a child, returning its builder for further composition.
--- @param child? WaffleFlexChild
--- @return WaffleFlexContainerBuilder
function FlexContainerBuilder:AddRow(child)
  child = child or {}
  child.direction = "ROW"
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return newFlexContainerBuilder(child, self.root)
end

--- Appends a new COLUMN container as a child, returning its builder for further composition.
--- @param child? WaffleFlexChild
--- @return WaffleFlexContainerBuilder
function FlexContainerBuilder:AddColumn(child)
  child = child or {}
  child.direction = "COLUMN"
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return newFlexContainerBuilder(child, self.root)
end

--- Runs the layout for everything composed so far. Call only on the root
--- builder, nested `AddRow`/`AddColumn` builders are laid out automatically
--- as part of it. No-ops if nothing changed since the last call.
function FlexContainerBuilder:Layout()
  if self.root.isDirty then
    flexLayout(self.node)
    self.root.isDirty = false
  end
end

-- =============================================================================
-- Waffle
-- =============================================================================

--- Starts composing a `Flex` container and returns a builder: call
--- `AddRow`/`AddColumn`/`AddChild` to populate it, then `Layout()` to run it.
--- For a fully declarative style, `options.children` may be given directly.
--- @param options WaffleFlexOptions
--- @return WaffleFlexContainerBuilder
function Waffle:Flex(options)
  return newFlexContainerBuilder(options)
end
