-- =============================================================================
-- Waffle: 0.3.0 - https://github.com/moody/Waffle
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
--- @alias WaffleFlexAlign "START" | "CENTER" | "END" | "STRETCH"
--- @alias WaffleFlexJustify "START" | "CENTER" | "END" | "SPACE_BETWEEN" | "SPACE_AROUND" | "SPACE_EVENLY"

--- Properties shared by every node in the tree, root included. The plain
--- data tables Waffle operates on.
--- @class WaffleFlexNode
--- @field frame? WaffleFrame An already-built frame, handed over as-is. Cannot be given together with `frameFactory`.
--- @field frameFactory? fun(parent: WaffleFrame): WaffleFrame Creates this node's own frame, once. Cannot be given together with `frame`. `parent` is `nil` for the tree's actual root, nothing sits above it to pass in.
--- @field children? WaffleFlexNode[] Children positioned within this node, in a row or column depending on `direction`.
--- @field direction? WaffleFlexDirection Default `ROW`.
--- @field align? WaffleFlexAlign How this node aligns its own children along the cross axis, if it has any. Default `STRETCH`. A child overrides this for itself via its own `alignSelf`. Set directly or via `SetAlign()`.
--- @field justify? WaffleFlexJustify How this node distributes leftover main-axis space among its own children, if it has any and none of them are flexible (a flexible child already consumes all leftover space, there's nothing left for this to distribute). Default `START`. Set directly or via `SetJustify()`.
--- @field width? integer | "AUTO" This node's own physical width, always horizontal, regardless of `direction`. Used directly as a fixed size, whether that's this node's own main-axis size within its parent (`direction` is `ROW` there) or its cross-axis size (parent's `direction` is `COLUMN`; required if resolved to a non-`STRETCH` alignment there, ignored, falling back to stretching, when `STRETCH`). Omitted, flexes/stretches instead, whichever applies. `"AUTO"` computes it as the sum of this node's own children's own `width` (plus `gap`/`padding`), only legal when `width` is this node's own main axis (`direction` is `ROW`); every visible child needs its own number or `"AUTO"`, a flexible child errors, there's no space yet to split. Set directly or via `SetWidth()`.
--- @field height? integer | "AUTO" This node's own physical height, always vertical. Same as `width` in every other respect; `"AUTO"` only legal when `direction` is `COLUMN`. Set directly or via `SetHeight()`.
--- @field alignSelf? WaffleFlexAlign Overrides the parent's `align` for this node specifically. Unset, inherits the parent's `align` (`STRETCH` if that's also unset). Set directly or via `SetAlignSelf()`. No effect on the tree's actual root, nothing aligns it within a parent.
--- @field gap? integer Space between consecutive children, if this node has any. Default `0`.
--- @field padding? integer Space between this node's edge and its children, on all four sides, if it has any. Default `0`.
--- @field hidden? boolean Excludes this node from the layout flow entirely, its siblings reflow to fill the space, and its own frame is hidden. Default `false`. Set directly or via `Hide()`/`Show()`.
--- @field key? string Registers this node for lookup via `GetChild(key)` from anywhere in the tree. A duplicate key isn't validated against, the first match found wins.
--- @field order? integer Visual position among siblings, independent of declaration order. Default `0`, ties broken by declaration order. Set directly or via `SetOrder()`. No effect on the tree's actual root, nothing orders it among siblings.
--- @field onLayout? fun(frame: WaffleFrame, width: integer, height: integer) Called with this node's frame and resolved width/height, after its `children` (if any) are laid out.
--- @field defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame Creates a frame for any descendant that gives neither `frame` nor its own `frameFactory`. Does not apply to this node.

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
--- @return WaffleFlexNode
function _W.NodeParent:FindRoot(node)
  local parent = self.byNode[node]
  while parent do
    node = parent
    parent = self.byNode[node]
  end
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
-- Auto Sizing
-- =============================================================================

--- Computes `node`'s own size along `axis` ("width" or "height", its own
--- main axis, given its own `direction`) from its children: the sum of
--- their own resolved sizes along that SAME physical axis (recursively
--- resolving any child of its own that's also `"AUTO"` there), plus `gap`
--- between them and `padding` on both ends. Errors if any visible child is
--- flexible along `axis`, there's no space yet for it to split.
--- @param node WaffleFlexNode
--- @param axis "width" | "height"
--- @return integer
function _W.computeAutoSize(node, axis)
  assert(node.children, "Waffle: `\"AUTO\"` needs `children` to compute a size from")

  local gap = node.gap or 0
  local padding = node.padding or 0
  local total = 0
  local visibleCount = 0

  for _, child in ipairs(node.children) do
    if not child.hidden then
      visibleCount = visibleCount + 1
      local size = _W.resolveDimension(child, axis)
      assert(size,
        "Waffle: every visible child of an `\"AUTO\"` node needs its own `" ..
        axis .. "`, a flexible child (`nil`) has nothing to split, there's no space yet to split")
      total = total + size
    end
  end

  return total + gap * math.max(visibleCount - 1, 0) + padding * 2
end

--- Resolves `node`'s own fixed size along the physical `axis` ("width" or
--- "height"): the given number, computed from its children if `"AUTO"`
--- (only legal when `axis` is `node`'s own main axis, given its own
--- `direction`; errors otherwise, auto-sizing the cross axis isn't
--- supported yet), or `nil` if `node` is flexible along `axis` instead,
--- the normal case, splitting whatever's left over among the other
--- flexible children of whoever's asking.
--- @param node WaffleFlexNode
--- @param axis "width" | "height"
--- @return integer?
function _W.resolveDimension(node, axis)
  local value = node[axis]
  if value == "AUTO" then
    local isMainAxis = ((node.direction or "ROW"):upper() == "ROW") == (axis == "width")
    assert(isMainAxis,
      "Waffle: `\"AUTO\"` on `" ..
      axis ..
      "` needs it to be this node's own main axis (given its `direction`), auto-sizing the cross axis isn't supported yet")
    return _W.computeAutoSize(node, axis)
  end
  return value
