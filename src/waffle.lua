-- =============================================================================
-- Waffle: 0.4.0 - https://github.com/moody/Waffle
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

--- Shared by every node in the tree, root included.
--- @class WaffleFlexNode
--- @field frame? WaffleFrame Cannot be given together with `frameFactory`.
--- @field frameFactory? fun(parent: WaffleFrame): WaffleFrame Cannot be given together with `frame`. `parent` is `nil` for the root, nothing sits above it to pass in.
--- @field children? WaffleFlexNode[] Positioned in a row or column, per `direction`.
--- @field direction? WaffleFlexDirection Default `ROW`.
--- @field align? WaffleFlexAlign Cross-axis alignment for this node's own children. Default `STRETCH`. A child's own `alignSelf` overrides this.
--- @field justify? WaffleFlexJustify Main-axis distribution of leftover space among this node's own children. Default `START`. No effect if any child has a positive `grow` share, it already claims the leftover space.
--- @field width? integer | "AUTO" Always physical/horizontal, regardless of `direction`. `"AUTO"` sums this node's own children's own `width` along its main axis (`direction` is `ROW`), maxes them along its cross axis instead.
--- @field height? integer | "AUTO" Same as `width`, vertical instead; sums along its main axis when `direction` is `COLUMN`, maxes along its cross axis otherwise.
--- @field grow? number This node's own share of its parent's leftover main-axis space, relative to its equally-flexible siblings. Default `1`. No effect on a node with its own explicit main-axis `width`/`height`, or on the root.
--- @field alignSelf? WaffleFlexAlign Overrides the parent's `align`. No effect on the root.
--- @field wrap? boolean Overflowing children start a new line instead of continuing past the main axis size. Each line gets its own cross-size (a max over its own children) and stacks after the previous one, `gap` between lines too. Default `false`.
--- @field gap? integer Between children only, not the edges. Default `0`.
--- @field padding? integer On all four sides. Default `0`.
--- @field hidden? boolean Excludes this node from layout entirely; siblings reflow to fill the space. Default `false`.
--- @field key? string For lookup via `GetChild(key)`. Duplicate keys aren't validated against, the first match wins.
--- @field order? integer Visual position among siblings, independent of declaration order. Default `0`, ties broken by declaration order. No effect on the root.
--- @field onLayout? fun(frame: WaffleFrame, width: integer, height: integer) Fires after `children` (if any) are already laid out.
--- @field defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame Applies to descendants only, not this node itself.

-- =============================================================================
-- Internal Data Table
-- =============================================================================

local _W = {}

-- =============================================================================
-- DeclarationOrder
-- =============================================================================

--- Used to break `order` ties. Weak keys so an unreferenced child can still
--- be garbage collected.
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

--- Tracks each node's current parent, found by walking up live on every
--- call rather than caching one, so a moved node's wrapper is never
--- stale. Weak keys so an unreferenced node can still be garbage collected.
_W.NodeParent = {
  byNode = setmetatable({}, { __mode = "k" })
}

--- Claims `node` as a child of `parent`. Errors if it already belongs to
--- a different one, call `RemoveChild()` on that one first to move it.
--- No-ops if `parent` already owns it.
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

--- Walks up to the tree's actual root, the node with no parent of its own.
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

--- Marks the tree containing `node` dirty, wherever its current root is.
--- @param node WaffleFlexNode
function _W.markDirty(node)
  _W.DirtyRoots[_W.NodeParent:FindRoot(node)] = true
end

-- =============================================================================
-- Cache
-- =============================================================================

--- Internal memoization and table reuse for `Layout()`.
_W.Cache = {}

--- A wrap node's own children, already split into lines by
--- `computeAutoCrossSize`, for `flexLayout` to reuse instead of
--- splitting them again right after. Weak keys so an unreferenced node
--- can still be garbage collected.
_W.Cache.WrapLines = setmetatable({}, { __mode = "k" })

--- Bumped once per `Layout()` pass (see `FlexComponent:Layout()`).
--- Scopes `ResolvedDimensions` entries to the pass that computed them,
--- so a stale one from an earlier pass is never reused.
_W.Cache.CurrentPass = 0

