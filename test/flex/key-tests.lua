--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddChild` with a `key` registers a leaf, retrievable via
-- `GetChild` on the root. `GetChild` returns a fresh component each call,
-- not the identical object `AddChild` returned, but both wrap the same node.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, key = "sidebar" })
  local component = container:GetChild("sidebar")

  assert(component ~= leaf)
  assert(component.node == leaf.node)
end

-- Test: `AddRow`/`AddColumn` with a `key` register the returned container
-- the same way.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame(), key = "toolbar" })
  local col = container:AddColumn({ frame = Mocks:CreateFrame(), key = "sidebar" })

  assert(container:GetChild("toolbar").node == row.node)
  assert(container:GetChild("sidebar").node == col.node)
end

-- Test: `GetChild` works from anywhere in the tree, not just the root,
-- both from a nested container and a leaf.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame() })
  local leaf = row:AddChild({ frame = Mocks:CreateFrame() })

  local target = container:AddChild({ frame = Mocks:CreateFrame(), key = "target" })

  assert(row:GetChild("target").node == target.node)
  assert(leaf:GetChild("target").node == target.node)
end

-- Test: an unknown key throws an error.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })

  local ok, err = pcall(function() container:GetChild("nope") end)
  assert(not ok)
  assert(tostring(err):find("nope"))
end

-- Test: a duplicate key doesn't error, the first match found wins.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })

  container:AddChild({ frame = a, key = "dup" })
  container:AddChild({ frame = b, key = "dup" })

  assert(container:GetChild("dup").node.frame == a)
end

-- Test: a leaf child's `key`, written directly into a declarative
-- `children` table, is found by `GetChild` too, not just container-added ones.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a, key = "sidebar" } }
  })

  assert(container:GetChild("sidebar").node.frame == a)
end

-- Test: a declarative container child's `key` resolves to a real container,
-- usable for further composition, not just a leaf.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()
  local newLeaf = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { key = "row", frame = rowFrame, direction = "ROW", children = { { frame = leaf } } },
    }
  })

  local row = container:GetChild("row")
  row:AddChild({ frame = newLeaf })
  container:Layout()

  assert(leaf._test.width ~= nil)    -- the row's declarative child still laid out
  assert(newLeaf._test.width ~= nil) -- and the newly added child too
end

-- Test: a `key` nested two levels deep in a declarative tree is still found.
do
  local root = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      {
        direction = "ROW",
        children = { { frame = leaf, key = "deep" } }
      },
    }
  })

  assert(container:GetChild("deep").node.frame == leaf)
end

-- Test: a declarative key colliding with a later container-added key
-- doesn't error, the first match (the declarative one) wins.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a, key = "dup" } }
  })

  container:AddChild({ frame = b, key = "dup" })

  assert(container:GetChild("dup").node.frame == a)
end

-- Test: a keyed grandchild inside a declarative subtree handed to `AddRow`
-- (not the root) is still found, mixing fluent and declarative composition.
do
  local root = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddRow({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    children = { { frame = leaf, key = "mixed" } }
  })

  assert(container:GetChild("mixed").node.frame == leaf)
end

-- Test: `SetKey` registers (or changes) a node's own key for `GetChild`
-- lookup, without marking the tree dirty.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetKey("a")
  assert(container:IsDirty() == false)
  assert(container:GetChild("a").node.frame == a)

  leaf:SetKey("b")
  assert(container:GetChild("b").node.frame == a)

  local ok = pcall(function() container:GetChild("a") end)
  assert(not ok) -- old key no longer registered
end

print("All assertions passed.")
