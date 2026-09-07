--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `hidden = true` on the root hides its own frame and skips laying
-- out its children entirely, same as a hidden child would.
do
  local root = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    hidden = true,
    width = 200,
    height = 50,
    children = {
      { frame = child },
    }
  }):Layout()

  assert(root._test.hideCalls == 1)
  assert(root._test.width == nil and root._test.height == nil)
  assert(child._test.width == nil)
end

-- Test: calling `SetHidden(true)`/`SetHidden(false)` on the root
-- container itself, after the fact, takes its frame down and back up,
-- same as giving `hidden = true` up front.
do
  local root = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, width = 200, height = 50 })
  container:AddChild({ frame = child })
  container:Layout()

  assert(root._test.showCalls == 1)
  assert(child._test.width == 200)

  container:SetHidden(true)
  container:Layout()

  assert(root._test.hideCalls == 1)
  assert(root._test.width == 200) -- unchanged, layout skipped entirely while hidden

  container:SetHidden(false)
  container:Layout()

  assert(root._test.showCalls == 2)
end

-- Test: `order` on the root has no effect, nothing above it to sort it
-- among siblings; layout still runs normally.
do
  local root = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    order = 5,
    width = 200,
    height = 50,
    children = {
      { frame = child, width = 100 },
    }
  }):Layout()

  assert(child._test.width == 100)
end

-- Test: `onLayout` on the root fires after its children are already laid
-- out, not before, they're already sized by the time it runs.
do
  local root = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  local rootLayoutCalls = 0
  local childWidthDuringOnLayout

  Waffle:Flex({
    frame = root,
    width = 200,
    height = 50,
    onLayout = function(component, width, height)
      rootLayoutCalls = rootLayoutCalls + 1
      assert(component:GetFrame() == root and width == 200 and height == 50)
      childWidthDuringOnLayout = child._test.width
    end,
    children = {
      { frame = child },
    }
  }):Layout()

  assert(rootLayoutCalls == 1)
  assert(childWidthDuringOnLayout == 200)
end

print("All assertions passed.")
