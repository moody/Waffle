--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddChild` with a `key` registers a handle, retrievable via
-- `GetChild` on the root, and it's the same handle `AddChild` returned.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  local handle = builder:AddChild({ frame = a, key = "sidebar" })

  assert(builder:GetChild("sidebar") == handle)
end

-- Test: `AddRow`/`AddColumn` with a `key` register the returned builder
-- the same way.
do
  local root = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  local row = builder:AddRow({ frame = Mocks:CreateFrame(), key = "toolbar" })
  local col = builder:AddColumn({ frame = Mocks:CreateFrame(), key = "sidebar" })

  assert(builder:GetChild("toolbar") == row)
  assert(builder:GetChild("sidebar") == col)
end

-- Test: `GetChild` works from anywhere in the tree, not just the root,
-- both from a nested builder and a leaf handle.
do
  local root = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  local row = builder:AddRow({ frame = Mocks:CreateFrame() })
  local leaf = row:AddChild({ frame = Mocks:CreateFrame() })

  local target = builder:AddChild({ frame = Mocks:CreateFrame(), key = "target" })

  assert(row:GetChild("target") == target)
  assert(leaf:GetChild("target") == target)
end

-- Test: an unknown key throws an error.
do
  local root = Mocks:CreateFrame()
  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })

  local ok, err = pcall(function() builder:GetChild("nope") end)
  assert(not ok)
  assert(tostring(err):find("nope"))
end

-- Test: a duplicate key throws an error.
do
  local root = Mocks:CreateFrame()
  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })

  builder:AddChild({ frame = Mocks:CreateFrame(), key = "dup" })

  local ok, err = pcall(function()
    builder:AddChild({ frame = Mocks:CreateFrame(), key = "dup" })
  end)
  assert(not ok)
  assert(tostring(err):find("dup"))
end

-- Test: a leaf child's `key`, written directly into a declarative
-- `children` table, is found by `GetChild` too, not just builder-added ones.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a, key = "sidebar" } }
  })

  --- @diagnostic disable-next-line: invisible
  assert(builder:GetChild("sidebar").node.frame == a)
end

-- Test: a declarative container child's `key` resolves to a real builder,
-- usable for further composition, not just a leaf handle.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { key = "row", frame = rowFrame, direction = "ROW", children = { { frame = leaf } } },
    }
  })

  local row = builder:GetChild("row")
  row:AddChild({ frame = Mocks:CreateFrame() })
  builder:Layout()

  assert(leaf._test.width ~= nil) -- the row's declarative child still laid out
end

-- Test: a `key` nested two levels deep in a declarative tree is still found.
do
  local root = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local builder = Waffle:Flex({
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
  assert(builder:GetChild("deep").node.frame == leaf)
end

-- Test: a declarative key colliding with a later builder-added key errors,
-- same as two builder-added keys colliding.
do
  local root = Mocks:CreateFrame()

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = Mocks:CreateFrame(), key = "dup" } }
  })

  local ok, err = pcall(function()
    builder:AddChild({ frame = Mocks:CreateFrame(), key = "dup" })
  end)
  assert(not ok)
  assert(tostring(err):find("dup"))
end

-- Test: a keyed grandchild inside a declarative subtree handed to `AddRow`
-- (not the root) is still found, mixing builder and declarative composition.
do
  local root = Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddRow({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    children = { { frame = leaf, key = "mixed" } }
  })

  assert(builder:GetChild("mixed").node.frame == leaf)
end

print("All assertions passed.")
