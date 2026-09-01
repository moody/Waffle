--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `onLayout` receives its own frame plus the resolved width/height
-- for a fixed ROW child, after sizing/positioning has already run.
do
  local parent = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  local received

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      {
        frame = child,
        size = 120,
        onLayout = function(frame, width, height)
          received = {
            frame = frame,
            width = width,
            height = height
          }
        end
      },
    }
  }):Layout()

  assert(child._test.width == 120 and child._test.height == 50)
  assert(received.frame == child)
  assert(received.width == 120 and received.height == 50)
end

-- Test: `onLayout` also fires for a flexible (no `size`) child, receiving
-- whatever it actually got resolved to.
do
  local parent = Mocks:CreateFrame()
  local fixed, flex = Mocks:CreateFrame(), Mocks:CreateFrame()
  local received

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = fixed, size = 100 },
      {
        frame = flex,
        onLayout = function(frame, width, height)
          received = { width = width, height = height }
        end
      },
    }
  }):Layout()

  assert(received.width == 200 and received.height == 50) -- 300 - 100
end

-- Test: in a COLUMN, `onLayout` receives (width, height) in that order too,
-- not (main, cross); main is height here, so it must be swapped correctly.
do
  local parent = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  local received

  Waffle:Flex({
    frame = parent,
    direction = "COLUMN",
    width = 200,
    height = 100,
    children = {
      {
        frame = child,
        size = 40,
        onLayout = function(frame, width, height)
          received = { width = width, height = height }
        end
      },
    }
  }):Layout()

  assert(child._test.width == 200 and child._test.height == 40)
  assert(received.width == 200 and received.height == 40)
end

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
      { frame = Mocks:CreateFrame(), size = 50 }, -- e.g. a title bar, unused here
      {
        frame = middle,
        onLayout = function(frame, width, height)
          Waffle:Flex({
            frame = frame,
            direction = "ROW",
            width = width,
            height = height,
            children = {
              { frame = leftChild, size = 150 },
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
      { frame = Mocks:CreateFrame(), size = 50 },
      {
        frame = middle,
        direction = "ROW",
        children = {
          { frame = leftChild, size = 150 },
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
          { frame = left, size = 30 },
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
          { frame = a, size = 50 },
          { frame = b, size = 50 },
        }
      },
    }
  }):Layout()

  assert(a._test.point.offsetX == 5)  -- padding
  assert(b._test.point.offsetX == 65) -- 5 padding + 50 + 10 gap
end

-- Test: if both `onLayout` and `children` are given, both fire, `onLayout`
-- doesn't suppress its `children` being laid out.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local nestedChild = Mocks:CreateFrame()
  local onLayoutCalled = false

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      {
        frame = middle,
        direction = "ROW",
        children = { { frame = nestedChild } },
        onLayout = function() onLayoutCalled = true end,
      },
    }
  }):Layout()

  assert(onLayoutCalled)
  assert(nestedChild._test.width == 200)
end

-- Test: `onLayout` fires after its `children` are laid out, not before,
-- they're already sized by the time it runs.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local nestedChild = Mocks:CreateFrame()
  local nestedChildWidthDuringOnLayout

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      {
        frame = middle,
        direction = "ROW",
        children = { { frame = nestedChild } },
        onLayout = function()
          nestedChildWidthDuringOnLayout = nestedChild._test.width
        end,
      },
    }
  }):Layout()

  assert(nestedChildWidthDuringOnLayout == 200)
end

print("All assertions passed.")
