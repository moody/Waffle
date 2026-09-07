--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: a hidden child is excluded from the layout flow, its flex-share
-- space is reallocated to visible siblings.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()
  local c = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = 50 },
      { frame = b, width = 100, hidden = true },
      { frame = c },
    }
  }):Layout()

  assert(c._test.width == 150) -- 200 - 50 (b's width excluded)
  assert(c._test.point.offsetX == 50) -- right after a, b's slot skipped
  assert(b._test.width == nil) -- never positioned
  assert(b._test.point == nil)
end

-- Test: a hidden child's frame gets `Hide()` called; a visible sibling's
-- frame doesn't.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a },
      { frame = b, hidden = true },
    }
  }):Layout()

  assert(b._test.hideCalls == 1)
  assert(a._test.hideCalls == 0)
end

-- Test: showing a previously hidden child brings it back into the layout
-- flow and calls `Show()` on its frame; hiding calls `Hide()`.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  local leaf = container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 100 and b._test.width == 100)
  assert(b._test.showCalls == 1 and b._test.hideCalls == 0)

  leaf:SetHidden(true)
  container:Layout()
  assert(a._test.width == 200)
  assert(b._test.hideCalls == 1)

  leaf:SetHidden(false)
  container:Layout()
  assert(a._test.width == 100 and b._test.width == 100)
  assert(b._test.showCalls == 2)
end

-- Test: `SetHidden()` marks the tree dirty, but only on an actual value
-- change, calling it again with the same value doesn't.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetHidden(true)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetHidden(true) -- already hidden, no-op
  assert(container:IsDirty() == false)

  leaf:SetHidden(false)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetHidden(false) -- already shown, no-op
  assert(container:IsDirty() == false)
end

-- Test: a child hidden before its first `Layout()` never gets a frame
-- created via `frameFactory` while hidden; showing it creates one.
do
  local root = Mocks:CreateFrame()
  local factoryCalls = 0
  local created

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({
    hidden = true,
    frameFactory = function(parent)
      factoryCalls = factoryCalls + 1
      created = Mocks:CreateFrame()
      return created
    end,
  })
  container:Layout()

  assert(factoryCalls == 0)
  assert(leaf.node.frame == nil)

  leaf:SetHidden(false)
  container:Layout()

  assert(factoryCalls == 1)
  assert(created._test.showCalls == 1)
end

-- Test: a hidden nested container's own children are never laid out (or
-- given frames) while it stays hidden, but any already-resolved frame
-- anywhere in its subtree is still hidden.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local childFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = rowFrame, hidden = true })
  row:AddChild({ frame = childFrame })
  container:Layout()

  assert(rowFrame._test.hideCalls == 1)
  assert(childFrame._test.hideCalls == 1)
  assert(childFrame._test.width == nil) -- never laid out, parent is hidden
end

-- Test: a root declared hidden from construction, with a declarative
-- `children` table (never touching `AddChild`), still hides any
-- already-resolved frame anywhere in it on the first `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local childFrame = Mocks:CreateFrame()
  local grandchildFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    hidden = true,
    children = {
      { frame = childFrame, children = { { frame = grandchildFrame } } },
    },
  })
  container:Layout()

  assert(root._test.hideCalls == 1)
  assert(childFrame._test.hideCalls == 1)
  assert(grandchildFrame._test.hideCalls == 1)
end

-- Test: `AddChild()`-ing an already-resolved frame under a currently
-- hidden tree doesn't hide it until the next `Layout()` call, the same
-- as any other mutation.
do
  local root = Mocks:CreateFrame()
  local hiddenFrame = Mocks:CreateFrame()
  local existingFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local hidden = container:AddRow({ frame = hiddenFrame, hidden = true })
  container:Layout()

  hidden:AddChild({ frame = existingFrame })
  assert(existingFrame._test.hideCalls == 0)

  container:Layout()
  assert(existingFrame._test.hideCalls == 1)
end

-- Test: `AttachComponent()`-ing an already-composed, already-shown subtree
-- under a currently hidden tree hides every already-resolved frame in it,
-- once `Layout()` runs again.
do
  local root = Mocks:CreateFrame()
  local hiddenFrame = Mocks:CreateFrame()
  local otherRoot = Mocks:CreateFrame()
  local grandchildFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local hidden = container:AddRow({ frame = hiddenFrame, hidden = true })
  container:Layout()

  local otherTree = Waffle:Flex({ frame = otherRoot, width = 100, height = 50 })
  local grandchild = otherTree:AddChild({ frame = grandchildFrame, width = 50, height = 50 })
  otherTree:Layout()
  assert(grandchildFrame._test.hideCalls == 0)

  grandchild:Detach()
  hidden:AttachComponent(grandchild)
  assert(grandchildFrame._test.hideCalls == 0)

  container:Layout()
  assert(grandchildFrame._test.hideCalls == 1)
end

-- Test: a `frameFactory`-only child attached under a currently hidden tree
-- isn't resolved early, even once `Layout()` runs again.
do
  local root = Mocks:CreateFrame()
  local hiddenFrame = Mocks:CreateFrame()
  local factoryCalls = 0

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local hidden = container:AddRow({ frame = hiddenFrame, hidden = true })
  container:Layout()

  hidden:AddChild({
    frameFactory = function()
      factoryCalls = factoryCalls + 1
      return Mocks:CreateFrame()
    end,
  })
  container:Layout()

  assert(factoryCalls == 0)
end

-- Test: gap is only applied between visible siblings, a hidden child in
-- between doesn't consume a gap on either side.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()
  local c = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 210,
    height = 50,
    gap = 10,
    children = {
      { frame = a },
      { frame = b, hidden = true, width = 999 },
      { frame = c },
    }
  }):Layout()

  assert(a._test.width == 100 and a._test.point.offsetX == 0)
  assert(c._test.width == 100 and c._test.point.offsetX == 110)
end

print("All assertions passed.")
