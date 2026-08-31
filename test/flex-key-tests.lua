--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddChild` with a `key` registers a leaf, retrievable via
-- `GetChild` on the root, and it's the same leaf `AddChild` returned.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, key = "sidebar" })

  assert(container:GetChild("sidebar") == leaf)
end

-- Test: `AddRow`/`AddColumn` with a `key` register the returned container
-- the same way.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame(), key = "toolbar" })
  local col = container:AddColumn({ frame = Mocks:CreateFrame(), key = "sidebar" })

  assert(container:GetChild("toolbar") == row)
  assert(container:GetChild("sidebar") == col)
end

-- Test: `GetChild` works from anywhere in the tree, not just the root,
-- both from a nested container and a leaf.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame() })
  local leaf = row:AddChild({ frame = Mocks:CreateFrame() })

  local target = container:AddChild({ frame = Mocks:CreateFrame(), key = "target" })

  assert(row:GetChild("target") == target)
  assert(leaf:GetChild("target") == target)
end

-- Test: an unknown key throws an error.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })

  local ok, err = pcall(function() container:GetChild("nope") end)
  assert(not ok)
  assert(tostring(err):find("nope"))
end

-- Test: a duplicate key throws an error.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })

  container:AddChild({ frame = Mocks:CreateFrame(), key = "dup" })

  local ok, err = pcall(function()
    container:AddChild({ frame = Mocks:CreateFrame(), key = "dup" })
  end)
  assert(not ok)
  assert(tostring(err):find("dup"))
end

-- Test: a leaf child's `key`, written directly into a declarative
-- `children` table, is found by `GetChild` too, not just container-added ones.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a, key = "sidebar" } }
  })

  --- @diagnostic disable-next-line: invisible
  assert(container:GetChild("sidebar").node.frame == a)
end

-- Test: a declarative container child's `key` resolves to a real container,
-- usable for further composition, not just a leaf.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local container = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { key = "row", frame = rowFrame, direction = "ROW", children = { { frame = leaf } } },
    }
  })

  local row = container:GetChild("row")
  row:AddChild({ frame = Mocks:CreateFrame() })
  container:Layout()

  assert(leaf._test.width ~= nil) -- the row's declarative child still laid out
end

-- Test: a `key` nested two levels deep in a declarative tree is still found.
do
  local root = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local container = Waffle:Flex({
    parent = root,
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

  --- @diagnostic disable-next-line: invisible
  assert(container:GetChild("deep").node.frame == leaf)
end

-- Test: a declarative key colliding with a later container-added key errors,
-- same as two container-added keys colliding.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = Mocks:CreateFrame(), key = "dup" } }
  })

  local ok, err = pcall(function()
    container:AddChild({ frame = Mocks:CreateFrame(), key = "dup" })
  end)
  assert(not ok)
  assert(tostring(err):find("dup"))
end

-- Test: a keyed grandchild inside a declarative subtree handed to `AddRow`
-- (not the root) is still found, mixing fluent and declarative composition.
do
  local root = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local container = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  container:AddRow({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    children = { { frame = leaf, key = "mixed" } }
  })

  assert(container:GetChild("mixed").node.frame == leaf)
end

print("All assertions passed.")
