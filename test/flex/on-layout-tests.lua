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
