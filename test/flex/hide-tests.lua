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
      { frame = a, size = 50 },
      { frame = b, size = 100, hidden = true },
      { frame = c },
    }
  }):Layout()

  assert(c._test.width == 150) -- 200 - 50 (b's size excluded)
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

  leaf:Hide()
  container:Layout()
  assert(a._test.width == 200)
  assert(b._test.hideCalls == 1)

  leaf:Show()
  container:Layout()
  assert(a._test.width == 100 and b._test.width == 100)
  assert(b._test.showCalls == 2)
end

-- Test: `Hide()`/`Show()` mark the tree dirty, but only on an actual state
-- change, calling either again while already in that state doesn't.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:Hide()
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:Hide() -- already hidden, no-op
  assert(container:IsDirty() == false)

  leaf:Show()
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:Show() -- already shown, no-op
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

  leaf:Show()
  container:Layout()

  assert(factoryCalls == 1)
  assert(created._test.showCalls == 1)
end

-- Test: a hidden nested container's own children are never laid out (or
-- given frames) while it stays hidden.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local childFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = rowFrame, hidden = true })
  row:AddChild({ frame = childFrame })
  container:Layout()

  assert(rowFrame._test.hideCalls == 1)
  assert(childFrame._test.width == nil) -- never laid out, parent is hidden
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
      { frame = b, hidden = true, size = 999 },
      { frame = c },
    }
  }):Layout()

  assert(a._test.width == 100 and a._test.point.offsetX == 0)
  assert(c._test.width == 100 and c._test.point.offsetX == 110)
end

print("All assertions passed.")
