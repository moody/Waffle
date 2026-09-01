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

--- Properties shared by every node in the tree, root included. The plain
--- data tables Waffle operates on.
--- @class WaffleFlexNode
--- @field frame? WaffleFrame An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
--- @field frameFactory? fun(parent: WaffleFrame): WaffleFrame Creates this node's own frame, once. Cannot be given together with `frame`. `parent` is `nil` for the tree's actual root, nothing sits above it to pass in.
--- @field children? WaffleFlexNode[] Children positioned within this node, in a row or column depending on `direction`.
--- @field direction? WaffleFlexDirection Default `ROW`.
--- @field size? integer Fixed size along the main axis (width for `ROW`, height for `COLUMN`) this node takes up within its parent. Omitted nodes split the remaining space evenly. Set directly or via `SetSize()`. No effect on the tree's actual root, nothing sizes it from outside.
--- @field gap? integer Space between consecutive children, if this node has any. Default `0`.
--- @field padding? integer Space between this node's edge and its children, on all four sides, if it has any. Default `0`.
--- @field hidden? boolean Excludes this node from the layout flow entirely, its siblings reflow to fill the space, and its own frame is hidden. Default `false`. Set directly or via `Hide()`/`Show()`.
--- @field key? string Registers this node for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key isn't validated against, the first match found wins.
--- @field order? integer Visual position among siblings, independent of declaration order. Default `0`, ties broken by declaration order. Set directly or via `SetOrder()`. No effect on the tree's actual root, nothing orders it among siblings.
--- @field onLayout? fun(frame: WaffleFrame, width: integer, height: integer) Called with this node's frame and resolved width/height, after its `children` (if any) are laid out.

--- The root passed to `Waffle:Flex()`.
--- @class WaffleFlexRootNode : WaffleFlexNode
--- @field width integer The root's available width.
--- @field height integer The root's available height.
--- @field defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame Creates a frame for any descendant (the root included) that gives neither `frame` nor its own `frameFactory`. `parent` is `nil` for the tree's actual root, nothing sits above it to pass in.

-- =============================================================================
-- Internal Data Table
-- =============================================================================

local _W = {}

-- =============================================================================
-- DeclarationOrder
-- =============================================================================

--- Assigns each child a permanent declaration order the first time it's
--- seen, used to break `order` ties. Weak keys, an unreferenced child can
--- still be garbage collected.
_W.DeclarationOrder = {
  next = 0,
  byChild = setmetatable({}, { __mode = "k" })
}

--- Returns `child`'s declaration order, `0` if not yet assigned.
--- @param child WaffleFlexNode
--- @return integer
function _W.DeclarationOrder:Get(child)
  return self.byChild[child] or 0
end

--- Assigns `child` the next declaration order. No-ops if it already has one.
--- @param child WaffleFlexNode
function _W.DeclarationOrder:Assign(child)
  if not self.byChild[child] then
    self.next = self.next + 1
    self.byChild[child] = self.next
  end
end

--- Clears `child`'s declaration order, so it's assigned a fresh one if
--- added again later.
--- @param child WaffleFlexNode
function _W.DeclarationOrder:Unassign(child)
  self.byChild[child] = nil
end

-- =============================================================================
-- Sort Functions
-- =============================================================================

--- Whether `childA` sorts before `childB`, by `order` then declaration order.
--- @param childA WaffleFlexNode
--- @param childB WaffleFlexNode
--- @return boolean
function _W.isFlexChildBefore(childA, childB)
  local orderA, orderB = childA.order or 0, childB.order or 0
  if orderA ~= orderB then
    return orderA < orderB
  end
  local decOrderA, decOrderB = _W.DeclarationOrder:Get(childA), _W.DeclarationOrder:Get(childB)
  return decOrderA < decOrderB
end

--- Sorts `children` in place by `order`, ties broken by declaration order.
--- Stable insertion sort.
--- @param children WaffleFlexNode[]
function _W.sortFlexChildren(children)
  for i = 2, #children do
    local child = children[i]
    local j = i - 1
    while j >= 1 and _W.isFlexChildBefore(child, children[j]) do
      children[j + 1] = children[j]
      j = j - 1
    end
    children[j + 1] = child
  end
