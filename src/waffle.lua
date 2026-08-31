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
--- @field Hide fun(self: WaffleFrame)
--- @field SetHeight fun(self: WaffleFrame, height: integer)
--- @field SetParent fun(self: WaffleFrame, parent: WaffleFrame)
--- @field SetPoint fun(self: WaffleFrame, point: WafflePoint, parent: WaffleFrame, relativePoint: WafflePoint, offsetX: integer, offsetY: integer)
--- @field SetWidth fun(self: WaffleFrame, width: integer)
--- @field Show fun(self: WaffleFrame)

--- @alias WaffleFlexDirection "ROW" | "COLUMN"

--- Layout properties shared by `WaffleFlexNodeChild` and `WaffleFlexNodeParent`,
--- the plain data tables Waffle operates on.
--- @class WaffleFlexNode
--- @field direction? WaffleFlexDirection Default `ROW`.
--- @field gap? integer Space between consecutive children, if this node has any. Default `0`.
--- @field padding? integer Space between this node's edge and its children, on all four sides, if it has any. Default `0`.
--- @field children? WaffleFlexNodeChild[] Children positioned within this node, in a row or column depending on `direction`.
--- @field hidden? boolean Excludes this node from the layout flow entirely, its siblings reflow to fill the space. Default `false`. Set directly or via `Hide()`/`Show()`. No effect on the tree's actual root, nothing lays it out.

--- A single child of a `Flex` container.
--- @class WaffleFlexNodeChild : WaffleFlexNode
--- @field frame? WaffleFrame An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
--- @field frameFactory? fun(parent: WaffleFrame): WaffleFrame Creates this child's own frame, once. Cannot be given together with `frame`.
--- @field key? string Registers this child for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key errors.
--- @field size? integer Fixed size along the main axis (width for `ROW`, height for `COLUMN`). Omitted children split the remaining space evenly.
--- @field onLayout? fun(frame: WaffleFrame, width: integer, height: integer) Called with this child's frame and resolved width/height, once assigned. Use instead of `children` for anything beyond simple recursion.

