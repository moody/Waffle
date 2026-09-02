--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `width = "AUTO"` on a ROW node (its own main axis) sums its
-- children's own `width`, plus `gap` between them and `padding` on both ends.
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
        gap = 10,
        padding = 5,
        children = {
          { frame = a, width = 30 },
          { frame = b, width = 40 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.width == 90) -- 30 + 40 + gap(10) + padding*2(10)
end

-- Test: `height = "AUTO"` on a COLUMN node works the same way, along its
-- own main axis instead.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 200,
    children = {
      {
        frame = autoFrame,
        direction = "COLUMN",
        width = 60,
        height = "AUTO",
        children = {
          { frame = a, height = 20 },
          { frame = b, height = 25 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 45) -- 20 + 25
end

-- Test: a COLUMN child's own `height = "AUTO"` (its own main axis) also
-- serves as its ROW parent's cross-axis measurement of it.
do
  local parent = Mocks:CreateFrame()
  local colFrame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 200,
    children = {
      {
        frame = colFrame,
        direction = "COLUMN",
        width = 60,
        height = "AUTO",
        children = {
          { frame = a, height = 20 },
          { frame = b, height = 25 },
        }
      }
    }
  }):Layout()

  assert(colFrame._test.width == 60) -- its own fixed main-axis width, unaffected
  assert(colFrame._test.height == 45) -- its own AUTO height, doubling as the ROW parent's cross size
end

-- Test: `"AUTO"` recurses through nested `"AUTO"` children automatically.
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
        width = "AUTO",
        children = {
          {
            frame = inner,
            direction = "ROW",
            width = "AUTO",
            children = {
              { frame = a, width = 10 },
              { frame = b, width = 20 },
            }
          }
        }
      }
    }
  }):Layout()

  assert(inner._test.width == 30) -- 10 + 20
  assert(outer._test.width == 30) -- inner's own AUTO width, nothing else beside it
end

-- Test: a hidden child is excluded from an `"AUTO"` sum.
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
        children = {
          { frame = a, width = 30 },
          { frame = b, width = 40, hidden = true },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.width == 30) -- b excluded entirely
end

-- Test: a flexible child (no `width` of its own) inside an `"AUTO"` node errors.
do
  local parent = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = parent, direction = "ROW", width = 400, height = 50 })
  local auto = container:AddChild({ frame = Mocks:CreateFrame(), direction = "ROW", width = "AUTO", children = {} })
  auto:AddChild({ frame = Mocks:CreateFrame() }) -- no width, flexible

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("flexible"))
end

-- Test: `"AUTO"` on a node's own cross axis (not its main axis, given its
-- own `direction`) errors.
do
  local parent = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = parent, direction = "ROW", width = 400, height = 50 })
  container:AddChild({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    height = "AUTO", -- ROW's cross axis, not its main axis
    children = { { frame = Mocks:CreateFrame(), width = 30 } },
  })

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("main axis"))
end

-- Test: root's own `width = "AUTO"` works the same way any node's would,
-- `height` (its cross axis) still required, given directly.
do
  local frame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = frame,
    direction = "ROW",
    width = "AUTO",
    height = 60,
    gap = 5,
    padding = 8,
    children = {
      { frame = a, width = 30 },
      { frame = b, width = 40 },
    }
  }):Layout()

  assert(frame._test.width == 91) -- 30 + 40 + gap(5) + padding*2(16)
  assert(frame._test.height == 60)
end

-- Test: root still needs its own `width`, missing it errors, nothing
-- above it to resolve one automatically.
do
  local frame = Mocks:CreateFrame()
  local root = Waffle:Flex({ frame = frame, direction = "ROW", height = 50 })
  root:AddChild({ frame = Mocks:CreateFrame(), width = 30 })

  local ok, err = pcall(function() root:Layout() end)
  assert(not ok)
  assert(tostring(err):find("width"))
end

-- Test: same for `height`, on a COLUMN root.
do
  local frame = Mocks:CreateFrame()
  local root = Waffle:Flex({ frame = frame, direction = "COLUMN", width = 50 })
  root:AddChild({ frame = Mocks:CreateFrame(), height = 30 })

  local ok, err = pcall(function() root:Layout() end)
  assert(not ok)
  assert(tostring(err):find("height"))
end

print("All assertions passed.")
