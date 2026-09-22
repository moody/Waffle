--- @diagnostic disable: assign-type-mismatch, param-type-mismatch

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- =============================================================================
-- Setup
-- =============================================================================

local WORD_WIDTH = 20
local LINE_HEIGHT = 10

--- Returns an `onMeasure` for a paragraph of `words` words. Each word is
--- `WORD_WIDTH` wide and each line `LINE_HEIGHT` tall, and the words wrap to
--- the width given. Records what it was called with in `calls`.
--- @param words integer
--- @param calls? table[]
--- @return fun(frame: WaffleMockFrame, width?: number, height?: number): number, number
local function Paragraph(words, calls)
  return function(frame, width, height)
    if calls then calls[#calls + 1] = { frame = frame, width = width, height = height } end
    if width then
      local perLine = math.max(math.floor(width / WORD_WIDTH), 1)
      return width, math.ceil(words / perLine) * LINE_HEIGHT
    end
    return words * WORD_WIDTH, LINE_HEIGHT
  end
end

-- =============================================================================
-- Tests
-- =============================================================================

-- Test: a stretched width is passed as the known width, and the `"AUTO"` height
-- is what `onMeasure` returns for it.
do
  local text = Mocks:CreateFrame()
  local calls = {}

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 100,
    height = 300,
    children = { { frame = text, height = "AUTO", onMeasure = Paragraph(10, calls) } }
  }):Layout()

  assert(text._test.width == 100)
  assert(text._test.height == 20) -- five words to a line, so two lines
  assert(calls[1].frame == text) -- the node's own frame
  assert(calls[1].width == 100 and calls[1].height == nil)
end

-- Test: with `"AUTO"` width and height, the natural size is used.
do
  local text = Mocks:CreateFrame()
  local calls = {}

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    width = 400,
    height = 100,
    children = { { frame = text, width = "AUTO", height = "AUTO", onMeasure = Paragraph(10, calls) } }
  }):Layout()

  assert(text._test.width == 200) -- 10 words of 20
  assert(text._test.height == 10)
  assert(calls[1].frame == text and calls[1].width == nil) -- asked for the width
end

-- Test: a child whose width is flexible is measured for the width it ends up
-- with, and its `"AUTO"`-height parent is as tall as the result.
do
  local row = Mocks:CreateFrame()
  local text = Mocks:CreateFrame()

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 300,
    height = 400,
    children = {
      {
        frame = row,
        direction = "ROW",
        height = "AUTO",
        children = {
          { frame = Mocks:CreateFrame(), width = 100, height = 5 },
          { frame = text, height = "AUTO", onMeasure = Paragraph(30) },
        }
      }
    }
  }):Layout()

  assert(text._test.width == 200) -- 300 - 100
  assert(text._test.height == 30) -- ten words to a line, so three lines
  assert(row._test.height == 30)
end

-- Test: a child that shrinks is measured for the width it shrinks to.
do
  local text = Mocks:CreateFrame()

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    width = 300,
    height = 200,
    children = {
      { frame = Mocks:CreateFrame(), width = 100, shrink = 0 },
      { frame = text, width = "AUTO", height = "AUTO", onMeasure = Paragraph(30) },
    }
  }):Layout()

  assert(text._test.width == 200) -- 600 natural, shrunk to 300 - 100
  assert(text._test.height == 30) -- ten words to a line, so three lines
end

-- Test: measured children in a wrapping parent wrap by their measured width,
-- and the line is as tall as its tallest child.
do
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    wrap = true,
    width = 300,
    height = 200,
    children = {
      { frame = a, width = "AUTO", height = "AUTO", onMeasure = Paragraph(6) },
      { frame = b, width = "AUTO", height = "AUTO", onMeasure = Paragraph(6) },
      { frame = c, width = "AUTO", height = "AUTO", onMeasure = Paragraph(6) },
    }
  }):Layout()

  assert(a._test.point.offsetY == 0 and b._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 120)
  assert(c._test.point.offsetX == 0 and c._test.point.offsetY == -LINE_HEIGHT) -- 360 would not fit in 300
end

-- Test: `maxWidth` limits the stretched width the node is measured for.
do
  local text = Mocks:CreateFrame()
  local calls = {}

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 300,
    height = 300,
    children = { { frame = text, maxWidth = 100, height = "AUTO", onMeasure = Paragraph(10, calls) } }
  }):Layout()

  assert(calls[1].width == 100)
  assert(text._test.width == 100 and text._test.height == 20)
end

-- Test: a percentage width is resolved before the node is measured.
do
  local text = Mocks:CreateFrame()

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 200,
    height = 300,
    children = { { frame = text, width = "50%", height = "AUTO", onMeasure = Paragraph(10) } }
  }):Layout()

  assert(text._test.width == 100)
  assert(text._test.height == 20)
end

