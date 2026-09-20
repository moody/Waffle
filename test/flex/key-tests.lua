--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddChild` with a `key` registers the child, retrievable via
-- `FindByKey` on the root.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, key = "sidebar" })

  assert(container:FindByKey("sidebar"):GetFrame() == a)
end

-- Test: `AddRow`/`AddColumn` with a `key` register the returned component
-- the same way.
do
  local root = Mocks:CreateFrame()
  local rowFrame, columnFrame = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddRow({ frame = rowFrame, key = "toolbar" })
  container:AddColumn({ frame = columnFrame, key = "sidebar" })

  assert(container:FindByKey("toolbar"):GetFrame() == rowFrame)
  assert(container:FindByKey("sidebar"):GetFrame() == columnFrame)
end

-- Test: `FindByKey` works from anywhere in the tree, not just the root.
do
  local root = Mocks:CreateFrame()
  local targetFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame() })
  local child = row:AddChild({ frame = Mocks:CreateFrame() })
  container:AddChild({ frame = targetFrame, key = "target" })

  assert(row:FindByKey("target"):GetFrame() == targetFrame)
  assert(child:FindByKey("target"):GetFrame() == targetFrame)
end

-- Test: an unknown key throws an error.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })

  local ok, err = pcall(function() container:FindByKey("nope") end)
  assert(not ok)
  assert(tostring(err):find("nope"))
end

-- Test: a duplicate key doesn't error, the first match found wins, a
-- declarative child before one added later.
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

  assert(container:FindByKey("dup"):GetFrame() == a)
end

-- Test: a `key` written into a declarative `children` table is found at any
-- depth, including inside a declarative subtree handed to `AddRow`.
do
  local root = Mocks:CreateFrame()
  local shallow, deep, mixed = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = shallow, key = "shallow" },
      { direction = "ROW", children = { { frame = deep, key = "deep" } } },
    }
  })
  container:AddRow({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    children = { { frame = mixed, key = "mixed" } }
  })

  assert(container:FindByKey("shallow"):GetFrame() == shallow)
  assert(container:FindByKey("deep"):GetFrame() == deep)
  assert(container:FindByKey("mixed"):GetFrame() == mixed)
end

-- Test: a declarative child's `key` resolves to a component usable for
-- further composition.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local declared = Mocks:CreateFrame()
  local added = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { key = "row", frame = rowFrame, direction = "ROW", children = { { frame = declared } } },
    }
  })

  container:FindByKey("row"):AddChild({ frame = added })
  container:Layout()

  assert(declared._test.width == 100 and added._test.width == 100)
end

-- Test: `SetKey` registers (or changes) a node's own key for `FindByKey`
-- lookup.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })

  leaf:SetKey("a")
  assert(container:FindByKey("a"):GetFrame() == a)

  leaf:SetKey("b")
  assert(container:FindByKey("b"):GetFrame() == a)

  local ok = pcall(function() container:FindByKey("a") end)
  assert(not ok) -- old key no longer registered
end

print("All assertions passed.")