--- `node`'s own `"AUTO"` result per axis, tagged with the pass that
--- computed it. Weak keys so an unreferenced node can still be garbage
--- collected.
_W.Cache.ResolvedDimensions = setmetatable({}, { __mode = "k" })

--- `node`'s own children, sorted for positioning, one persistent table
--- per node reused across every `Layout()` call instead of allocated
--- fresh each time. Weak keys so an unreferenced node can still be
--- garbage collected.
_W.Cache.SortedChildren = setmetatable({}, { __mode = "k" })

--- `node`'s own visible (non-hidden) children, same reuse as
--- `SortedChildren` and for the same reason.
_W.Cache.VisibleChildren = setmetatable({}, { __mode = "k" })

--- Returns `node`'s cached `"AUTO"` result for `axis`, `nil` if it was
--- never computed or is from a stale pass.
--- @param node WaffleFlexNode
--- @param axis "width" | "height"
--- @return integer?
function _W.Cache:GetResolvedDimension(node, axis)
  local entry = self.ResolvedDimensions[node]
  if entry and entry.pass == self.CurrentPass then
    return entry[axis]
  end
  return nil
end

--- Records `node`'s `"AUTO"` result for `axis` for the rest of the
--- current pass. Reuses `node`'s own existing entry rather than
--- allocating a new one, resetting it first if it's from a stale pass.
--- @param node WaffleFlexNode
--- @param axis "width" | "height"
--- @param value integer
function _W.Cache:SetResolvedDimension(node, axis, value)
  local entry = self.ResolvedDimensions[node]
  if not entry then
    entry = { pass = self.CurrentPass }
    self.ResolvedDimensions[node] = entry
  elseif entry.pass ~= self.CurrentPass then
    entry.pass = self.CurrentPass
    entry.width = nil
    entry.height = nil
  end
  entry[axis] = value
end

--- Returns and clears `node`'s cached wrap lines, even if the caller
--- ends up not using them.
--- @param node WaffleFlexNode
--- @return WaffleFlexNode[][]?
function _W.Cache:GetWrapLines(node)
  local lines = self.WrapLines[node]
  self.WrapLines[node] = nil
  return lines
end

--- Records `node`'s wrap lines for `flexLayout` to take right after.
--- @param node WaffleFlexNode
--- @param lines WaffleFlexNode[][]
function _W.Cache:SetWrapLines(node, lines)
  self.WrapLines[node] = lines
end

--- Returns `node`'s own table in `pool` (`SortedChildren`/
--- `VisibleChildren` above), creating it on the first ask. Never
--- replaced once created; callers overwrite it by index and finish
--- with `Truncate` below.
--- @param pool table<WaffleFlexNode, WaffleFlexNode[]>
--- @param node WaffleFlexNode
--- @return WaffleFlexNode[]
function _W.Cache:GetReusableTable(pool, node)
  local t = pool[node]
  if not t then
    t = {}
    pool[node] = t
  end
  return t
end

--- Clears every entry in `t` past index `count`, so reusing it for a
--- shorter list than last time doesn't leave stale entries past its new
--- logical length.
--- @param t table
--- @param count integer
function _W.Cache:Truncate(t, count)
  for i = count + 1, #t do
    t[i] = nil
  end
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

--- Sorts `children` in place by `order`, ties broken by declaration
--- order. Custom insertion sort, not `table.sort`: Lua's built-in sort
--- isn't guaranteed stable, which would risk reshuffling those ties.
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
--- `defaultFrameFactory` if neither was already given. `parent` is `nil`
--- for the root, nothing sits above it to hand a factory.
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

--- Computes `node`'s size along its own main axis (`axis`) as the sum of
--- its children's own sizes along that same axis, plus `gap` between them
--- and `padding` on both ends. Errors if any visible child is flexible,
--- there's no space yet for it to split.
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

