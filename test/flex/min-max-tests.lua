--- @diagnostic disable: undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `maxWidth` caps a flexible child's share of the leftover space,
-- the excess goes to its uncapped sibling instead of being dropped.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a },                -- flexible, would be 150 unclamped
      { frame = b, maxWidth = 50 }, -- flexible, capped below its 150 share
    }
  }):Layout()

  assert(a._test.width == 250) -- 300 - 50
  assert(b._test.width == 50)
end

-- Test: `minWidth` floors a flexible child's share, the deficit comes out
-- of its unfloored sibling instead of overflowing the container.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a },                 -- flexible, would be 150 unclamped
      { frame = b, minWidth = 200 }, -- flexible, floored above its 150 share
    }
  }):Layout()

  assert(a._test.width == 100) -- 300 - 200
  assert(b._test.width == 200)
end

-- Test: `gap` comes out of the available space before `min`/`max`
-- clamping runs on what's left, not layered on top of it afterward.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 310,
    height = 50,
    gap = 10,
    children = {
      { frame = a },                -- flexible, uncapped
      { frame = b, maxWidth = 50 }, -- would be 155 if the gap were ignored
    }
  }):Layout()

  assert(a._test.width == 250)         -- 310 - 10 (gap) - 50
  assert(b._test.width == 50)
  assert(b._test.point.offsetX == 260) -- right after a, plus the gap
end

-- Test: capping one child can push a second child's own share over its
-- own cap too, once the first child's freed space gets redistributed.
-- Both need to end up clamped, not just the one caught on the first pass.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a },                 -- flexible, uncapped
      { frame = b, maxWidth = 100 }, -- would be 125 once c is capped
      { frame = c, maxWidth = 50 },  -- would be 100 unclamped, capped first
    }
  }):Layout()

  assert(c._test.width == 50)
  assert(b._test.width == 100)
  assert(a._test.width == 150) -- 300 - 50 - 100
end

-- Test: a min violation and a max violation among different children,
-- both caught in the same pass, are both applied correctly.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, minWidth = 120 }, -- would be 100 unclamped, floored up
      { frame = b, maxWidth = 30 },  -- would be 100 unclamped, capped down
    }
  }):Layout()

  assert(a._test.width == 120)
  assert(b._test.width == 30)
end

-- Test: `minWidth`/`maxWidth` have no effect on a child with its own
-- explicit `width`, only a flexible child's computed share is clamped.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 250, minWidth = 10, maxWidth = 20 }, -- explicit, ignores both
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 250)
  assert(b._test.width == 50)
end

-- Test: `minWidth` wins over the available space entirely, overflowing
-- the container, when there's less leftover than the floor asks for.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 50,
    height = 50,
    children = {
      { frame = a, minWidth = 200 },
    }
  }):Layout()

  assert(a._test.width == 200)
end

-- Test: `minHeight`/`maxHeight` work the same way on a COLUMN, main axis
-- there is height instead of width.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 50,
    height = 300,
    children = {
      { frame = a },
      { frame = b, maxHeight = 100 },
    }
  }):Layout()

  assert(a._test.height == 200) -- 300 - 100
  assert(b._test.height == 100)
end

-- Test: once every flexible child on a line ends up clamped, the space
-- none of them claimed flows to `justify` instead of being dropped.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    justify = "END",
    children = {
      { frame = a, minWidth = 120 }, -- floored up, still leaves 50 unclaimed
      { frame = b, maxWidth = 30 },  -- capped down
    }
  }):Layout()

  assert(a._test.width == 120)
  assert(b._test.width == 30)
  assert(a._test.point.offsetX == 50)  -- the 50 unclaimed pushed both to the end
  assert(b._test.point.offsetX == 170) -- right after a
end

-- Test: `minWidth` greater than `maxWidth` on the same node is a
-- misconfiguration, not a silently-picked winner.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, minWidth = 100, maxWidth = 50 })

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("minWidth"))
end

-- Test: the same misconfiguration check applies to `minHeight`/
-- `maxHeight` on a COLUMN, naming the matching field in the error.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "COLUMN", width = 50, height = 200 })
  container:AddChild({ frame = a, minHeight = 100, maxHeight = 50 })

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("minHeight"))
end

-- Test: `minWidth`/`maxWidth` are resolved per line under `wrap`, one
-- line's clamping doesn't affect another line's leftover.
do
  local root = Mocks:CreateFrame()
  local fixed1, flexA, fixed2, flexB, flexC =
      Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 100,
    height = 50,
    wrap = true,
    children = {
      { frame = fixed1, width = 40 },    -- line 1
      { frame = flexA },                 -- line 1, uncapped, leftover 60
      { frame = fixed2, width = 70 },    -- doesn't fit alongside line 1, starts line 2
      { frame = flexB,  maxWidth = 10 }, -- line 2, capped below its 15 share
      { frame = flexC },                 -- line 2, takes flexB's excess
    }
  }):Layout()

  assert(flexA._test.width == 60) -- line 1's own leftover, unaffected by line 2's cap
  assert(flexB._test.width == 10)
  assert(flexC._test.width == 20) -- line 2 leftover 30, minus flexB's capped 10
end

-- Test: `maxHeight` caps a `STRETCH`-ed child's cross-axis size in a ROW
-- container, the same as `maxWidth` caps a main-axis share.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    children = {
      { frame = a, maxHeight = 40 }, -- would stretch to 100 uncapped
    }
  }):Layout()

  assert(a._test.height == 40)
end

-- Test: `minHeight` floors a `STRETCH`-ed child's cross-axis size the same
-- way, overflowing the container if the floor is taller than it is.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    children = {
      { frame = a, minHeight = 150 },
    }
  }):Layout()

  assert(a._test.height == 150)
end

-- Test: `minHeight`/`maxHeight` have no effect on a child with its own
-- explicit `height`, only a `STRETCH`-ed cross size is clamped.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    children = {
      { frame = a, height = 50, minHeight = 80, maxHeight = 90 }, -- explicit, ignores both
    }
  }):Layout()

  assert(a._test.height == 50)
end

-- Test: `minHeight`/`maxHeight` have no effect under non-`STRETCH`
-- alignment either, that always needs its own explicit cross size too.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    align = "CENTER",
    children = {
      { frame = a, height = 30, minHeight = 80 },
    }
  }):Layout()

  assert(a._test.height == 30)
end

-- Test: cross-axis clamping flips with direction, `maxWidth` caps a
-- `STRETCH`-ed width on a COLUMN container.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 100,
    height = 200,
    children = {
      { frame = a, maxWidth = 40 }, -- would stretch to 100 uncapped
    }
  }):Layout()

  assert(a._test.width == 40)
end

-- Test: `minHeight` greater than `maxHeight` is a misconfiguration on the
-- cross axis too, not just the main axis.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  container:AddChild({ frame = a, minHeight = 100, maxHeight = 50 })

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("minHeight"))
end

print("All assertions passed.")
