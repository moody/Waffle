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

print("All assertions passed.")
