--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `GetChildren` returns every direct child, wrapped, in declaration order.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  container:AddChild({ frame = a })
  container:AddChild({ frame = b })
  container:AddChild({ frame = c })

  local children = container:GetChildren()

  assert(#children == 3)
  assert(children[1]:GetFrame() == a)
  assert(children[2]:GetFrame() == b)
  assert(children[3]:GetFrame() == c)
end

-- Test: a container-shaped child comes back usable for further composition, not just a leaf.
do
  local root = Mocks:CreateFrame()
  local nested = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  container:AddRow({ frame = Mocks:CreateFrame() })

  local row = container:GetChildren()[1]
  row:AddChild({ frame = nested })
  container:Layout()

  assert(nested._test.width ~= nil)
end

-- Test: `GetChildren` returns only direct children, doesn't recurse into grandchildren.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame() })
  row:AddChild({ frame = Mocks:CreateFrame() })
  row:AddChild({ frame = Mocks:CreateFrame() })

  assert(#container:GetChildren() == 1)
  assert(#row:GetChildren() == 2)
end

-- Test: `GetChildren` on an empty container returns an empty array.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })

  assert(#container:GetChildren() == 0)
end

-- Test: `GetChildren` reflects the container's current state, not a
-- snapshot from whenever it was first called.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leafA = container:AddChild({ frame = a })
  assert(#container:GetChildren() == 1)

  container:AddChild({ frame = b })
  assert(#container:GetChildren() == 2)

  container:DetachComponent(leafA)
  assert(#container:GetChildren() == 1)
  assert(container:GetChildren()[1].node.frame == b)
end

-- Test: `DetachComponent` and `Clear` on a component that never had any
-- children at all don't error, same as on one that's merely empty.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })

  assert(container:DetachComponent(container) == false)
  container:Clear() -- no-ops, doesn't error
end

-- Test: `Layout()` on a root that never had any children at all resolves
-- its own frame without erroring.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })

  container:Layout()

  assert(root._test.width == 200 and root._test.height == 50)
end

print("All assertions passed.")
