--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddRow` with no `frame` uses the root's `defaultFrameFactory` to create one.
do
  local root = Mocks:CreateFrame()
  local created

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  builder:AddRow()
  builder:Layout()

  assert(created ~= nil)
  assert(created._test.width == 200 and created._test.height == 50)
end

-- Test: `AddColumn` with no `frame` uses the root's `defaultFrameFactory` to create one.
do
  local root = Mocks:CreateFrame()
  local created

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  builder:AddColumn()
  builder:Layout()

  assert(created ~= nil)
end

-- Test: `defaultFrameFactory` reaches every level; a grandchild that also
-- omits `frame`/`frameFactory` still gets one.
do
  local root = Mocks:CreateFrame()
  local createCount = 0

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 100,
    defaultFrameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })
  local row = builder:AddRow()
  row:AddColumn()
  builder:Layout()

  assert(createCount == 2) -- the row itself, and its nested column
end

-- Test: a child with an explicit `frame` never calls `defaultFrameFactory`.
do
  local root = Mocks:CreateFrame()
  local explicit = Mocks:CreateFrame()
  local createCount = 0

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })
  builder:AddChild({ frame = explicit })
  builder:Layout()

  assert(createCount == 0)
  assert(explicit._test.width == 200)
end

-- Test: a child's own `frameFactory` produces only that child's frame; its
-- nested children fall back to the root's `defaultFrameFactory` instead.
do
  local root = Mocks:CreateFrame()
  local rootCreateCount, overrideCreateCount = 0, 0

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
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
  row:AddColumn() -- no frame/frameFactory: falls back to the root default

  builder:Layout()

  assert(overrideCreateCount == 1) -- only the row itself used its own override
  assert(rootCreateCount == 1)     -- the row's nested column fell back to the root default
end

-- Test: a child with neither `frame` nor an available factory errors clearly.
do
  local root = Mocks:CreateFrame()
  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddRow()

  local ok, err = pcall(function() builder:Layout() end)
  assert(not ok)
  assert(tostring(err):find("frameFactory"))
end

-- Test: giving both `frame` and `frameFactory` on the same child throws an error.
do
  local root = Mocks:CreateFrame()
  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddChild({
    frame = Mocks:CreateFrame(),
    frameFactory = function() return Mocks:CreateFrame() end
  })

  local ok, err = pcall(function() builder:Layout() end)
  assert(not ok)
  assert(tostring(err):find("frame"))
end

-- Test: both `defaultFrameFactory` and a child's own `frameFactory` receive
-- the resolved parent as an argument.
do
  local root = Mocks:CreateFrame()
  local defaultReceivedParent, ownReceivedParent

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function(parent)
      defaultReceivedParent = parent
      return Mocks:CreateFrame()
    end
  })
  builder:AddRow() -- uses the default factory
  builder:AddChild({
    frameFactory = function(parent)
      ownReceivedParent = parent
      return Mocks:CreateFrame()
    end
  })
  builder:Layout()

  assert(defaultReceivedParent == root)
  assert(ownReceivedParent == root)
end

-- Test: `defaultFrameFactory` receives the immediate parent at each level
-- of nesting, not always the root.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local receivedParent

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 100,
    defaultFrameFactory = function(parent)
      receivedParent = parent
      return Mocks:CreateFrame()
    end
  })
  local row = builder:AddRow({ frame = middle })
  row:AddColumn() -- two levels deep, no frame/frameFactory of its own

  builder:Layout()

  assert(receivedParent == middle)
end

-- Test: a factory only runs once, even across repeated `Layout()` calls.
do
  local root = Mocks:CreateFrame()
  local createCount = 0

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddChild({
    frameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })

  builder:Layout()
  builder:Layout()

  assert(createCount == 1)
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
    defaultFrameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end,
    children = { { direction = "COLUMN", children = { { frame = Mocks:CreateFrame() } } } }
  }):Layout()

  assert(created ~= nil)
end

print("All assertions passed.")