end

-- =============================================================================
-- Frame Resolution
-- =============================================================================

--- Resolves `node.frame` in place, creating it via `frameFactory`/
--- `defaultFrameFactory` if neither was already given. `parent` is the
--- frame to hand the factory; `nil` for the tree's actual root, nothing
--- sits above it to pass in.
--- @param node WaffleFlexNode
--- @param parent WaffleFrame?
--- @param defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame
--- @return WaffleFrame
function _W.resolveFrame(node, parent, defaultFrameFactory)
  assert(not (node.frame and node.frameFactory),
    "Waffle: node cannot have both `frame` and `frameFactory`")

  if not node.frame then
    local factory = node.frameFactory or defaultFrameFactory
    assert(factory, "Waffle: node has no `frame` and no `frameFactory`/`defaultFrameFactory` was provided")
    node.frame = factory(parent)
    node.frameFactory = nil
  end

  return node.frame
end

-- =============================================================================
-- Layout Functions
-- =============================================================================

--- Positions `options.children` in a row or column within `options.frame`.
--- Children stretch to fill the cross axis (height for `ROW`, width for `COLUMN`).
--- `options.frame` must already be resolved and sized, the caller's
--- responsibility: `Layout()` for the tree's actual root, this same loop
--- for every other node, right before recursing into it.
--- @param options WaffleFlexRootNode
function _W.flexLayout(options)
  local children = options.children
  local gap = options.gap or 0
  local padding = options.padding or 0
  local isRow = (options.direction or "ROW"):upper() == "ROW"

  local mainSize = (isRow and options.width or options.height) - (padding * 2)
  local crossSize = (isRow and options.height or options.width) - (padding * 2)

  -- Sum fixed sizes and count flexible children among the visible ones, to
  -- split the space left over evenly. A hidden child is excluded from the
  -- layout flow entirely, its siblings reflow to fill the space. Also
  -- assigns a declaration order to new children.
  local fixedTotal = 0
  local flexCount = 0
  local visibleCount = 0
  for _, child in ipairs(children) do
    _W.DeclarationOrder:Assign(child)
    if not child.hidden then
      visibleCount = visibleCount + 1
      if child.size then
        fixedTotal = fixedTotal + child.size
      else
        flexCount = flexCount + 1
      end
    end
  end

  _W.sortFlexChildren(children)

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
      local frame = _W.resolveFrame(child, options.frame, options.defaultFrameFactory)

      frame:Show()
      frame:ClearAllPoints()
      frame:SetParent(options.frame)

      local size = child.size or flexSize
      local width, height

      if isRow then
        width, height = size, crossSize
        frame:SetPoint("TOPLEFT", options.frame, "TOPLEFT", mainOffset, -padding)
      else
        width, height = crossSize, size
        frame:SetPoint("TOPLEFT", options.frame, "TOPLEFT", padding, -mainOffset)
      end

      frame:SetWidth(width)
      frame:SetHeight(height)

      if child.children then
        _W.flexLayout({
          frame = frame,
          width = width,
          height = height,
          direction = child.direction,
          gap = child.gap,
          padding = child.padding,
          defaultFrameFactory = options.defaultFrameFactory,
          children = child.children,
        })
      end

      if child.onLayout then
        child.onLayout(frame, width, height)
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
--- @field package node WaffleFlexNode
_W.FlexComponent = {}
_W.FlexComponent.__index = _W.FlexComponent

--- Returns a table whose missing methods fall back to `FlexComponent`.
--- @return WaffleFlexComponent
function _W.newFlexComponent()
  return setmetatable({}, _W.FlexComponent)
end

--- Recursively searches `node` and its descendants, depth-first, for one
--- whose `key` matches, returning the first found.
--- @param node WaffleFlexNode
--- @param key string
--- @return WaffleFlexNode?
function _W.findFlexNodeByKey(node, key)
  if node.key == key then
    return node
  end
  if node.children then
    for _, child in ipairs(node.children) do
      local found = _W.findFlexNodeByKey(child, key)
      if found then
        return found
      end
    end
  end
