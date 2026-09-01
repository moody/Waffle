--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: a ROW child with its own `crossSize` is sized to that instead of
-- stretching to the container's full height, anchored at the cross axis's
-- start (offsetY 0).
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    children = { { frame = a, crossSize = 40 } }
  }):Layout()

  assert(a._test.height == 40)
  assert(a._test.point.offsetY == 0)
end

-- Test: a COLUMN child with its own `crossSize` is sized to that instead of
-- stretching to the container's full width, anchored at the cross axis's
-- start (offsetX 0).
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "COLUMN",
    width = 200,
    height = 100,
    children = { { frame = a, crossSize = 60 } }
  }):Layout()

  assert(a._test.width == 60)
  assert(a._test.point.offsetX == 0)
end

-- Test: a child without its own `crossSize` still stretches, siblings each
-- resolve their own `crossSize` independently.
do
  local parent = Mocks:CreateFrame()
  local fixed, stretched = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    children = {
      { frame = fixed, crossSize = 40 },
      { frame = stretched },
    }
  }):Layout()

  assert(fixed._test.height == 40)
  assert(stretched._test.height == 100)
end

-- Test: `crossSize` is still measured after `padding` is subtracted, same
-- as the stretched default, and stays anchored at the padded start.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    padding = 10,
    children = { { frame = a, crossSize = 40 } }
  }):Layout()

  assert(a._test.height == 40)
  assert(a._test.point.offsetY == -10)
end

-- Test: `crossSize` works on a container, not just a leaf, and still applies
-- to that container's own children within its now cross-sized frame.
do
  local parent = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local nested = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "COLUMN",
    width = 200,
    height = 100,
    children = {
      {
        frame = rowFrame,
        direction = "ROW",
        crossSize = 60,
        children = { { frame = nested } },
      },
    }
  }):Layout()

  assert(rowFrame._test.width == 60)
  assert(nested._test.width == 60) -- laid out within the row's own cross-sized frame
end

print("All assertions passed.")