end

-- =============================================================================
-- Layout Functions
-- =============================================================================

--- Positions `node.children` in a row or column within `frame`, sized to
--- `width`/`height`. A child's own main-axis size (`resolveDimension`,
--- along whichever physical axis `node`'s own `direction` treats as main)
--- is either that axis's own number, computed from the child's own
--- children if `"AUTO"`, or `nil`, flexible, splitting whatever's left
--- over evenly with any other flexible siblings. A child's cross-axis
--- alignment (its own `alignSelf`, else `node.align`, else `STRETCH`)
--- decides both its cross-axis size and where it sits: `STRETCH` fills the
--- cross axis, falling back to it only when the child gives no value of
--- its own along that axis; any other alignment requires the child's own
--- value there (errors otherwise) and positions it at the cross axis's
--- start, center, or end accordingly. `node.justify` distributes any
--- leftover main-axis space (only meaningful when nothing is flexible, a
--- flexible child already consumes it all) among the children instead of
--- leaving it unused after the last one. `frame` must already be resolved
--- and sized by the caller: `Layout()` for the tree's actual root, this
--- same loop for every other node, right before recursing into it.
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
  local mainAxis = isRow and "width" or "height"
  local crossAxis = isRow and "height" or "width"

  local mainSize = (isRow and width or height) - (padding * 2)
  local crossSize = (isRow and height or width) - (padding * 2)

  -- Sum fixed (or auto-computed) sizes and count flexible children among
  -- the visible ones, to split the space left over evenly. A hidden child
  -- is excluded from the layout flow entirely, its siblings reflow to fill
  -- the space. Also assigns a declaration order and current parent to new
  -- children.
  local fixedTotal = 0
  local flexCount = 0
  local visibleCount = 0
  for _, child in ipairs(children) do
    _W.DeclarationOrder:Assign(child)
    _W.NodeParent:Claim(child, node)
    if not child.hidden then
      visibleCount = visibleCount + 1
      local size = _W.resolveDimension(child, mainAxis)
      if size then
        fixedTotal = fixedTotal + size
      else
        flexCount = flexCount + 1
      end
    end
  end

  _W.sortFlexChildren(children)

  local totalGap = gap * math.max(visibleCount - 1, 0)
  local remaining = mainSize - fixedTotal - totalGap
  local flexSize = flexCount > 0 and math.max(remaining / flexCount, 0) or 0

  -- `justify` only has leftover space to distribute when nothing is
  -- flexible, a flexible child already consumes all of `remaining` via
  -- `flexSize` above.
  local justifyOffset, justifyGap = 0, 0
  if flexCount == 0 then
    local leftover = math.max(remaining, 0)
    local justify = (node.justify or "START"):upper()
    if justify == "END" then
      justifyOffset = leftover
    elseif justify == "CENTER" then
      justifyOffset = leftover / 2
    elseif justify == "SPACE_BETWEEN" and visibleCount > 1 then
      justifyGap = leftover / (visibleCount - 1)
    elseif justify == "SPACE_AROUND" and visibleCount > 0 then
      justifyGap = leftover / visibleCount
      justifyOffset = justifyGap / 2
    elseif justify == "SPACE_EVENLY" then
      justifyGap = leftover / (visibleCount + 1)
      justifyOffset = justifyGap
    end
  end

  local mainOffset = padding + justifyOffset
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

      local size = _W.resolveDimension(child, mainAxis) or flexSize

      local align = (child.alignSelf or node.align or "STRETCH"):upper()
      local childCrossSize
      if align == "STRETCH" then
        childCrossSize = _W.resolveDimension(child, crossAxis) or crossSize
      else
        childCrossSize = _W.resolveDimension(child, crossAxis)
        assert(childCrossSize,
          "Waffle: a child aligned '" ..
          align ..
          "' (not STRETCH) needs its own `" ..
          crossAxis .. "`, alignment doesn't fall back to the container's cross size")
      end

      local crossOffset = padding
      if align == "CENTER" then
        crossOffset = padding + (crossSize - childCrossSize) / 2
      elseif align == "END" then
        crossOffset = padding + (crossSize - childCrossSize)
      end

      local childWidth, childHeight

      if isRow then
        childWidth, childHeight = size, childCrossSize
        childFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", mainOffset, -crossOffset)
      else
        childWidth, childHeight = childCrossSize, size
        childFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", crossOffset, -mainOffset)
      end

      childFrame:SetWidth(childWidth)
      childFrame:SetHeight(childHeight)

      if child.children then
        _W.flexLayout(child, childFrame, childWidth, childHeight, child.defaultFrameFactory or defaultFrameFactory)
      end

      if child.onLayout then
        child.onLayout(childFrame, childWidth, childHeight)
      end

      mainOffset = mainOffset + size + gap + justifyGap
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

