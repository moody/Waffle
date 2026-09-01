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
--- @field crossSize? integer Fixed size along the cross axis (height for `ROW`, width for `COLUMN`) this node takes up within its parent. Omitted nodes stretch to fill the full cross axis. Set directly or via `SetCrossSize()`. No effect on the tree's actual root, nothing sizes it from outside.
--- @field gap? integer Space between consecutive children, if this node has any. Default `0`.
--- @field padding? integer Space between this node's edge and its children, on all four sides, if it has any. Default `0`.
--- @field hidden? boolean Excludes this node from the layout flow entirely, its siblings reflow to fill the space, and its own frame is hidden. Default `false`. Set directly or via `Hide()`/`Show()`.
--- @field key? string Registers this node for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key isn't validated against, the first match found wins.
--- @field order? integer Visual position among siblings, independent of declaration order. Default `0`, ties broken by declaration order. Set directly or via `SetOrder()`. No effect on the tree's actual root, nothing orders it among siblings.
--- @field onLayout? fun(frame: WaffleFrame, width: integer, height: integer) Called with this node's frame and resolved width/height, after its `children` (if any) are laid out.
--- @field defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`. Does not apply to this node.

--- The root passed to `Waffle:Flex()`.
--- @class WaffleFlexRootNode : WaffleFlexNode
--- @field width integer The root's available width.
--- @field height integer The root's available height.

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
-- NodeParent
-- =============================================================================

--- Tracks each node's current parent, so its root can be found by walking
--- up live, instead of caching one and trusting it forever. Weak keys, an
--- unreferenced node can still be garbage collected.
_W.NodeParent = {
  byNode = setmetatable({}, { __mode = "k" })
}

--- Claims `node` as a child of `parent`. Errors if it already belongs to
--- a different one; call `RemoveChild()` on that one first to move it.
--- No-ops if `parent` already owns it, safe to call repeatedly, whether
--- that's `AddChild` called twice or the tree just being walked again.
--- @param node WaffleFlexNode
--- @param parent WaffleFlexNode
--- @return boolean claimed `true` if `node` wasn't already `parent`'s, `false` if this was a no-op.
function _W.NodeParent:Claim(node, parent)
  local currentParent = self.byNode[node]
  assert(not currentParent or currentParent == parent,
    "Waffle: child already belongs to another container, call RemoveChild() on it first to move it")
  self.byNode[node] = parent
  return currentParent == nil
end

--- Releases `node`, so it can be claimed by another parent.
--- @param node WaffleFlexNode
function _W.NodeParent:Release(node)
  self.byNode[node] = nil
end

--- Walks up from `node` to the tree's actual root node, the one with no
--- parent of its own.
--- @param node WaffleFlexNode
--- @return WaffleFlexRootNode
function _W.NodeParent:FindRoot(node)
  local parent = self.byNode[node]
  while parent do
    node = parent
    parent = self.byNode[node]
  end
  --- @cast node WaffleFlexRootNode
  return node
end

-- =============================================================================
-- DirtyRoots
-- =============================================================================

--- Which root nodes have changed since their last `Layout()` call. Weak
--- keys, an unreferenced root can still be garbage collected.
_W.DirtyRoots = setmetatable({}, { __mode = "k" })

--- Marks the tree containing `node` dirty, wherever its current root
--- actually is.
--- @param node WaffleFlexNode
function _W.markDirty(node)
  _W.DirtyRoots[_W.NodeParent:FindRoot(node)] = true
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

--- Positions `node.children` in a row or column within `frame`, sized to
--- `width`/`height`. A child stretches to fill the cross axis (height for
--- `ROW`, width for `COLUMN`) unless it gives its own fixed `crossSize`, in
--- which case it's sized to that instead, still anchored at the cross
--- axis's start. `frame` must already be resolved and sized by the caller:
--- `Layout()` for the tree's actual root, this same loop for every other
--- node, right before recursing into it.
--- @param node WaffleFlexNode
--- @param frame WaffleFrame
--- @param width integer
--- @param height integer
--- @param defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame
function _W.flexLayout(node, frame, width, height, defaultFrameFactory)
  local children = node.children
  local gap = node.gap or 0
  local padding = node.padding or 0
  local isRow = (node.direction or "ROW"):upper() == "ROW"

  local mainSize = (isRow and width or height) - (padding * 2)
  local crossSize = (isRow and height or width) - (padding * 2)

  -- Sum fixed sizes and count flexible children among the visible ones, to
  -- split the space left over evenly. A hidden child is excluded from the
  -- layout flow entirely, its siblings reflow to fill the space. Also
  -- assigns a declaration order and current parent to new children.
  local fixedTotal = 0
  local flexCount = 0
  local visibleCount = 0
  for _, child in ipairs(children) do
    _W.DeclarationOrder:Assign(child)
    _W.NodeParent:Claim(child, node)
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
      local childFrame = _W.resolveFrame(child, frame, defaultFrameFactory)

      childFrame:Show()
      childFrame:ClearAllPoints()
      childFrame:SetParent(frame)

      local size = child.size or flexSize
      local childCrossSize = child.crossSize or crossSize
      local childWidth, childHeight

      if isRow then
        childWidth, childHeight = size, childCrossSize
        childFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", mainOffset, -padding)
      else
        childWidth, childHeight = childCrossSize, size
        childFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -mainOffset)
      end

      childFrame:SetWidth(childWidth)
      childFrame:SetHeight(childHeight)

      if child.children then
        _W.flexLayout(child, childFrame, childWidth, childHeight, child.defaultFrameFactory or defaultFrameFactory)
      end

      if child.onLayout then
        child.onLayout(childFrame, childWidth, childHeight)
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
--- @field package node WaffleFlexNode
_W.FlexComponent = {}
_W.FlexComponent.__index = _W.FlexComponent

--- Returns a table whose missing methods fall back to `FlexComponent`.
--- @return WaffleFlexComponent
function _W.newFlexComponent()
  return setmetatable({}, _W.FlexComponent)
end

--- Recursively searches `node` and its descendants, depth-first, for one
--- whose `key` matches, returning the first found. Records itself as the
--- current parent of every node it visits along the way.
--- @param node WaffleFlexNode
--- @param key string
--- @return WaffleFlexNode?
function _W.findFlexNodeByKey(node, key)
  if node.key == key then
    return node
  end
  if node.children then
    for _, child in ipairs(node.children) do
      _W.NodeParent:Claim(child, node)
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
  local root = _W.NodeParent:FindRoot(self.node)
  local found = _W.findFlexNodeByKey(root, key)
  assert(found, "Waffle: no child registered under key '" .. key .. "'")
  if found.children then
    return _W.newFlexComponentContainer(found)
  else
    return _W.newFlexComponentLeaf(found)
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

--- Returns `true` if this node's tree has changed since its last
--- `Layout()` call.
--- @return boolean
function _W.FlexComponent:IsDirty()
  return _W.DirtyRoots[_W.NodeParent:FindRoot(self.node)] == true
end

--- Removes this node from the layout flow entirely, its siblings reflow to
--- fill the space. Its position in the tree is preserved, `Show()` brings
--- it back.
function _W.FlexComponent:Hide()
  if not self.node.hidden then
    self.node.hidden = true
    _W.markDirty(self.node)
  end
end

--- Reverses `Hide()`. No-ops if not currently hidden.
function _W.FlexComponent:Show()
  if self.node.hidden then
    self.node.hidden = false
    _W.markDirty(self.node)
  end
end

--- Sets the fixed size this node takes up within its parent. Pass
--- `nil` to remove a fixed size and let it flex again. No-ops if already
--- that size.
--- @param size? integer
function _W.FlexComponent:SetSize(size)
  if self.node.size ~= size then
    self.node.size = size
    _W.markDirty(self.node)
  end
end

--- Sets the fixed size this node takes up within its parent along the
--- cross axis. Pass `nil` to remove a fixed cross size and let it stretch
--- again. No-ops if already that size.
--- @param crossSize? integer
function _W.FlexComponent:SetCrossSize(crossSize)
  if self.node.crossSize ~= crossSize then
    self.node.crossSize = crossSize
    _W.markDirty(self.node)
  end
end

--- Sets this node's visual position among its siblings, independent of
--- declaration order. Pass `nil` to reset to the default (`0`). No-ops if
--- already that order.
--- @param order? integer
function _W.FlexComponent:SetOrder(order)
  if self.node.order ~= order then
    self.node.order = order
    _W.markDirty(self.node)
  end
end

--- Runs the layout for the tree containing this node, starting from its
--- actual current root, wherever that currently is. No-ops if nothing's
--- changed since the last call.
function _W.FlexComponent:Layout()
  local root = _W.NodeParent:FindRoot(self.node)
  if _W.DirtyRoots[root] then
    if root.hidden then
      if root.frame then
        root.frame:Hide()
      end
    else
      local frame = _W.resolveFrame(root)
      frame:Show()
      frame:SetWidth(root.width)
      frame:SetHeight(root.height)

      _W.flexLayout(root, frame, root.width, root.height, root.defaultFrameFactory)

      if root.onLayout then
        root.onLayout(frame, root.width, root.height)
      end
    end

    _W.DirtyRoots[root] = nil
  end
end

-- =============================================================================
-- FlexComponentLeaf
-- =============================================================================

--- Returned by `AddChild`. A leaf child; cannot have children.
--- @class WaffleFlexComponentLeaf : WaffleFlexComponent
_W.FlexComponentLeaf = _W.newFlexComponent()
_W.FlexComponentLeaf.__index = _W.FlexComponentLeaf

--- @param node WaffleFlexNode
--- @return WaffleFlexComponentLeaf
function _W.newFlexComponentLeaf(node)
  return setmetatable({ node = node }, _W.FlexComponentLeaf)
end

-- =============================================================================
-- FlexComponentContainer
-- =============================================================================

--- Returned by `Waffle:Flex()`. Composes a container's children fluently;
--- nothing runs until `Layout()` is called.
--- @class WaffleFlexComponentContainer : WaffleFlexComponent
_W.FlexComponentContainer = _W.newFlexComponent()
_W.FlexComponentContainer.__index = _W.FlexComponentContainer

--- Constructs a container wrapping `node` as-is.
--- @param node WaffleFlexNode
--- @return WaffleFlexComponentContainer
function _W.newFlexComponentContainer(node)
  node.children = node.children or {}
  return setmetatable({ node = node }, _W.FlexComponentContainer)
end

--- Appends a child as-is, returning its wrapper: a container if `child`
--- already has its own `children`, a leaf otherwise. Errors if `child`
--- already belongs to a different container, call `RemoveChild()` on that
--- one first to move it here. No-ops (beyond returning a fresh wrapper) if
--- `child` is already this container's own.
--- @param child WaffleFlexNode
--- @return WaffleFlexComponentContainer | WaffleFlexComponentLeaf
function _W.FlexComponentContainer:AddChild(child)
  if _W.NodeParent:Claim(child, self.node) then
    table.insert(self.node.children, child)
    _W.markDirty(self.node)
  end
  if child.children then
    return _W.newFlexComponentContainer(child)
  else
    return _W.newFlexComponentLeaf(child)
  end
end

--- Appends a new ROW container as a child, returning its container for
--- further composition. Errors if `child` already belongs to a different
--- container, call `RemoveChild()` on that one first to move it here.
--- No-ops (beyond returning a fresh wrapper) if `child` is already this
--- container's own.
--- @param child? WaffleFlexNode
--- @return WaffleFlexComponentContainer
function _W.FlexComponentContainer:AddRow(child)
  child = child or {}
  child.direction = "ROW"
  if _W.NodeParent:Claim(child, self.node) then
    table.insert(self.node.children, child)
    _W.markDirty(self.node)
  end
  return _W.newFlexComponentContainer(child)
end

--- Appends a new COLUMN container as a child, returning its container for
--- further composition. Errors if `child` already belongs to a different
--- container, call `RemoveChild()` on that one first to move it here.
--- No-ops (beyond returning a fresh wrapper) if `child` is already this
--- container's own.
--- @param child? WaffleFlexNode
--- @return WaffleFlexComponentContainer
function _W.FlexComponentContainer:AddColumn(child)
  child = child or {}
  child.direction = "COLUMN"
  if _W.NodeParent:Claim(child, self.node) then
    table.insert(self.node.children, child)
    _W.markDirty(self.node)
  end
  return _W.newFlexComponentContainer(child)
end

--- Returns every one of this container's children, wrapped, in
--- declaration order. Doesn't recurse into grandchildren.
--- @return (WaffleFlexComponentContainer | WaffleFlexComponentLeaf)[]
function _W.FlexComponentContainer:GetChildren()
  local children = {}
  for i, node in ipairs(self.node.children) do
    _W.NodeParent:Claim(node, self.node)
    if node.children then
      children[i] = _W.newFlexComponentContainer(node)
    else
      children[i] = _W.newFlexComponentLeaf(node)
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
      _W.NodeParent:Release(node)
      _W.markDirty(self.node)
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
    _W.NodeParent:Release(node)
  end
  self.node.children = {}
  _W.markDirty(self.node)
end

--- Sets the space between this container's children. No-ops if already
--- that gap.
--- @param gap? integer
function _W.FlexComponentContainer:SetGap(gap)
  if self.node.gap ~= gap then
    self.node.gap = gap
    _W.markDirty(self.node)
  end
end

--- Sets the space between this container's edge and its children, on all
--- four sides. No-ops if already that padding.
--- @param padding? integer
function _W.FlexComponentContainer:SetPadding(padding)
  if self.node.padding ~= padding then
    self.node.padding = padding
    _W.markDirty(self.node)
  end
end

-- =============================================================================
-- Waffle
-- =============================================================================

--- Starts composing a `Flex` container and returns it: call
--- `AddRow`/`AddColumn`/`AddChild` to populate it, then `Layout()` to run it.
--- For a fully declarative style, `rootNode.children` may be given directly.
--- @param rootNode WaffleFlexRootNode
--- @return WaffleFlexComponentContainer
function Waffle:Flex(rootNode)
  _W.DirtyRoots[rootNode] = true
  return _W.newFlexComponentContainer(rootNode)
end
