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

--- A single child of a `Flex` container. Providing `children` makes this
--- child itself a nested `Flex` container.
--- @class WaffleFlexChild
--- @field frame WaffleFrame
--- @field size? integer Fixed size along the main axis (width for `ROW`, height for `COLUMN`). Omit to fill remaining space, shared evenly with every other child that also omits it.
--- @field children? WaffleFlexChild[] Makes this child a nested `Flex` container, laid out within its own resolved width/height.
--- @field direction? WaffleFlexDirection
--- @field gap? integer Passed through to the nested `Flex` call.
--- @field padding? integer Passed through to the nested `Flex` call.
--- @field onLayout? fun(frame: WaffleFrame, width: integer, height: integer) Called with this child's own frame and its resolved width/height, right after they're assigned. Use this instead of `children` for anything beyond "just recurse".

--- @class WaffleFlexOptions
--- @field parent WaffleFrame
--- @field direction WaffleFlexDirection
--- @field width integer The container's available width.
--- @field height integer The container's available height.
--- @field children WaffleFlexChild[]
--- @field gap? integer Space between consecutive children. Default `0`.
--- @field padding? integer Space between the container's edge and its children, on all four sides. Default `0`.

-- =============================================================================
-- Waffle
-- =============================================================================

--- Positions `options.children` in a row or column within `options.parent`,
--- each child's `TOPLEFT` anchored to `options.parent`'s `TOPLEFT` with a
--- computed offset, never anchored to a sibling. Children stretch to fill
--- the cross axis (height for `ROW`, width for `COLUMN`).
--- @param options WaffleFlexOptions
function Waffle:Flex(options)
  options.parent:SetWidth(options.width)
  options.parent:SetHeight(options.height)

  local children = options.children
  local gap = options.gap or 0
  local padding = options.padding or 0
  local isRow = options.direction == "ROW"

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
      Waffle:Flex({
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