--- Sets this node's own physical width. Pass `nil` to let it flex/stretch
--- instead (whichever applies), or `"AUTO"` to compute it from this
--- node's own children instead (only legal when `width` is this node's
--- own main axis, `direction` is `ROW`). No-ops if already that value.
--- @param width? integer | "AUTO"
function _W.FlexComponent:SetWidth(width)
  if self.node.width ~= width then
    self.node.width = width
    _W.markDirty(self.node)
  end
end

--- Sets this node's own physical height. Same as `SetWidth()`, the
--- vertical axis instead; `"AUTO"` only legal when `direction` is
--- `COLUMN`. No-ops if already that value.
--- @param height? integer | "AUTO"
function _W.FlexComponent:SetHeight(height)
  if self.node.height ~= height then
    self.node.height = height
    _W.markDirty(self.node)
  end
end

--- Sets how this node aligns itself within its parent along the cross
--- axis, overriding the parent's own `align`. Pass `nil` to go back to
--- inheriting it. No-ops if already that alignment.
--- @param alignSelf? WaffleFlexAlign
function _W.FlexComponent:SetAlignSelf(alignSelf)
  if self.node.alignSelf ~= alignSelf then
    self.node.alignSelf = alignSelf
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

      -- The root resolves its own width/height exactly the same way any
      -- node resolves a child's: `resolveDimension` already only allows
      -- `"AUTO"` along a node's own main axis (given its own `direction`),
      -- so the cross axis correctly stays a required real number here too,
      -- with no root-specific logic needed to enforce that separately.
      local width = _W.resolveDimension(root, "width")
      local height = _W.resolveDimension(root, "height")
      assert(width,
        "Waffle: root needs its own `width`, or `\"AUTO\"` if `direction` is ROW, nothing above it to resolve one automatically")
      assert(height,
        "Waffle: root needs its own `height`, or `\"AUTO\"` if `direction` is COLUMN, nothing above it to resolve one automatically")

      frame:SetWidth(width)
      frame:SetHeight(height)

      _W.flexLayout(root, frame, width, height, root.defaultFrameFactory)

      if root.onLayout then
        root.onLayout(frame, width, height)
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

--- Sets how this container aligns its own children along the cross axis
--- by default, unless a given child overrides it with its own
--- `alignSelf`. Pass `nil` to reset to the default (`STRETCH`). No-ops if
--- already that alignment.
--- @param align? WaffleFlexAlign
function _W.FlexComponentContainer:SetAlign(align)
  if self.node.align ~= align then
    self.node.align = align
    _W.markDirty(self.node)
  end
end

--- Sets how this container distributes leftover main-axis space among its
--- own children. Pass `nil` to reset to the default (`START`). No-ops if
--- already that value.
--- @param justify? WaffleFlexJustify
function _W.FlexComponentContainer:SetJustify(justify)
  if self.node.justify ~= justify then
    self.node.justify = justify
    _W.markDirty(self.node)
  end
end

-- =============================================================================
-- Waffle
-- =============================================================================

--- Starts composing a `Flex` container and returns it: call
--- `AddRow`/`AddColumn`/`AddChild` to populate it, then `Layout()` to run it.
--- For a fully declarative style, `node.children` may be given directly.
--- @param node WaffleFlexNode
--- @return WaffleFlexComponentContainer
function Waffle:Flex(node)
  _W.DirtyRoots[node] = true
  return _W.newFlexComponentContainer(node)
end
