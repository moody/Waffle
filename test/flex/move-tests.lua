--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddChild` returns a container wrapper, not a leaf, when the given
-- node already has its own `children`, usable for further composition.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local nested = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local wrapper = container:AddChild({
    frame = middle,
    children = { { frame = nested } },
  })

  assert(wrapper:IsContainer())
  wrapper:AddChild({ frame = Mocks:CreateFrame() }) -- further composition works
  assert(#wrapper:GetChildren() == 2)
end

-- Test: adding the same node to a second container without removing it
-- from the first errors instead of silently double-attaching it.
do
  local rootA, rootB = Mocks:CreateFrame(), Mocks:CreateFrame()
  local containerA = Waffle:Flex({ frame = rootA, direction = "ROW", width = 200, height = 50 })
  local containerB = Waffle:Flex({ frame = rootB, direction = "ROW", width = 200, height = 50 })

  local child = { frame = Mocks:CreateFrame() }
  containerA:AddChild(child)

  local ok, err = pcall(function() containerB:AddChild(child) end)
  assert(not ok)
  assert(tostring(err):find("already belongs"))
end

-- Test: calling `AddChild` twice with the same node on the same container
-- is a harmless no-op, it doesn't duplicate the entry or error.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local child = { frame = a }

  container:AddChild(child)
  container:AddChild(child) -- same node, same container, again

  assert(#container:GetChildren() == 1)
end

-- Test: a node shared between two purely declarative trees, never touching
-- `AddChild`, still errors once both trees are actually walked.
do
  local rootAFrame = Mocks:CreateFrame()
  local rootBFrame = Mocks:CreateFrame()
  local sharedFrame = Mocks:CreateFrame()

  local shared = { frame = sharedFrame }

  local containerA = Waffle:Flex({
    frame = rootAFrame,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { shared },
  })
  containerA:Layout() -- shared's parent is now rootA's node

  local containerB = Waffle:Flex({
    frame = rootBFrame,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { shared },
  })

  local ok, err = pcall(function() containerB:Layout() end)
  assert(not ok)
  assert(tostring(err):find("already belongs"))
end

-- Test: removing a child from its container first, then adding it to a
-- different one, moves it there cleanly, laid out under the new parent.
do
  local rootA, rootB = Mocks:CreateFrame(), Mocks:CreateFrame()
  local containerA = Waffle:Flex({ frame = rootA, direction = "ROW", width = 200, height = 50 })
  local containerB = Waffle:Flex({ frame = rootB, direction = "ROW", width = 300, height = 50 })

  local childFrame = Mocks:CreateFrame()
  local leafA = containerA:AddChild({ frame = childFrame, size = 100 })
  containerA:Layout()
  assert(childFrame._test.point.parent == rootA)

  assert(containerA:RemoveChild(leafA))
  local leafB = containerB:AddChild({ frame = childFrame, size = 100 })
  containerB:Layout()

  assert(childFrame._test.point.parent == rootB)
  assert(leafB.node.frame == childFrame)
end

-- Test: a node that's the actual root of its own (never laid out) tree was
-- never claimed by any container, so it can be grafted straight into a
-- different tree as a child, no `RemoveChild()` dance required.
do
  local rootAFrame = Mocks:CreateFrame()
  local rootBFrame = Mocks:CreateFrame()
  local nestedFrame = Mocks:CreateFrame()

  local rootBOptions = {
    frame = rootBFrame,
    direction = "ROW",
    children = { { frame = nestedFrame } },
  }
  Waffle:Flex(rootBOptions) -- rootBOptions is the root of its own tree, never laid out

  local containerA = Waffle:Flex({ frame = rootAFrame, direction = "ROW", width = 200, height = 50 })
  local wrapper = containerA:AddChild(rootBOptions) -- grafted in as a child, no error

  assert(wrapper:IsContainer())
  containerA:Layout()

  assert(rootBFrame._test.point.parent == rootAFrame)
  assert(nestedFrame._test.width == 200) -- rootBOptions' own children laid out too, as containerA's child now
end

-- Test: calling `Layout()` on a node nested deep in the tree, not the root
-- container itself, still lays out the whole tree from its actual root.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local nested = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  container:AddChild({ frame = a, size = 100 })
  local row = container:AddRow({ frame = rowFrame })
  local leaf = row:AddChild({ frame = nested })

  leaf:Layout() -- called from deep in the tree, not the root container

  assert(a._test.width == 100)
  assert(rowFrame._test.width == 200) -- 300 - 100, flexes to fill the rest
  assert(nested._test.width == 200) -- rowFrame's own sole child, flexes to fill it
end

-- Test: once grafted into a different tree, the *original* root wrapper is
-- no longer stale, mutating or calling `Layout()` through it reaches the
-- new tree correctly instead of a conflicting, independent one.
do
  local rootAFrame = Mocks:CreateFrame()
  local rootBFrame = Mocks:CreateFrame()
  local siblingFrame = Mocks:CreateFrame()

  local rootBOptions = { frame = rootBFrame, direction = "ROW" }
  local staleRootB = Waffle:Flex(rootBOptions) -- tree B's own root wrapper

  local containerA = Waffle:Flex({ frame = rootAFrame, direction = "ROW", width = 300, height = 50 })
  containerA:AddChild({ frame = siblingFrame, size = 100 })
  containerA:AddChild(rootBOptions) -- grafted in as a child, tree B stops being independent
  containerA:Layout()

  assert(rootBFrame._test.point.parent == rootAFrame)
  assert(rootBFrame._test.width == 200) -- 300 - 100, flexes to fill the rest
  assert(containerA:IsDirty() == false)

  staleRootB:SetSize(50) -- mutating through the stale wrapper still reaches tree A
  assert(containerA:IsDirty() == true)

  containerA:Layout()
  assert(rootBFrame._test.width == 50)
  assert(siblingFrame._test.width == 100)
end

print("All assertions passed.")
