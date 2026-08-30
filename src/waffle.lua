-- =============================================================================
-- Waffle: 0.0.1 - https://github.com/moody/Waffle
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
--- @field frame WaffleFrame
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
    child.frame:ClearAllPoints()
    child.frame:SetParent(options.parent)

    local size = child.size or flexSize
    local frame = child.frame
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
        children = child.children,
      })
    end

    mainOffset = mainOffset + size + gap
  end
end

-- =============================================================================
-- FlexBuilder
-- =============================================================================

--- Returned by `Waffle:Flex()`. Composes a container's children fluently;
--- nothing runs until `Layout()` is called on the root builder.
--- @class WaffleFlexBuilder
--- @field private node WaffleFlexOptions | WaffleFlexChild
local FlexBuilder = {}
FlexBuilder.__index = FlexBuilder

--- @param node WaffleFlexOptions | WaffleFlexChild
--- @return WaffleFlexBuilder
local function newFlexBuilder(node)
  node.children = node.children or {}
  return setmetatable({ node = node }, FlexBuilder)
end

--- Appends a child as-is.
--- @param child WaffleFlexChild
--- @return WaffleFlexBuilder self
function FlexBuilder:AddChild(child)
  table.insert(self.node.children, child)
  return self
end

--- Appends a new ROW container as a child, returning its builder for further composition.
--- @param child? WaffleFlexChild
--- @return WaffleFlexBuilder
function FlexBuilder:AddRow(child)
  child = child or {}
  child.direction = "ROW"
  table.insert(self.node.children, child)
  return newFlexBuilder(child)
end

--- Appends a new COLUMN container as a child, returning its builder for further composition.
--- @param child? WaffleFlexChild
--- @return WaffleFlexBuilder
function FlexBuilder:AddColumn(child)
  child = child or {}
  child.direction = "COLUMN"
  table.insert(self.node.children, child)
  return newFlexBuilder(child)
end

--- Runs the layout for everything composed so far. Call only on the root
--- builder, nested `AddRow`/`AddColumn` builders are laid out automatically
--- as part of it.
function FlexBuilder:Layout()
  flexLayout(self.node)
end

-- =============================================================================
-- Waffle
-- =============================================================================

--- Starts composing a `Flex` container and returns a builder: call
--- `AddRow`/`AddColumn`/`AddChild` to populate it, then `Layout()` to run it.
--- For a fully declarative style, `options.children` may be given directly.
--- @param options WaffleFlexOptions
--- @return WaffleFlexBuilder
function Waffle:Flex(options)
  return newFlexBuilder(options)
end
