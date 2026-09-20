--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `height = "AUTO"` on a ROW node (its own cross axis) is the max of
-- its children's own `height`, plus `padding` on both ends, not a sum.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        padding = 5,
        children = {
          { frame = a, height = 20 },
          { frame = b, height = 45 },
          { frame = c, height = 30 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 55) -- max(20, 45, 30) + padding*2(10)
end

-- Test: `width = "AUTO"` on a COLUMN node (its own cross axis) works the
-- same way, along width instead of height.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 200,
    children = {
      {
        frame = autoFrame,
        direction = "COLUMN",
        height = 150,
        width = "AUTO",
        children = {
          { frame = a, width = 15 },
          { frame = b, width = 50 },
          { frame = c, width = 25 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.width == 50) -- max(15, 50, 25)
end

-- Test: a flexible child (no `height` of its own) inside a cross-axis
-- `"AUTO"` node errors.
do
  local parent = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = parent, direction = "ROW", width = 400, height = 50 })
  local auto = container:AddChild({ frame = Mocks:CreateFrame(), direction = "ROW", width = 200, height = "AUTO", children = {} })
  auto:AddChild({ frame = Mocks:CreateFrame() }) -- no height, flexible

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("flexible"))
end

-- Test: a `"GONE"` child is excluded from a cross-axis `"AUTO"` max.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        children = {
          { frame = a, height = 20 },
          { frame = b, height = 100, visibility = "GONE" },
          { frame = c, height = 30 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 30) -- b (100) excluded, max(20, 30)
end

-- Test: an `"INVISIBLE"` child is included in a cross-axis `"AUTO"` max.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        children = {
          { frame = a, height = 20 },
          { frame = b, height = 100, visibility = "INVISIBLE" },
          { frame = c, height = 30 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 100) -- b (100) still counts, max(20, 100, 30)
end

-- Test: cross-axis `"AUTO"` recurses through a nested cross-axis `"AUTO"`
-- child automatically.
do
  local parent = Mocks:CreateFrame()
  local outer = Mocks:CreateFrame()
  local inner = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = outer,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        children = {
          {
            frame = inner,
            direction = "ROW",
            width = 200,
            height = "AUTO",
            children = {
              { frame = a, height = 15 },
              { frame = b, height = 35 },
            }
          }
        }
      }
    }
  }):Layout()

  assert(inner._test.height == 35) -- max(15, 35)
  assert(outer._test.height == 35) -- inner's own AUTO height, nothing else beside it
end

-- Test: main-axis `"AUTO"` (sum) and cross-axis `"AUTO"` (max) on the same
-- node compute independently.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = "AUTO",
        height = "AUTO",
        gap = 10,
        children = {
          { frame = a, width = 20, height = 15 },
          { frame = b, width = 30, height = 40 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.width == 60)  -- 20 + 30 + gap(10), main-axis sum
  assert(autoFrame._test.height == 40) -- max(15, 40), cross-axis max
end

-- Test: root's own cross axis can be `"AUTO"` too, the same as any node's.
do
  local frame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = frame,
    direction = "ROW",
    width = 300,
    height = "AUTO",
    children = {
      { frame = a, height = 20 },
      { frame = b, height = 45 },
    }
  }):Layout()

  assert(frame._test.width == 300)
  assert(frame._test.height == 45) -- max(20, 45), root's own cross axis
end

-- Test: cross-axis `"AUTO"` on a wrapped container sums each line's own
-- max, rather than one flat max over every child regardless of line.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 100,
        height = "AUTO",
        wrap = true,
        children = {
          { frame = a, width = 60, height = 30 }, -- line 1
          { frame = b, width = 60, height = 40 }, -- doesn't fit alongside a, line 2
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 70) -- line 1's 30 + line 2's 40, not max(30, 40)
end

-- Test: cross-axis `"AUTO"` on a wrapped container also accounts for
-- `gap` between lines, not just each line's own max; omitting it would
-- under-report the space its own children actually occupy once
-- `flexLayout` positions them for real.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 100,
        height = "AUTO",
        wrap = true,
        gap = 10,
        children = {
          { frame = a, width = 60, height = 30 }, -- line 1
          { frame = b, width = 60, height = 40 }, -- doesn't fit alongside a, line 2
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 80) -- 30 + 40 + gap(10), not 70
  assert(b._test.point.offsetY == -40) -- line 2 actually starts at 30 + gap(10)
end

-- Test: `wrap` on a cross-axis `"AUTO"` node that never actually wraps
-- (everything fits on one line) still degenerates to the original flat
-- max, unaffected by being lines-aware now.
do
  local parent = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 400,
    height = 50,
    children = {
      {
        frame = autoFrame,
        direction = "ROW",
        width = 200,
        height = "AUTO",
        wrap = true,
        children = {
          { frame = a, width = 60, height = 30 },
          { frame = b, width = 60, height = 40 },
        }
      }
    }
  }):Layout()

  assert(autoFrame._test.height == 40) -- both fit on one line, max(30, 40)
end