end

--- Looks up a child anywhere in the tree by its `key`, erroring if none is found.
--- A duplicate key isn't validated against, the first match found wins.
--- @param key string
--- @return WaffleFlexComponentContainer | WaffleFlexComponentLeaf
function _W.FlexComponent:GetChild(key)
  local found = _W.findFlexNodeByKey(self.root.node, key)
  assert(found, "Waffle: no child registered under key '" .. key .. "'")
  if found.children then
    return _W.newFlexComponentContainer(found, self.root)
  else
    return _W.newFlexComponentLeaf(found, self.root)
  end
end

--- Returns `true` if this node is a container.
--- @return boolean
function _W.FlexComponent:IsContainer()
  return self.node.children ~= nil
end

--- Returns this node's frame, `nil` if not resolved yet, e.g. a
--- `frameFactory` not yet laid out.
--- @return WaffleFrame?
function _W.FlexComponent:GetFrame()
  return self.node.frame
end

--- Removes this node from the layout flow entirely, its siblings reflow to
--- fill the space. Its position in the tree is preserved, `Show()` brings
--- it back.
function _W.FlexComponent:Hide()
  if not self.node.hidden then
    self.node.hidden = true
    self.root.isDirty = true
  end
end

--- Reverses `Hide()`. No-ops if not currently hidden.
function _W.FlexComponent:Show()
  if self.node.hidden then
    self.node.hidden = false
    self.root.isDirty = true
  end
end

--- Sets the fixed size this node takes up within its parent. Pass
--- `nil` to remove a fixed size and let it flex again. No-ops if already
--- that size.
--- @param size? integer
function _W.FlexComponent:SetSize(size)
  if self.node.size ~= size then
    self.node.size = size
    self.root.isDirty = true
  end
end

--- Sets this node's visual position among its siblings, independent of
--- declaration order. Pass `nil` to reset to the default (`0`). No-ops if
--- already that order.
--- @param order? integer
function _W.FlexComponent:SetOrder(order)
  if self.node.order ~= order then
    self.node.order = order
    self.root.isDirty = true
  end
end

-- =============================================================================
-- FlexComponentLeaf
-- =============================================================================

--- Returned by `AddChild`. A leaf child; cannot have children of its own.
--- @class WaffleFlexComponentLeaf : WaffleFlexComponent
_W.FlexComponentLeaf = _W.newFlexComponent()
_W.FlexComponentLeaf.__index = _W.FlexComponentLeaf

--- @param node WaffleFlexNode
--- @param root WaffleFlexComponentContainer
--- @return WaffleFlexComponentLeaf
function _W.newFlexComponentLeaf(node, root)
  return setmetatable({ node = node, root = root }, _W.FlexComponentLeaf)
end

-- =============================================================================
-- FlexComponentContainer
-- =============================================================================

--- Returned by `Waffle:Flex()`. Composes a container's children fluently;
--- nothing runs until `Layout()` is called on the root container.
--- @class WaffleFlexComponentContainer : WaffleFlexComponent
--- @field package node WaffleFlexRootNode | WaffleFlexNode The full root shape, but only when this container is the tree's actual root.
--- @field package isDirty boolean Root only. Set by `AddChild`/`AddRow`/`AddColumn`; cleared by `Layout()`.
_W.FlexComponentContainer = _W.newFlexComponent()
_W.FlexComponentContainer.__index = _W.FlexComponentContainer

--- Constructs a container wrapping `node` as-is.
--- @param node WaffleFlexNode
--- @param root? WaffleFlexComponentContainer Omit for the root itself.
--- @return WaffleFlexComponentContainer
function _W.newFlexComponentContainer(node, root)
  node.children = node.children or {}
  local container = setmetatable({ node = node }, _W.FlexComponentContainer)
  container.root = root or container
  if root == nil then
    container.isDirty = true
  end
  return container
end

