--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: attaching an independently-composed container component grafts its
-- own children into the outer tree too, not just its own root frame.
do
  local outerFrame = Mocks:CreateFrame()
  local innerFrame = Mocks:CreateFrame()
  local nestedFrame = Mocks:CreateFrame()

  local outer = Waffle:Flex({ frame = outerFrame, direction = "ROW", width = 300, height = 50 })
  local inner = Waffle:Flex({
    frame = innerFrame,
    direction = "ROW",
    children = { { frame = nestedFrame } },
  })

  local attached = outer:AttachComponent(inner)
  assert(attached == inner) -- the same component handed back, not a fresh one

  outer:Layout()

  assert(innerFrame._test.point.parent == outerFrame)
  assert(nestedFrame._test.width == 300) -- inner's own child laid out too, as outer's child now
end

-- Test: attaching a leaf component, obtained from `AddChild` and then
-- detached, works the same way as attaching a container.
do
  local rootAFrame, rootBFrame = Mocks:CreateFrame(), Mocks:CreateFrame()
  local leafFrame = Mocks:CreateFrame()

  local containerA = Waffle:Flex({ frame = rootAFrame, direction = "ROW", width = 200, height = 50 })
  local leaf = containerA:AddChild({ frame = leafFrame, width = 100 })
  assert(containerA:DetachComponent(leaf))

  local containerB = Waffle:Flex({ frame = rootBFrame, direction = "ROW", width = 300, height = 50 })
  containerB:AttachComponent(leaf)
  containerB:Layout()

  assert(leafFrame._test.point.parent == rootBFrame)
  assert(leafFrame._test.width == 100)
end

-- Test: attaching a component that already belongs to a different
-- container errors instead of silently double-attaching it.
do
  local rootAFrame, rootBFrame = Mocks:CreateFrame(), Mocks:CreateFrame()
  local containerA = Waffle:Flex({ frame = rootAFrame, direction = "ROW", width = 200, height = 50 })
  local containerB = Waffle:Flex({ frame = rootBFrame, direction = "ROW", width = 200, height = 50 })

  local child = containerA:AddChild({ frame = Mocks:CreateFrame() })

  local ok, err = pcall(function() containerB:AttachComponent(child) end)
  assert(not ok)
  assert(tostring(err):find("already belongs"))
end

-- Test: attaching the same component twice to the same container is a
-- harmless no-op, it doesn't duplicate the entry.
do
  local rootFrame = Mocks:CreateFrame()
  local innerFrame = Mocks:CreateFrame()

  local outer = Waffle:Flex({ frame = rootFrame, direction = "ROW", width = 200, height = 50 })
  local inner = Waffle:Flex({ frame = innerFrame, direction = "ROW", width = 100, height = 50 })

  outer:AttachComponent(inner)
  outer:AttachComponent(inner) -- same component, same container, again

  assert(#outer:GetChildren() == 1)
end

-- Test: a component's own `direction` is unchanged by attaching it, unlike
-- `AddRow`/`AddColumn` which force one on a fresh node.
do
  local rootFrame = Mocks:CreateFrame()
  local innerFrame = Mocks:CreateFrame()

  local outer = Waffle:Flex({ frame = rootFrame, direction = "ROW", width = 200, height = 50 })
  local inner = Waffle:Flex({ frame = innerFrame, direction = "COLUMN" })

  local attached = outer:AttachComponent(inner)
  outer:Layout()

  assert(attached.node.direction == "COLUMN") -- untouched by the outer ROW container
end

print("All assertions passed.")