--- The max of every one of `children`'s own resolved sizes along `axis`.
--- Errors if any is flexible, there's nothing of its own to measure.
--- The strict counterpart to `lineCrossSize`, which falls back instead.
--- @param children WaffleFlexNode[]
--- @param axis "width" | "height"
--- @return integer
function _W.maxCrossSize(children, axis)
  local max = 0
  for _, child in ipairs(children) do
    local size = _W.resolveDimension(child, axis)
    assert(size,
      "Waffle: every visible child of an `\"AUTO\"` node needs its own `" ..
      axis .. "`, a flexible child (`nil`) has nothing of its own to measure")
    max = math.max(max, size)
  end
  return max
end

--- Computes `node`'s size along its own cross axis (`axis`) as the sum
--- of every line's own `maxCrossSize`, plus `gap` between lines and
--- `padding` on both ends. One line, a flat max with no `gap` term,
--- unless `node.wrap` is set and its own main axis resolves to a number
--- to wrap against.
--- @param node WaffleFlexNode
--- @param axis "width" | "height"
--- @return integer
function _W.computeAutoCrossSize(node, axis)
  assert(node.children, "Waffle: `\"AUTO\"` needs `children` to compute a cross size from")

  local gap = node.gap or 0
  local padding = node.padding or 0

  local visibleChildren = {}
  for _, child in ipairs(node.children) do
    if not child.hidden then
      table.insert(visibleChildren, child)
    end
  end

  local lines = { visibleChildren }
  if node.wrap then
    local mainAxis = axis == "width" and "height" or "width"
    local mainSize = _W.resolveDimension(node, mainAxis)
    if mainSize then
      -- Lines have to match what `flexLayout` will actually produce, which
      -- sorts before splitting; without this, a child moved earlier by
      -- `order` could land on a different line here than it really will.
      _W.sortFlexChildren(visibleChildren)
      lines = _W.splitFlexLines(visibleChildren, mainAxis, mainSize, gap)

      -- Cached for `node`'s own upcoming `flexLayout` call, which would
      -- otherwise redo this same sort and split.
      _W.Cache:SetWrapLines(node, lines)
    end
  end

  local total = 0
  for _, lineChildren in ipairs(lines) do
    total = total + _W.maxCrossSize(lineChildren, axis)
  end

  return total + gap * math.max(#lines - 1, 0) + padding * 2
end

--- A line's own cross-size: the max of every child's own resolved size
--- along `axis` that has one, skipping any that don't (e.g. a STRETCH
--- child on its cross axis) rather than erroring. `fallback` covers a
--- line with nothing explicit at all.
--- @param children WaffleFlexNode[]
--- @param axis "width" | "height"
--- @param fallback integer
--- @return integer
function _W.lineCrossSize(children, axis, fallback)
  local max
  for _, child in ipairs(children) do
    local size = _W.resolveDimension(child, axis)
    if size then
      max = max and math.max(max, size) or size
    end
  end
  return max or fallback
end

--- Resolves `node`'s size along `axis`: the given number, computed from
--- its children if `"AUTO"` (a sum along `node`'s own main axis, a max
--- along its cross axis), or `nil` if `node` is flexible along `axis`
--- instead. An `"AUTO"` result is cached for the rest of the current pass.
--- @param node WaffleFlexNode
--- @param axis "width" | "height"
--- @return integer?
function _W.resolveDimension(node, axis)
  local value = node[axis]
  if value == "AUTO" then
    local cached = _W.Cache:GetResolvedDimension(node, axis)
    if cached == nil then
      local isMainAxis = ((node.direction or "ROW"):upper() == "ROW") == (axis == "width")
      cached = isMainAxis and _W.computeAutoSize(node, axis) or _W.computeAutoCrossSize(node, axis)
      _W.Cache:SetResolvedDimension(node, axis, cached)
    end

    return cached
  end
  return value
end

-- =============================================================================
-- Layout Functions
-- =============================================================================

