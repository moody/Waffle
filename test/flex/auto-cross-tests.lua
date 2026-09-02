--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `height = "AUTO"` on a ROW node (its own cross axis) is the max of
-- its children's own `height`, plus `padding` on both ends, not a sum.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        padding = 5,
        children = {
          { frame = a, height = 20 },
          { frame = b, height = 45 },
          { frame = c, height = 30 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 55) -- max(20, 45, 30) + padding*2(10)
end

-- Test: `width = "AUTO"` on a COLUMN node (its own cross axis) works the
-- same way, along width instead of height.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 200,
    children = {
      {
        frame = autoFrame,
        direction = "COLUMN",
        height = 150,
        width = "AUTO",
        children = {
          { frame = a, width = 15 },
          { frame = b, width = 50 },
          { frame = c, width = 25 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.width == 50) -- max(15, 50, 25)
end

-- Test: a flexible child (no `height` of its own) inside a cross-axis
-- `"AUTO"` node errors.
do
  local parent = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = parent, direction = "ROW", width = 400, height = 50 })
  local auto = container:AddChild({ frame = Mocks:CreateFrame(), direction = "ROW", width = 200, height = "AUTO", children = {} })
  auto:AddChild({ frame = Mocks:CreateFrame() }) -- no height, flexible

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("flexible"))
end

-- Test: a hidden child is excluded from a cross-axis `"AUTO"` max.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        children = {
          { frame = a, height = 20 },
          { frame = b, height = 100, hidden = true },
          { frame = c, height = 30 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 30) -- b (100) excluded, max(20, 30)
end

-- Test: cross-axis `"AUTO"` recurses through a nested cross-axis `"AUTO"`
-- child automatically.
do
  local parent = Mocks:CreateFrame()
  local outer = Mocks:CreateFrame()
  local inner = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = outer,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        children = {
          {
            frame = inner,
            direction = "ROW",
            width = 200,
            height = "AUTO",
            children = {
              { frame = a, height = 15 },
              { frame = b, height = 35 },
            }
          }
        }
      }
    }
  }):Layout()

  assert(inner._test.height == 35) -- max(15, 35)
  assert(outer._test.height == 35) -- inner's own AUTO height, nothing else beside it
end

-- Test: main-axis `"AUTO"` (sum) and cross-axis `"AUTO"` (max) on the same
-- node compute independently.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = "AUTO",
        height = "AUTO",
        gap = 10,
        children = {
          { frame = a, width = 20, height = 15 },
          { frame = b, width = 30, height = 40 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.width == 60)  -- 20 + 30 + gap(10), main-axis sum
  assert(autoFrame._test.height == 40) -- max(15, 40), cross-axis max
end

-- Test: root's own cross axis can be `"AUTO"` too, the same as any node's.
do
  local frame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = frame,
    direction = "ROW",
    width = 300,
    height = "AUTO",
    children = {
      { frame = a, height = 20 },
      { frame = b, height = 45 },
    }
  }):Layout()

  assert(frame._test.width == 300)
  assert(frame._test.height == 45) -- max(20, 45), root's own cross axis
end

print("All assertions passed.")
