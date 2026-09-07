--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `onLayout` receives this node's own component plus the resolved
-- width/height for a fixed ROW child, after sizing/positioning has
-- already run. The component's own frame matches the node's real frame.
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
        width = 120,
        onLayout = function(component, width, height)
          received = {
            frame = component:GetFrame(),
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

-- Test: `onLayout` also fires for a flexible (no `width`) child, receiving
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
      { frame = fixed, width = 100 },
      {
        frame = flex,
        onLayout = function(component, width, height)
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
        height = 40,
        onLayout = function(component, width, height)
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

-- Test: the component `onLayout` receives is fully usable, not just for
-- reading its own frame: it can reach a keyed sibling via `GetChild`,
-- without the caller having captured a wrapper up front.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()
  local siblingFrameSeen

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      {
        frame = a,
        width = 100,
        onLayout = function(component)
          siblingFrameSeen = component:GetChild("b"):GetFrame() == b
        end
      },
      { frame = b, key = "b", width = 200 },
    }
  }):Layout()

  assert(siblingFrameSeen)
end

-- Test: the root's own `onLayout` receives a component too, usable the
-- same way as any other node's.
do
  local root = Mocks:CreateFrame()
  local receivedFrame

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    onLayout = function(component) receivedFrame = component:GetFrame() end
  })
  container:Layout()

  assert(receivedFrame == root)
end

-- Test: firing order is bottom-up: a child's own `onLayout` fires before
-- its parent's, and the root's fires last of all.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()
  local order = {}

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    onLayout = function() table.insert(order, "root") end,
    children = {
      {
        frame = middle,
        direction = "ROW",
        onLayout = function() table.insert(order, "middle") end,
        children = {
          { frame = leaf, onLayout = function() table.insert(order, "leaf") end },
        }
      },
    }
  }):Layout()

  assert(order[1] == "leaf" and order[2] == "middle" and order[3] == "root")
end

-- Test: `IsDirty()` reports `false` from inside `onLayout`, this pass is
-- already clean by the time it fires.
do
  local parent = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  local isDirtyDuringOnLayout
  local container

  container = Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = child, width = 100, onLayout = function() isDirtyDuringOnLayout = container:IsDirty() end },
    }
  })
  container:Layout()

  assert(isDirtyDuringOnLayout == false)
end

-- Test: mutating a different node from `onLayout` marks it dirty again,
-- same as any other setter call. The mark survives this call's own
-- dirty-clear, taking effect on the very next `Layout()` call.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100, onLayout = function(component) component:GetChild("b"):SetWidth(50) end },
      { frame = b, key = "b", width = 200 },
    }
  })
  container:Layout()

  assert(b._test.width == 200) -- this pass already resolved b before a's onLayout mutated it
  assert(container:IsDirty() == true)

  container:Layout()
  assert(b._test.width == 50)
end

-- Test: `SetOnLayout` replaces which callback fires on the next
-- `Layout()` call; `SetOnLayout(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local firstCalls, secondCalls = 0, 0

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, onLayout = function() firstCalls = firstCalls + 1 end })
  container:Layout()

  assert(firstCalls == 1 and secondCalls == 0)

  leaf:SetOnLayout(function() secondCalls = secondCalls + 1 end)
  container:Layout()

  assert(firstCalls == 1 and secondCalls == 1) -- replaced, not both firing

  leaf:SetOnLayout(nil)
  container:Layout()

  assert(secondCalls == 1) -- removed, doesn't fire again
end

print("All assertions passed.")
