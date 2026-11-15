-- Cmd+S, then 2/3 to split or S to swap two panes.
-- Keep Rex's Autobalance setting OFF so the app preserves these ratios.
-- Direct server API calls: no CLI helper or Remote Control required.
local terminal = "com.superlogical.terminal"

local function checked(result, err)
  if err ~= nil then error(err, 0) end
  return result
end

local function shell(ctx)
  assert(ctx.block_id, "Focus a terminal pane before splitting")
  local process = checked(rex.block.call(terminal, "process", {
    block_id = ctx.block_id,
  }))
  local cwd = (process.foreground and process.foreground.cwd)
    or (process.child and process.child.cwd)
  return rex.layout.block{
    flavor = terminal .. ".shell",
    options = { cwd = cwd },
  }
end

rex.action{
  name = "split_two_columns",
  title = "Split into Two Columns (1/3 + 2/3)",
  category = "Pane",
  description = "Add a shell on the left, keeping the existing pane on the right.",
  run = function(ctx)
    return checked(rex.session.new_split{
      anchor_id = ctx.block_id,
      direction = "horizontal",
      side = "before",
      ratio = 1 / 3,
      layout = shell(ctx),
      focus = true,
    })
  end,
}

rex.action{
  name = "split_three_columns",
  title = "Split into Three Equal Columns",
  category = "Pane",
  description = "Keep the existing pane on the left and add two shells on the right.",
  run = function(ctx)
    local left = shell(ctx)
    local right = shell(ctx)
    local result = checked(rex.session.new_split{
      anchor_id = ctx.block_id,
      direction = "horizontal",
      side = "after",
      ratio = 1 / 3,
      layout = rex.layout.horizontal(0.5, left, right),
      focus = true,
    })
    checked(rex.session.focus_block{ block_id = result.block_ids[2] })
    return result
  end,
}

rex.action{
  name = "swap_two_panes",
  title = "Swap Two Panes (Keep Split Sizes)",
  category = "Pane",
  description = "Exchange two panes, keeping the split ratio and following focus.",
  run = function(ctx)
    assert(ctx.block_id, "Focus a pane before swapping")
    local view = checked(rex.session.view{})
    for _, window in ipairs(view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        local blocks = layer.blocks or {}
        for _, block in ipairs(blocks) do
          if block.block_id == ctx.block_id then
            assert(layer.kind == "tiled" and #blocks == 2,
              "Swap requires exactly two tiled panes in the focused window")
            -- Swap only the occupants: the layout's slots and ratio stay intact.
            return checked(rex.session.swap_blocks{
              block_id = blocks[1].block_id,
              other_block_id = blocks[2].block_id,
            })
          end
        end
      end
    end
    error("Focused pane was not found in the session layout", 0)
  end,
}

rex.bind("cmd+s>2", "split_two_columns")
rex.bind("cmd+s>3", "split_three_columns")
rex.bind("cmd+s>s", "swap_two_panes")