-- Test: an `"INVISIBLE"` node is measured and keeps its space, and a `"GONE"`
-- node is never measured and its frame is never created.
do
  local invisible, after = Mocks:CreateFrame(), Mocks:CreateFrame()
  local goneCalls, goneFrames = {}, 0

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 100,
    height = 300,
    children = {
      { frame = invisible, height = "AUTO", visibility = "INVISIBLE", onMeasure = Paragraph(10) },
      {
        frameFactory = function() goneFrames = goneFrames + 1 return Mocks:CreateFrame() end,
        height = "AUTO",
        visibility = "GONE",
        onMeasure = Paragraph(10, goneCalls)
      },
      { frame = after, height = 10 },
    }
  }):Layout()

  assert(invisible._test.visible == false)
  assert(after._test.point.offsetY == -20) -- below the invisible node's two lines
  assert(#goneCalls == 0 and goneFrames == 0)
end

-- Test: the node's frame is created when it is first measured, under its
-- parent's frame, once, even when the parent's own size is `"AUTO"`.
do
  local created = {}
  local parentFrame = Mocks:CreateFrame()
  local textFrame = Mocks:CreateFrame()
  local textParent

  Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 100,
    height = 300,
    children = {
      {
        frameFactory = function() created.parent = (created.parent or 0) + 1 return parentFrame end,
        direction = "COLUMN",
        height = "AUTO",
        children = {
          {
            frameFactory = function(parent)
              created.text = (created.text or 0) + 1
              textParent = parent
              return textFrame
            end,
            height = "AUTO",
            onMeasure = Paragraph(10)
          },
        }
      },
    }
  }):Layout()

  assert(created.parent == 1 and created.text == 1)
  assert(textParent == parentFrame)
  assert(parentFrame._test.height == 20)
  assert(textFrame._test.height == 20)
end

-- Test: a frame created for measuring comes from the nearest ancestor's
-- `defaultFrameFactory`, and `WhenFrameReady` callbacks run once.
do
  local made, ready = {}, 0
  local root = Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 100,
    height = 300,
    defaultFrameFactory = function(parent)
      local frame = Mocks:CreateFrame()
      made[#made + 1] = { frame = frame, parent = parent }
      return frame
    end,
    children = { { key = "text", height = "AUTO", onMeasure = Paragraph(10) } }
  })
  root:FindByKey("text"):WhenFrameReady(function() ready = ready + 1 end)
  root:Layout()

  assert(#made == 1 and made[1].parent == root:GetFrame())
  assert(root:FindByKey("text"):GetFrame() == made[1].frame)
  assert(ready == 1)
end

-- Test: a frame created for measuring comes from the nearest ancestor that has
-- a `defaultFrameFactory`, not only its parent.
do
  local rootMade, containerMade = 0, 0
  local text = Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 100,
    height = 300,
    defaultFrameFactory = function() rootMade = rootMade + 1 return Mocks:CreateFrame() end,
    children = {
      {
        direction = "COLUMN",
        height = "AUTO",
        children = {
          {
            direction = "COLUMN",
            height = "AUTO",
            children = { { key = "text", height = "AUTO", onMeasure = Paragraph(10) } }
          },
        }
      },
    }
  })
  text:Layout()
  assert(rootMade == 3) -- both containers and the leaf

  local nearer = Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "COLUMN",
    width = 100,
    height = 300,
    defaultFrameFactory = function() rootMade = rootMade + 1 return Mocks:CreateFrame() end,
    children = {
      {
        direction = "COLUMN",
        height = "AUTO",
        defaultFrameFactory = function() containerMade = containerMade + 1 return Mocks:CreateFrame() end,
        children = {
          {
            direction = "COLUMN",
            height = "AUTO",
            children = { { height = "AUTO", onMeasure = Paragraph(10) } }
          },
        }
      },
    }
  })
  nearer:Layout()
  assert(rootMade == 4 and containerMade == 2) -- the outer container from the root's, the rest from its own
end

-- Test: `SetOnMeasure` replaces the callback for the next `Layout()` call, and
-- `GetOnMeasure` returns it.
do
  local text = Mocks:CreateFrame()
  local container = Waffle:Flex({ frame = Mocks:CreateFrame(), direction = "COLUMN", width = 100, height = 300 })
  local leaf = container:AddChild({ frame = text, height = "AUTO" })
  local first, second = Paragraph(10), Paragraph(30)

  assert(leaf:GetOnMeasure() == nil)
  leaf:SetOnMeasure(first)
  assert(leaf:GetOnMeasure() == first)
  container:Layout()
  assert(text._test.height == 20)

  leaf:SetOnMeasure(second)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(text._test.height == 60) -- five to a line, so six lines
end

-- Test: `MarkDirty` makes `onMeasure` run again with the content's new
-- size, applied on the next `Layout()`.
do
  local text = Mocks:CreateFrame()
  local words = 10
  local container = Waffle:Flex({ frame = Mocks:CreateFrame(), direction = "COLUMN", width = 100, height = 300 })
  local leaf = container:AddChild({
    frame = text,
    height = "AUTO",
    onMeasure = function(_, width) return Paragraph(words)(nil, width) end
  })
  container:Layout()
  assert(text._test.height == 20) -- five words to a line, so two lines

  words = 30
  leaf:MarkDirty()
  container:Layout()
  assert(text._test.height == 60) -- six lines
end


-- Test: an `onMeasure` node with `children` throws an error when it is measured.
do
  local ok, err = pcall(function()
    Waffle:Flex({
      frame = Mocks:CreateFrame(),
      direction = "COLUMN",
      width = 100,
      height = 300,
      children = {
        {
          frame = Mocks:CreateFrame(),
          height = "AUTO",
          onMeasure = Paragraph(10),
          children = { { frame = Mocks:CreateFrame(), height = 10 } }
        },
      }
    }):Layout()
  end)

  assert(not ok)
  assert(tostring(err):find("onMeasure", 1, true), tostring(err))
end

-- Test: an `onMeasure` that does not return a number for the axis throws an
-- error naming `onMeasure`.
do
  local ok, err = pcall(function()
    Waffle:Flex({
      frame = Mocks:CreateFrame(),
      direction = "COLUMN",
      width = 100,
      height = 300,
      children = { { frame = Mocks:CreateFrame(), height = "AUTO", onMeasure = function() end } }
    }):Layout()
  end)

  assert(not ok)
  assert(tostring(err):find("onMeasure", 1, true), tostring(err))
end

print("All assertions passed.")