--- Appends a child as-is, returning its leaf.
--- @param child WaffleFlexNode
--- @return WaffleFlexComponentLeaf
function _W.FlexComponentContainer:AddChild(child)
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return _W.newFlexComponentLeaf(child, self.root)
end

--- Appends a new ROW container as a child, returning its container for further composition.
--- @param child? WaffleFlexNode
--- @return WaffleFlexComponentContainer
function _W.FlexComponentContainer:AddRow(child)
  child = child or {}
  child.direction = "ROW"
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return _W.newFlexComponentContainer(child, self.root)
end

--- Appends a new COLUMN container as a child, returning its container for further composition.
--- @param child? WaffleFlexNode
--- @return WaffleFlexComponentContainer
function _W.FlexComponentContainer:AddColumn(child)
  child = child or {}
  child.direction = "COLUMN"
  table.insert(self.node.children, child)
  self.root.isDirty = true
  return _W.newFlexComponentContainer(child, self.root)
end

--- Returns every one of this container's children, wrapped, in
--- declaration order. Doesn't recurse into grandchildren.
--- @return (WaffleFlexComponentContainer | WaffleFlexComponentLeaf)[]
function _W.FlexComponentContainer:GetChildren()
  local children = {}
  for i, node in ipairs(self.node.children) do
    if node.children then
      children[i] = _W.newFlexComponentContainer(node, self.root)
    else
      children[i] = _W.newFlexComponentLeaf(node, self.root)
    end
  end
  return children
end

--- Removes `child` from this container's children entirely, detaching it
--- from the tree rather than excluding it from layout the way `Hide()`
--- does. Doesn't touch `child`'s own `frame`. Returns `true` if found and
--- removed.
--- @param child WaffleFlexComponentContainer | WaffleFlexComponentLeaf
--- @return boolean removed
function _W.FlexComponentContainer:RemoveChild(child)
  for i, node in ipairs(self.node.children) do
    if node == child.node then
      table.remove(self.node.children, i)
      _W.DeclarationOrder:Unassign(node)
      self.root.isDirty = true
      return true
    end
  end
  return false
end

--- Removes every child from this container, same as calling `RemoveChild`
--- on each one. No-ops if already empty.
function _W.FlexComponentContainer:Clear()
  if #self.node.children == 0 then return end
  for _, node in ipairs(self.node.children) do
    _W.DeclarationOrder:Unassign(node)
  end
  self.node.children = {}
  self.root.isDirty = true
end

--- Sets the space between this container's children. No-ops if already
--- that gap.
--- @param gap? integer
function _W.FlexComponentContainer:SetGap(gap)
  if self.node.gap ~= gap then
    self.node.gap = gap
    self.root.isDirty = true
  end
end

--- Sets the space between this container's edge and its children, on all
--- four sides. No-ops if already that padding.
--- @param padding? integer
function _W.FlexComponentContainer:SetPadding(padding)
  if self.node.padding ~= padding then
    self.node.padding = padding
    self.root.isDirty = true
  end
end

--- Runs the layout for everything composed so far. Call only on the root
--- container, nested `AddRow`/`AddColumn` containers are laid out
--- automatically. No-ops if nothing changed since the last call.
function _W.FlexComponentContainer:Layout()
  if self.root.isDirty then
    local node = self.node

    if node.hidden then
      if node.frame then
        node.frame:Hide()
      end
    else
      local frame = _W.resolveFrame(node, nil, node.defaultFrameFactory)
      frame:Show()
      frame:SetWidth(node.width)
      frame:SetHeight(node.height)

      _W.flexLayout(node)

      if node.onLayout then
        node.onLayout(frame, node.width, node.height)
      end
    end

    self.root.isDirty = false
  end
end

-- =============================================================================
-- Waffle
-- =============================================================================

--- Starts composing a `Flex` container and returns it: call
--- `AddRow`/`AddColumn`/`AddChild` to populate it, then `Layout()` to run it.
--- For a fully declarative style, `options.children` may be given directly.
--- @param options WaffleFlexRootNode
--- @return WaffleFlexComponentContainer
function Waffle:Flex(options)
  return _W.newFlexComponentContainer(options)
end
