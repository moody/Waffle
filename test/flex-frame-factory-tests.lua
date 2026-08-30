--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddRow` with no `frame` uses the root's `frameFactory` to create one.
do
  local root = Mocks:CreateFrame()
  local created

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    frameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  builder:AddRow()
  builder:Layout()

  assert(created ~= nil)
  assert(created._test.width == 200 and created._test.height == 50)
end

-- Test: `AddColumn` with no `frame` uses the root's `frameFactory` to create one.
do
  local root = Mocks:CreateFrame()
  local created

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    frameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  builder:AddColumn()
  builder:Layout()

  assert(created ~= nil)
end

-- Test: `frameFactory` is inherited through nested containers, a grandchild
-- row that also omits `frame` still gets one from the same root factory.
do
  local root = Mocks:CreateFrame()
  local createCount = 0

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 100,
    frameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })
  local row = builder:AddRow()
  row:AddColumn()
  builder:Layout()

  assert(createCount == 2) -- the row itself, and its nested column
end

-- Test: a child with an explicit `frame` never calls `frameFactory`.
do
  local root = Mocks:CreateFrame()
  local explicit = Mocks:CreateFrame()
  local createCount = 0

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    frameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })
  builder:AddChild({ frame = explicit })
  builder:Layout()

  assert(createCount == 0)
  assert(explicit._test.width == 200)
end

-- Test: a child's own `frameFactory` overrides the inherited one, for
-- itself and for its own nested children.
do
  local root = Mocks:CreateFrame()
  local rootCreateCount, overrideCreateCount = 0, 0

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    frameFactory = function()
      rootCreateCount = rootCreateCount + 1
      return Mocks:CreateFrame()
    end
  })
  local row = builder:AddRow({
    frameFactory = function()
      overrideCreateCount = overrideCreateCount + 1
      return Mocks:CreateFrame()
    end
  })
  row:AddColumn() -- also omits frame, should use the row's override, not the root's

  builder:Layout()

  assert(rootCreateCount == 0)
  assert(overrideCreateCount == 2) -- the row itself, and its nested column
end

-- Test: a child with neither `frame` nor an available `frameFactory` errors clearly.
do
  local root = Mocks:CreateFrame()
  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddRow()

  local ok, err = pcall(function() builder:Layout() end)
  assert(not ok)
  assert(tostring(err):find("frameFactory"))
end

-- Test: the same defaulting works for the fully declarative style too, not
-- just children added through the builder.
do
  local root = Mocks:CreateFrame()
  local created

  Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    frameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end,
    children = { { direction = "COLUMN", children = { { frame = Mocks:CreateFrame() } } } }
  }):Layout()

  assert(created ~= nil)
end

print("All assertions passed.")
