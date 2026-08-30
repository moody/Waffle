--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `onLayout` receives its own frame plus the exact resolved
-- width/height for a fixed-size ROW child, after SetWidth/SetHeight/SetPoint
-- have already run.
do
  local parent = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  local received

  Waffle:Flex({
    parent = parent,
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
  }):Build()

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
    parent = parent,
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
  }):Build()

  assert(received.width == 200 and received.height == 50) -- 300 - 100
end

-- Test: in a COLUMN, `onLayout` receives (width, height) in that order too,
-- not (main, cross); main is height here, so it must be swapped correctly.
do
  local parent = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  local received

  Waffle:Flex({
    parent = parent,
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
  }):Build()

  assert(child._test.width == 200 and child._test.height == 40)
  assert(received.width == 200 and received.height == 40)
end

-- Test: a real two-level nested cascade via `onLayout`. The grandchildren
-- end up positioned relative to the middle frame, not the root, and sized
-- from what the middle frame actually resolved to, not the root's own
-- dimensions.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local leftChild, rightChild = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    parent = root,
    direction = "COLUMN",
    width = 400,
    height = 300,
    children = {
      { frame = Mocks:CreateFrame(), size = 50 }, -- e.g. a title bar, unused here
      {
        frame = middle,
        onLayout = function(frame, width, height)
          Waffle:Flex({
            parent = frame,
            direction = "ROW",
            width = width,
            height = height,
            children = {
              { frame = leftChild, size = 150 },
              { frame = rightChild },
            }
          }):Build()
        end
      },
    }
  }):Build()

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

-- Test: `children` sugar recurses automatically, no `onLayout` needed for
-- the plain "this child is itself a nested container" case.
-- Same shape as the `onLayout` cascade test above, but declarative.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local leftChild, rightChild = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    parent = root,
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
  }):Build()

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
    parent = root,
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
  }):Build()

  -- Falls back to ROW: left/right sit side by side, not stacked.
  assert(left._test.point.offsetX == 0 and left._test.point.offsetY == 0)
  assert(right._test.point.offsetX == 30 and right._test.point.offsetY == 0)
  assert(left._test.height == 100 and right._test.height == 100) -- cross axis stretches
end

-- Test: `children` sugar passes `gap`/`padding` through to the
-- nested call correctly.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    parent = root,
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
  }):Build()

  assert(a._test.point.offsetX == 5)  -- padding
  assert(b._test.point.offsetX == 65) -- 5 padding + 50 + 10 gap
end

-- Test: if both `onLayout` and `children` are given, `onLayout` wins and
-- `children` is ignored entirely.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local ignoredChild = Mocks:CreateFrame()
  local onLayoutCalled = false

  Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      {
        frame = middle,
        direction = "ROW",
        children = { { frame = ignoredChild } },
        onLayout = function() onLayoutCalled = true end,
      },
    }
  }):Build()

  assert(onLayoutCalled)
  assert(ignoredChild._test.width == nil)
end

print("All assertions passed.")
