--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddRow` with no `frame` uses the root's `defaultFrameFactory` to create one.
do
  local root = Mocks:CreateFrame()
  local created

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  container:AddRow()
  container:Layout()

  assert(created ~= nil)
  assert(created._test.width == 200 and created._test.height == 50)
end

-- Test: `AddColumn` with no `frame` uses the root's `defaultFrameFactory` to create one.
do
  local root = Mocks:CreateFrame()
  local created

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  container:AddColumn()
  container:Layout()

  assert(created ~= nil)
end

-- Test: `defaultFrameFactory` reaches every level; a grandchild that also
-- omits `frame`/`frameFactory` still gets one.
do
  local root = Mocks:CreateFrame()
  local createCount = 0

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    defaultFrameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })
  local row = container:AddRow()
  row:AddColumn()
  container:Layout()

  assert(createCount == 2) -- the row itself, and its nested column
end

-- Test: a child with an explicit `frame` never calls `defaultFrameFactory`.
do
  local root = Mocks:CreateFrame()
  local explicit = Mocks:CreateFrame()
  local createCount = 0

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })
  container:AddChild({ frame = explicit })
  container:Layout()

  assert(createCount == 0)
  assert(explicit._test.width == 200)
end

-- Test: a child's own `frameFactory` produces only that child's frame; its
-- nested children fall back to the root's `defaultFrameFactory` instead.
do
  local root = Mocks:CreateFrame()
  local rootCreateCount, overrideCreateCount = 0, 0

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function()
      rootCreateCount = rootCreateCount + 1
      return Mocks:CreateFrame()
    end
  })
  local row = container:AddRow({
    frameFactory = function()
      overrideCreateCount = overrideCreateCount + 1
      return Mocks:CreateFrame()
    end
  })
  row:AddColumn() -- no frame/frameFactory: falls back to the root default

  container:Layout()

  assert(overrideCreateCount == 1) -- only the row itself used its own override
  assert(rootCreateCount == 1)     -- the row's nested column fell back to the root default
end

-- Test: a child with neither `frame` nor an available factory errors clearly.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddRow()

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("frameFactory"))
end

-- Test: a root with only its own `defaultFrameFactory`, no `frame` or
-- `frameFactory` of its own, errors too, `defaultFrameFactory` never
-- resolves the node that declares it, root included.
do
  local container = Waffle:Flex({
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function() return Mocks:CreateFrame() end
  })

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("frameFactory"))
end

-- Test: giving both `frame` and `frameFactory` on the same child throws an error.
do
  local root = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({
    frame = Mocks:CreateFrame(),
    frameFactory = function() return Mocks:CreateFrame() end
  })

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("frame"))
end

-- Test: both `defaultFrameFactory` and a child's own `frameFactory` receive
-- the resolved parent as an argument.
do
  local root = Mocks:CreateFrame()
  local defaultReceivedParent, ownReceivedParent

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    defaultFrameFactory = function(parent)
      defaultReceivedParent = parent
      return Mocks:CreateFrame()
    end
  })
  container:AddRow() -- uses the default factory
  container:AddChild({
    frameFactory = function(parent)
      ownReceivedParent = parent
      return Mocks:CreateFrame()
    end
  })
  container:Layout()

  assert(defaultReceivedParent == root)
  assert(ownReceivedParent == root)
end

-- Test: `defaultFrameFactory` receives the immediate parent at each level
-- of nesting, not always the root.
do
  local root = Mocks:CreateFrame()
  local middle = Mocks:CreateFrame()
  local receivedParent

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    defaultFrameFactory = function(parent)
      receivedParent = parent
      return Mocks:CreateFrame()
    end
  })
  local row = container:AddRow({ frame = middle })
  row:AddColumn() -- two levels deep, no frame/frameFactory of its own

  container:Layout()

  assert(receivedParent == middle)
end

-- Test: a nested container's own `defaultFrameFactory` overrides the
-- root's, for everything below it; the root's default doesn't reach past it.
do
  local root = Mocks:CreateFrame()
  local rootDefaultFrame, rowDefaultFrame = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    defaultFrameFactory = function()
      return rootDefaultFrame
    end
  })
  local row = container:AddRow({
    defaultFrameFactory = function()
      return rowDefaultFrame
    end
  })
  local column = row:AddColumn()

  container:Layout()

  assert(row:GetFrame() == rootDefaultFrame)   -- the row resolved from the root's default
  assert(column:GetFrame() == rowDefaultFrame) -- the column resolved from the row's default
end

-- Test: a factory only runs once, even across repeated `Layout()` calls.
do
  local root = Mocks:CreateFrame()
  local createCount = 0

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({
    frameFactory = function()
      createCount = createCount + 1
      return Mocks:CreateFrame()
    end
  })

  container:Layout()
  container:Layout()

  assert(createCount == 1)
end

-- Test: the same defaulting works for the fully declarative style too, not
-- just children added through the container.
do
  local root = Mocks:CreateFrame()
  local created

  Waffle:Flex({
    frame = root,
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

-- Test: `GetFrame()` returns an explicit `frame` immediately, no `Layout()` needed.
do
  local root = Mocks:CreateFrame()
  local explicit = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = explicit })

  assert(leaf:GetFrame() == explicit)
end

-- Test: `GetFrame()` on a `frameFactory` child is `nil` until the first
-- `Layout()` actually resolves it, then returns the resolved frame.
do
  local root = Mocks:CreateFrame()
  local created

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({
    frameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })

  assert(leaf:GetFrame() == nil)

  container:Layout()

  assert(leaf:GetFrame() == created)
end

print("All assertions passed.")