--- Splits `children` (already sorted, already visible-only) into lines
--- along `axis`: each line is as many children as fit within `mainSize`,
--- in order. A fixed-size child that would overflow the current line
--- starts a new one instead, unless the current line is still empty, a
--- lone child bigger than `mainSize` still gets placed on one rather than
--- looping forever. A flexible child (no fixed size of its own yet)
--- always joins the current line, there's nothing of its own yet to check
--- for overflow.
--- @param children WaffleFlexNode[]
--- @param axis "width" | "height"
--- @param mainSize integer
--- @param gap integer
--- @return WaffleFlexNode[][]
function _W.splitFlexLines(children, axis, mainSize, gap)
  local lines = {}
  local currentLine = {}
  local currentLineTotal = 0

  for _, child in ipairs(children) do
    local size = _W.resolveDimension(child, axis)
    if size and #currentLine > 0 and currentLineTotal + gap + size > mainSize then
      table.insert(lines, currentLine)
      currentLine = {}
      currentLineTotal = 0
    end

    table.insert(currentLine, child)
    if size then
      currentLineTotal = currentLineTotal + size + (#currentLine > 1 and gap or 0)
    end
  end

  if #currentLine > 0 then
    table.insert(lines, currentLine)
  end

  return lines
end

--- Positions `lineChildren` along `mainAxis`, starting at `mainStart`, and
--- aligns each within `crossSize` starting at `crossStart`. One line is
--- every one of `node.children` when `node.wrap` isn't set, or one
--- wrapped line's worth of them when it is. Non-STRETCH alignment
--- requires the child's own cross-axis value, it never falls back to
--- stretching. A flexible child's own share of the leftover space is
--- proportional to its `grow` (default `1`), split across every
--- flexible child on the line.
--- @param node WaffleFlexNode
--- @param frame WaffleFrame
--- @param lineChildren WaffleFlexNode[]
--- @param mainAxis "width" | "height"
--- @param crossAxis "width" | "height"
--- @param mainSize integer
--- @param crossSize integer
--- @param mainStart integer
--- @param crossStart integer
--- @param defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame
function _W.layoutFlexLine(node, frame, lineChildren, mainAxis, crossAxis, mainSize, crossSize, mainStart, crossStart,
                           defaultFrameFactory)
  local gap = node.gap or 0
  local isRow = mainAxis == "width"
  local visibleCount = #lineChildren

  local fixedTotal = 0
  local totalGrow = 0
  for _, child in ipairs(lineChildren) do
    local size = _W.resolveDimension(child, mainAxis)
    if size then
      fixedTotal = fixedTotal + size
    else
      totalGrow = totalGrow + (child.grow or 1)
    end
  end

  local totalGap = gap * math.max(visibleCount - 1, 0)
  local remaining = math.max(mainSize - fixedTotal - totalGap, 0)

  -- A child with a positive `grow` share already claims some or all of
  -- `remaining`; `justify` only has anything left once no child does.
  local justifyOffset, justifyGap = 0, 0
  if totalGrow == 0 then
    local leftover = remaining
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

  local mainOffset = mainStart + justifyOffset
  for _, child in ipairs(lineChildren) do
    local childFrame = _W.resolveFrame(child, frame, defaultFrameFactory)

    childFrame:Show()
    childFrame:ClearAllPoints()
    childFrame:SetParent(frame)

    local size = _W.resolveDimension(child, mainAxis)
    if not size then
      size = totalGrow > 0 and (remaining * (child.grow or 1) / totalGrow) or 0
    end

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

    local crossOffset = crossStart
    if align == "CENTER" then
      crossOffset = crossStart + (crossSize - childCrossSize) / 2
    elseif align == "END" then
      crossOffset = crossStart + (crossSize - childCrossSize)
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

--- Positions `node.children` in a row or column within `frame`, sized to
--- `width`/`height`, one line (`node.wrap` unset) or several (`node.wrap`
--- set, overflowing children start a new one instead of continuing past
--- `mainSize`). `frame` must already be resolved/sized by the caller.
--- @param node WaffleFlexNode
--- @param frame WaffleFrame
--- @param width integer
--- @param height integer
--- @param defaultFrameFactory? fun(parent: WaffleFrame): WaffleFrame
function _W.flexLayout(node, frame, width, height, defaultFrameFactory)
  local padding = node.padding or 0
  local isRow = (node.direction or "ROW"):upper() == "ROW"
  local mainAxis = isRow and "width" or "height"
  local crossAxis = isRow and "height" or "width"

  local mainSize = (isRow and width or height) - (padding * 2)
  local crossSize = (isRow and height or width) - (padding * 2)

  -- Declaration order/parent are assigned here, not in their own pass,
  -- since this loop is already walking every child anyway. `children`
  -- is `node`'s own reused scratch copy, not `node.children` itself, so
  -- sorting it doesn't disturb `GetChildren()`'s own declaration-order
  -- guarantee.
  local children = _W.Cache:GetReusableTable(_W.Cache.SortedChildren, node)
  for i, child in ipairs(node.children) do
    _W.DeclarationOrder:Assign(child)
    _W.NodeParent:Claim(child, node)
    children[i] = child
  end
  _W.Cache:Truncate(children, #node.children)

  _W.sortFlexChildren(children)

  -- Reuses lines a cross-axis `"AUTO"` computation already split `node`
  -- into, instead of splitting them again.
  local wrapLines = _W.Cache:GetWrapLines(node)
  local lines = node.wrap and wrapLines or nil

  -- Hidden children are hidden and dropped here, once, so neither
  -- `splitFlexLines` nor `layoutFlexLine` needs to care about them at
  -- all. Left `nil`, not built, when `lines` already covers `node`.
  local visibleChildren = not lines and _W.Cache:GetReusableTable(_W.Cache.VisibleChildren, node) or nil

  local visibleCount = 0
  for _, child in ipairs(children) do
    if child.hidden then
      if child.frame then
        child.frame:Hide()
      end
    elseif visibleChildren then
      visibleCount = visibleCount + 1
      visibleChildren[visibleCount] = child
    end
  end
  if visibleChildren then
    _W.Cache:Truncate(visibleChildren, visibleCount)
  end

  if node.wrap then
    local gap = node.gap or 0
    local crossOffset = padding

    for _, lineChildren in ipairs(lines or _W.splitFlexLines(visibleChildren, mainAxis, mainSize, gap)) do
      local thisLineCrossSize = _W.lineCrossSize(lineChildren, crossAxis, crossSize)
      _W.layoutFlexLine(node, frame, lineChildren, mainAxis, crossAxis, mainSize, thisLineCrossSize, padding,
        crossOffset, defaultFrameFactory)
      crossOffset = crossOffset + thisLineCrossSize + gap
    end
  else
    _W.layoutFlexLine(node, frame, visibleChildren, mainAxis, crossAxis, mainSize, crossSize, padding, padding,
      defaultFrameFactory)
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

--- Looks up a child anywhere in the tree by its `key`, erroring if none is
--- found. A duplicate key isn't validated against, the first match wins.
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

--- Returns `true` if this node's tree has changed since its last `Layout()` call.
--- @return boolean
function _W.FlexComponent:IsDirty()
  return _W.DirtyRoots[_W.NodeParent:FindRoot(self.node)] == true
end

--- Removes this node from the layout flow entirely, its siblings reflow
--- to fill the space. Position in the tree is preserved, `Show()` brings
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

-- Every setter below is a no-op unless the value actually changes, so
-- redundant calls (e.g. from a per-frame OnUpdate) stay cheap.

--- Sets this node's own width. `nil` flexes/stretches instead; `"AUTO"`
--- computes it from this node's own children (a sum along its main axis,
--- a max along its cross axis).
--- @param width? integer | "AUTO"
function _W.FlexComponent:SetWidth(width)
  if self.node.width ~= width then
    self.node.width = width
    _W.markDirty(self.node)
  end
end

--- Sets this node's own height. Same as `SetWidth()`, vertical instead.
--- @param height? integer | "AUTO"
function _W.FlexComponent:SetHeight(height)
  if self.node.height ~= height then
    self.node.height = height
    _W.markDirty(self.node)
  end
end

--- Sets this node's own share of its parent's leftover main-axis space,
--- relative to its equally-flexible siblings. `nil` resets to the
--- default (`1`).
--- @param grow? number
function _W.FlexComponent:SetGrow(grow)
  if self.node.grow ~= grow then
    self.node.grow = grow
    _W.markDirty(self.node)
  end
end

--- Overrides the parent's `align` for this node. `nil` reverts to inheriting it.
--- @param alignSelf? WaffleFlexAlign
function _W.FlexComponent:SetAlignSelf(alignSelf)
  if self.node.alignSelf ~= alignSelf then
    self.node.alignSelf = alignSelf
    _W.markDirty(self.node)
  end
end

--- Sets this node's visual position among siblings, independent of
--- declaration order. `nil` resets to the default.
--- @param order? integer
function _W.FlexComponent:SetOrder(order)
  if self.node.order ~= order then
    self.node.order = order
    _W.markDirty(self.node)
  end
end

--- Runs the layout for the tree containing this node, starting from its
--- actual current root. No-ops unless something changed since the last
--- call, cheap to call from e.g. an `OnUpdate` handler every frame.
function _W.FlexComponent:Layout()
  local root = _W.NodeParent:FindRoot(self.node)
  if _W.DirtyRoots[root] then
    _W.Cache.CurrentPass = _W.Cache.CurrentPass + 1

    if root.hidden then
      if root.frame then
        root.frame:Hide()
      end
    else
      local frame = _W.resolveFrame(root)
      frame:Show()

      -- Root resolves its own width/height the same way `resolveDimension`
      -- resolves any child's.
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

--- Constructs a leaf wrapping `node` as-is.
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

--- Constructs a container wrapping `node` as-is. May mutate `node` in
--- place, giving it `children` if it didn't already have any, turning a
--- leaf-shaped table into a container-shaped one.
--- @param node WaffleFlexNode
--- @return WaffleFlexComponentContainer
function _W.newFlexComponentContainer(node)
  node.children = node.children or {}
  return setmetatable({ node = node }, _W.FlexComponentContainer)
end

--- Appends a child as-is, returning its wrapper: a container if `child`
--- already has its own `children`, a leaf otherwise. Errors if `child`
--- already belongs to a different container, call `RemoveChild()` on
--- that one first to move it here. No-ops if `child` is already this
--- container's own, still returns a wrapper.
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

--- Appends a new ROW container as a child, returning it for further
--- composition. Errors if `child` already belongs to a different
--- container, call `RemoveChild()` on that one first to move it here.
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

--- Appends a new COLUMN container as a child, returning it for further
--- composition. Errors if `child` already belongs to a different
--- container, call `RemoveChild()` on that one first to move it here.
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
--- declaration order, not necessarily visual `order`. Not recursive.
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

--- Detaches from the tree entirely, unlike `Hide()`. Doesn't touch
--- `child`'s own `frame`.
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
--- on each one.
function _W.FlexComponentContainer:Clear()
  if #self.node.children == 0 then return end
  for _, node in ipairs(self.node.children) do
    _W.DeclarationOrder:Unassign(node)
    _W.NodeParent:Release(node)
  end
  self.node.children = {}
  _W.markDirty(self.node)
end

-- Every setter below is a no-op unless the value actually changes, same
-- convention as `FlexComponent`'s own setters above.

--- Sets the space between this container's children.
--- @param gap? integer
function _W.FlexComponentContainer:SetGap(gap)
  if self.node.gap ~= gap then
    self.node.gap = gap
    _W.markDirty(self.node)
  end
end

--- Sets the space between this container's edge and its children, on all
--- four sides.
--- @param padding? integer
function _W.FlexComponentContainer:SetPadding(padding)
  if self.node.padding ~= padding then
    self.node.padding = padding
    _W.markDirty(self.node)
  end
end

--- Sets how this container aligns its own children along the cross axis by default.
--- @param align? WaffleFlexAlign
function _W.FlexComponentContainer:SetAlign(align)
  if self.node.align ~= align then
    self.node.align = align
    _W.markDirty(self.node)
  end
end

--- Sets how this container distributes leftover main-axis space among its own children.
--- @param justify? WaffleFlexJustify
function _W.FlexComponentContainer:SetJustify(justify)
  if self.node.justify ~= justify then
    self.node.justify = justify
    _W.markDirty(self.node)
  end
end

--- Sets whether this container's overflowing children wrap onto a new line.
--- @param wrap? boolean
function _W.FlexComponentContainer:SetWrap(wrap)
  if self.node.wrap ~= wrap then
    self.node.wrap = wrap
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
