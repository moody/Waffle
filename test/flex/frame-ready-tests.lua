--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `WhenFrameReady` on a node with a `frameFactory` waits for `Layout()`,
-- then calls the callback once with the frame the factory created.
do
  local root = Mocks:CreateFrame()
  local created
  local calls, receivedFrame = 0, nil

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({
    frameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  leaf:WhenFrameReady(function(frame)
    calls = calls + 1
    receivedFrame = frame
  end)

  assert(calls == 0)
  container:Layout()

  assert(calls == 1)
  assert(receivedFrame == created)
end

-- Test: `WhenFrameReady` on a node given its own `frame` calls the callback
-- immediately, before any `Layout()`.
do
  local root = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  local receivedFrame

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = child })
  leaf:WhenFrameReady(function(frame) receivedFrame = frame end)

  assert(receivedFrame == child)
end

-- Test: `WhenFrameReady` on a node whose frame was already created by a
-- `Layout()` calls the callback immediately.
do
  local root = Mocks:CreateFrame()
  local created
  local receivedFrame

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({
    frameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  container:Layout()

  leaf:WhenFrameReady(function(frame) receivedFrame = frame end)

  assert(receivedFrame == created)
end

-- Test: `WhenFrameReady` calls the callback with a frame created by the root's
-- `defaultFrameFactory`, chained off `AddRow`.
do
  local root = Mocks:CreateFrame()
  local created
  local receivedFrame

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  container:AddRow():WhenFrameReady(function(frame) receivedFrame = frame end)
  container:Layout()

  assert(receivedFrame == created)
end

-- Test: `WhenFrameReady` calls the callback before Waffle parents, positions,
-- sizes, or shows the node's frame.
do
  local root = Mocks:CreateFrame()
  local rootState, childState

  local container = Waffle:Flex({
    direction = "ROW",
    width = 200,
    height = 50,
    frameFactory = function() return root end
  })
  container:WhenFrameReady(function(frame)
    rootState = { width = frame._test.width, shows = frame._test.showCalls }
  end)
  container:AddChild({ frameFactory = function() return Mocks:CreateFrame() end })
      :WhenFrameReady(function(frame)
        childState = {
          width = frame._test.width,
          parent = frame._test.parent,
          shows = frame._test.showCalls,
          clears = frame._test.clearedPoints
        }
      end)
  container:Layout()

  assert(rootState.width == nil and rootState.shows == 0)
  assert(childState.width == nil and childState.parent == nil)
  assert(childState.shows == 0 and childState.clears == 0)
end

-- Test: `WhenFrameReady` calls each callback once, not again on later
-- `Layout()` calls.
do
  local root = Mocks:CreateFrame()
  local calls = 0

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frameFactory = function() return Mocks:CreateFrame() end })
  leaf:WhenFrameReady(function() calls = calls + 1 end)
  container:Layout()

  leaf:SetWidth(50)
  container:Layout()
  container:SetWidth(300)
  container:Layout()

  assert(calls == 1)
end

-- Test: `WhenFrameReady` calls several callbacks on one node in
-- registration order.
do
  local root = Mocks:CreateFrame()
  local order = {}
  local function record(name) return function() table.insert(order, name) end end

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frameFactory = function() return Mocks:CreateFrame() end })
  leaf:WhenFrameReady(record("first"))
  leaf:WhenFrameReady(record("second"))
  leaf:WhenFrameReady(record("third"))
  container:Layout()

  assert(order[1] == "first")
  assert(order[2] == "second")
  assert(order[3] == "third")
end

-- Test: a hidden node's frame is not created, so `WhenFrameReady` waits for
-- the first `Layout()` that shows it.
do
  local root = Mocks:CreateFrame()
  local factoryCalls, calls = 0, 0

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({
    hidden = true,
    frameFactory = function()
      factoryCalls = factoryCalls + 1
      return Mocks:CreateFrame()
    end
  })
  leaf:WhenFrameReady(function() calls = calls + 1 end)
  container:Layout()

  assert(factoryCalls == 0 and calls == 0)

  leaf:SetHidden(false)
  container:Layout()

  assert(factoryCalls == 1 and calls == 1)
end

-- Test: a callback registered from inside another callback on the same node
-- runs immediately.
do
  local root = Mocks:CreateFrame()
  local order = {}

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frameFactory = function() return Mocks:CreateFrame() end })
  leaf:WhenFrameReady(function()
    table.insert(order, "outer start")
    leaf:WhenFrameReady(function() table.insert(order, "inner") end)
    table.insert(order, "outer end")
  end)
  container:Layout()

  assert(order[1] == "outer start")
  assert(order[2] == "inner")
  assert(order[3] == "outer end")
end

print("All assertions passed.")