-- Test: cross-axis `"AUTO"` on a wrapping node with a stretched width counts
-- the lines that width produces. Eight 32-wide icons with `gap` 4 fit five to a
-- 200-wide line.
do
  local gridFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 8 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 200,
    height = 400,
    children = {
      { frame = gridFrame, direction = "ROW", height = "AUTO", wrap = true, gap = 4, lineGap = 4, children = icons }
    }
  }):Layout()

  assert(gridFrame._test.width == 200)
  assert(gridFrame._test.height == 68) -- two lines: 32 + 4 + 32
  assert(icons[6].frame._test.point.offsetY == -36) -- the sixth icon starts line two
end

-- Test: the stretched width `"AUTO"` wraps against is what is left after the
-- parent's `padding` and the node's own `margin`.
do
  local gridFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 10 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 200,
    height = 400,
    padding = 10,
    children = {
      {
        frame = gridFrame,
        direction = "ROW",
        height = "AUTO",
        wrap = true,
        gap = 4,
        lineGap = 4,
        margin = 10,
        children = icons
      }
    }
  }):Layout()

  assert(gridFrame._test.width == 160) -- 200 - padding 20 - margin 20
  assert(gridFrame._test.height == 104) -- four to a line, so three lines: 32 * 3 + 4 * 2
end

-- Test: a stretched width clamped by `maxWidth` is the width `"AUTO"` wraps
-- against.
do
  local gridFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 8 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 200,
    height = 400,
    children = {
      {
        frame = gridFrame,
        direction = "ROW",
        height = "AUTO",
        maxWidth = 100,
        wrap = true,
        gap = 4,
        lineGap = 4,
        children = icons
      }
    }
  }):Layout()

  assert(gridFrame._test.width == 100)
  assert(gridFrame._test.height == 140) -- two to a line, so four lines: 32 * 4 + 4 * 3
end

-- Test: cross-axis `"AUTO"` on a wrapping node whose width is flexed by a ROW
-- parent counts the lines that width produces.
do
  local gridFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 8 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    width = 300,
    height = 400,
    children = {
      { frame = Mocks:CreateFrame(), width = 100 },
      { frame = gridFrame, direction = "ROW", height = "AUTO", wrap = true, gap = 4, lineGap = 4, children = icons },
    }
  }):Layout()

  assert(gridFrame._test.width == 200) -- 300 - 100
  assert(gridFrame._test.height == 68) -- five to a line, so two lines
end

-- Test: the same holds along the other axis, a wrapping COLUMN node with
-- `width = "AUTO"` and a height stretched by a ROW parent counts its columns.
do
  local gridFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 8 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    width = 400,
    height = 100,
    children = {
      { frame = gridFrame, direction = "COLUMN", width = "AUTO", wrap = true, gap = 4, lineGap = 4, children = icons },
    }
  }):Layout()

  assert(gridFrame._test.height == 100)
  assert(gridFrame._test.width == 140) -- two to a column, so four columns: 32 * 4 + 4 * 3
end

-- Test: a main-axis `"AUTO"` container sizes to its wrapping child's lines when
-- its own width is fixed.
do
  local gridFrame = Mocks:CreateFrame()
  local containerFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 8 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = containerFrame,
    direction = "COLUMN",
    width = 200,
    height = "AUTO",
    children = {
      { frame = gridFrame, direction = "ROW", height = "AUTO", wrap = true, gap = 4, lineGap = 4, children = icons }
    }
  }):Layout()

  assert(gridFrame._test.height == 68)
  assert(containerFrame._test.height == 68)
end

-- Test: the width a wrapping node is stretched to reaches it through a nested
-- `"AUTO"` container.
do
  local gridFrame = Mocks:CreateFrame()
  local containerFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 8 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 200,
    height = 400,
    children = {
      {
        frame = containerFrame,
        direction = "COLUMN",
        height = "AUTO",
        children = {
          { frame = gridFrame, direction = "ROW", height = "AUTO", wrap = true, gap = 4, lineGap = 4, children = icons }
        }
      }
    }
  }):Layout()

  assert(containerFrame._test.height == 68)
  assert(gridFrame._test.height == 68)
end

-- Test: the width a wrapping node wraps against inside a nested `"AUTO"`
-- container excludes that container's own padding.
do
  local gridFrame = Mocks:CreateFrame()
  local containerFrame = Mocks:CreateFrame()
  local icons = {}
  for i = 1, 6 do icons[i] = { frame = Mocks:CreateFrame(), width = 32, height = 32 } end

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 220,
    height = 400,
    children = {
      {
        frame = containerFrame,
        direction = "COLUMN",
        padding = 10,
        height = "AUTO",
        children = {
          { frame = gridFrame, direction = "ROW", height = "AUTO", wrap = true, gap = 4, lineGap = 4, children = icons }
        }
      }
    }
  }):Layout()

  assert(gridFrame._test.width == 200) -- 220 - 20
  assert(gridFrame._test.height == 68) -- five to a line, so two lines
  assert(containerFrame._test.height == 88) -- 68 + 20
end

-- Test: an `"AUTO"` container with a percentage width and no parent size to
-- resolve it against still sizes from its children.
do
  local containerFrame = Mocks:CreateFrame()

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 200,
    height = "AUTO",
    children = {
      {
        frame = containerFrame,
        direction = "COLUMN",
        width = "50%",
        height = "AUTO",
        children = { { frame = Mocks:CreateFrame(), height = 10 } }
      }
    }
  }):Layout()

  assert(containerFrame._test.width == 100)
  assert(containerFrame._test.height == 10)
end

print("All assertions passed.")