--- @class WaffleFlexNodeParent : WaffleFlexNode
--- @field parent WaffleFrame
--- @field width integer The container's available width.
--- @field height integer The container's available height.
--- @field defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`.

-- =============================================================================
-- Local Functions
-- =============================================================================

--- Positions `options.children` in a row or column within `options.parent`.
--- Children stretch to fill the cross axis (height for `ROW`, width for `COLUMN`).
--- @param options WaffleFlexNodeParent
local function flexLayout(options)
  options.parent:SetWidth(options.width)
  options.parent:SetHeight(options.height)

  local children = options.children
  local gap = options.gap or 0
  local padding = options.padding or 0
  local isRow = (options.direction or "ROW"):upper() == "ROW"

  local mainSize = (isRow and options.width or options.height) - (padding * 2)
  local crossSize = (isRow and options.height or options.width) - (padding * 2)

  -- Sum fixed sizes and count flexible children among the visible ones, to
  -- find out how much space is left over, then split it evenly. A hidden
  -- child is excluded from the layout flow entirely, its siblings reflow
  -- to fill the space.
  local fixedTotal = 0
  local flexCount = 0
  local visibleCount = 0
  for _, child in ipairs(children) do
    if not child.hidden then
      visibleCount = visibleCount + 1
      if child.size then
        fixedTotal = fixedTotal + child.size
      else
        flexCount = flexCount + 1
      end
    end
  end

  local totalGap = gap * math.max(visibleCount - 1, 0)
  local remaining = mainSize - fixedTotal - totalGap
  local flexSize = flexCount > 0 and math.max(remaining / flexCount, 0) or 0

  local mainOffset = padding
  for _, child in ipairs(children) do
    if child.hidden then
      if child.frame then
        child.frame:Hide()
      end
    else
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

      frame:Show()
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
end

-- =============================================================================
-- FlexComponent
-- =============================================================================

--- Shared behavior between `WaffleFlexComponentContainer` and
--- `WaffleFlexComponentLeaf`.
--- @class WaffleFlexComponent
--- @field package root WaffleFlexComponentContainer
--- @field package node WaffleFlexNodeParent | WaffleFlexNodeChild
local FlexComponent = {}
FlexComponent.__index = FlexComponent

--- Returns a table whose missing methods fall back to `FlexComponent`.
--- @return WaffleFlexComponent
local function newFlexComponent()
  return setmetatable({}, FlexComponent)
end

--- Looks up a child anywhere in the tree by its `key`. Errors if none was
--- registered under it.
--- @param key string
--- @return WaffleFlexComponentContainer | WaffleFlexComponentLeaf
function FlexComponent:GetChild(key)
  local found = self.root.keyed[key]
  assert(found, "Waffle: no child registered under key '" .. key .. "'")
  return found
end

--- Removes this node from the layout flow entirely, its siblings reflow to
--- fill the space. Its position in the tree is preserved, `Show()` brings
--- it back.
function FlexComponent:Hide()
  if not self.node.hidden then
    self.node.hidden = true
    self.root.isDirty = true
  end
end

--- Reverses `Hide()`. No-ops if not currently hidden.
function FlexComponent:Show()
  if self.node.hidden then
    self.node.hidden = false
    self.root.isDirty = true
  end
end

-- =============================================================================
-- FlexComponentLeaf
-- =============================================================================

--- Returned by `AddChild`. A leaf child; cannot have children of its own.
--- @class WaffleFlexComponentLeaf : WaffleFlexComponent
--- @field package node WaffleFlexNodeChild
local FlexComponentLeaf = newFlexComponent()
FlexComponentLeaf.__index = FlexComponentLeaf

--- @param node WaffleFlexNodeChild
--- @param root WaffleFlexComponentContainer
--- @return WaffleFlexComponentLeaf
local function newFlexComponentLeaf(node, root)
  local leaf = setmetatable({ node = node, root = root }, FlexComponentLeaf)
  if node.key then
    assert(not root.keyed[node.key], "Waffle: duplicate key '" .. node.key .. "'")
    root.keyed[node.key] = leaf
  end
  return leaf
end

-- =============================================================================
-- FlexComponentContainer
-- =============================================================================

--- Returned by `Waffle:Flex()`. Composes a container's children fluently;
--- nothing runs until `Layout()` is called on the root container.
--- @class WaffleFlexComponentContainer : WaffleFlexComponent
--- @field package keyed table<string, WaffleFlexComponentContainer | WaffleFlexComponentLeaf>
--- @field package isDirty boolean Root only. Set by `AddChild`/`AddRow`/`AddColumn`; cleared by `Layout()`.
local FlexComponentContainer = newFlexComponent()
FlexComponentContainer.__index = FlexComponentContainer

--- Constructs a container for `node`, and recursively creates
--- containers/leaves for its children as necessary.
--- @param node WaffleFlexNodeParent | WaffleFlexNodeChild
--- @param root? WaffleFlexComponentContainer Omit for the root itself.
--- @return WaffleFlexComponentContainer
local function newFlexComponentContainer(node, root)
  node.children = node.children or {}
  local container = setmetatable({ node = node }, FlexComponentContainer)
  container.root = root or container
  if not root then
    container.keyed = {}
    container.isDirty = true
  end
  if node.key then
    assert(not container.root.keyed[node.key], "Waffle: duplicate key '" .. node.key .. "'")
    container.root.keyed[node.key] = container
  end
  for _, child in ipairs(node.children) do
    if child.children then
      newFlexComponentContainer(child, container.root)
    else
      newFlexComponentLeaf(child, container.root)
    end
  end
  return container
end

--- Appends a child as-is, returning its leaf.
--- @param child WaffleFlexNodeChild
--- @return WaffleFlexComponentLeaf
function FlexComponentContainer:AddChild(child)
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return newFlexComponentLeaf(child, self.root)
end

--- Appends a new ROW container as a child, returning its container for further composition.
--- @param child? WaffleFlexNodeChild
--- @return WaffleFlexComponentContainer
function FlexComponentContainer:AddRow(child)
  child = child or {}
  child.direction = "ROW"
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return newFlexComponentContainer(child, self.root)
end

--- Appends a new COLUMN container as a child, returning its container for further composition.
--- @param child? WaffleFlexNodeChild
--- @return WaffleFlexComponentContainer
function FlexComponentContainer:AddColumn(child)
  child = child or {}
  child.direction = "COLUMN"
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return newFlexComponentContainer(child, self.root)
end

--- Runs the layout for everything composed so far. Call only on the root
--- container, nested `AddRow`/`AddColumn` containers are laid out
--- automatically as part of it. No-ops if nothing changed since the last call.
function FlexComponentContainer:Layout()
  if self.root.isDirty then
    flexLayout(self.node)
    self.root.isDirty = false
  end
end

-- =============================================================================
-- Waffle
-- =============================================================================

--- Starts composing a `Flex` container and returns it: call
--- `AddRow`/`AddColumn`/`AddChild` to populate it, then `Layout()` to run it.
--- For a fully declarative style, `options.children` may be given directly.
--- @param options WaffleFlexNodeParent
--- @return WaffleFlexComponentContainer
function Waffle:Flex(options)
  return newFlexComponentContainer(options)
end
