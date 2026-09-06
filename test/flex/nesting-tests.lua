--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: two-level cascade via `onLayout`. Grandchildren position relative
-- to the middle frame, not the root, sized from the middle's resolved
-- size, not the root's.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local leftChild, rightChild = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 400,
    height = 300,
    children = {
      { frame = Mocks:CreateFrame(), height = 50 }, -- e.g. a title bar, unused here
      {
        frame = middle,
        onLayout = function(component, width, height)
          Waffle:Flex({
            frame = component:GetFrame(),
            direction = "ROW",
            width = width,
            height = height,
            children = {
              { frame = leftChild, width = 150 },
              { frame = rightChild },
            }
          }):Layout()
        end
      },
    }
  }):Layout()

  -- middle got the remaining column space: full width (COLUMN's cross axis
  -- stretches), height = 300 - 50 = 250.
  assert(middle._test.width == 400 and middle._test.height == 250)

  -- leftChild/rightChild were laid out against middle's *resolved* size
  -- (400x250), not the root's original 400x300, and anchored to middle,
  -- not to root.
  assert(leftChild._test.width == 150 and leftChild._test.height == 250)
  assert(rightChild._test.width == 250 and rightChild._test.height == 250) -- 400 - 150
  assert(leftChild._test.point.parent == middle)
  assert(rightChild._test.point.parent == middle)
  assert(leftChild._test.point.offsetX == 0)
  assert(rightChild._test.point.offsetX == 150)
end

-- Test: `children` sugar recurses automatically, no `onLayout` needed.
-- Same shape as the cascade test above, but declarative.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local leftChild, rightChild = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 400,
    height = 300,
    children = {
      { frame = Mocks:CreateFrame(), height = 50 },
      {
        frame = middle,
        direction = "ROW",
        children = {
          { frame = leftChild, width = 150 },
          { frame = rightChild },
        }
      },
    }
  }):Layout()

  -- middle got the remaining column space: full width (COLUMN's cross axis
  -- stretches), height = 300 - 50 = 250.
  assert(middle._test.width == 400 and middle._test.height == 250)

  -- leftChild/rightChild were laid out against middle's *resolved* size
  -- (400x250), not the root's original 400x300, and anchored to middle,
  -- not to root.
  assert(leftChild._test.width == 150 and leftChild._test.height == 250)
  assert(rightChild._test.width == 250 and rightChild._test.height == 250) -- 400 - 150
  assert(leftChild._test.point.parent == middle)
  assert(rightChild._test.point.parent == middle)
  assert(leftChild._test.point.offsetX == 0)
  assert(rightChild._test.point.offsetX == 150)
end

-- Test: a nested `children` block with no `direction` at all defaults to ROW.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local left, right = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 200,
    height = 100,
    children = {
      {
        frame = middle,
        -- no `direction` here at all
        children = {
          { frame = left, width = 30 },
          { frame = right },
        }
      },
    }
  }):Layout()

  -- Falls back to ROW: left/right sit side by side, not stacked.
  assert(left._test.point.offsetX == 0 and left._test.point.offsetY == 0)
  assert(right._test.point.offsetX == 30 and right._test.point.offsetY == 0)
  assert(left._test.height == 100 and right._test.height == 100) -- cross axis stretches
end

-- Test: `children` sugar applies `gap`/`padding` to the nested container correctly.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 220,
    height = 60,
    children = {
      {
        frame = middle,
        direction = "ROW",
        gap = 10,
        padding = 5,
        children = {
          { frame = a, width = 50 },
          { frame = b, width = 50 },
        }
      },
    }
  }):Layout()

  assert(a._test.point.offsetX == 5)  -- padding
  assert(b._test.point.offsetX == 65) -- 5 padding + 50 + 10 gap
end

print("All assertions passed.")
