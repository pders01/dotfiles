-- Cmd+S, then 2/3 to split, S to swap two panes, or Z to toggle column zoom.
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

-- Find a leaf and its immediate parent without guessing from block order.
local function find_pane(node, block_id, parent)
  if not node then return end
  if node.block_id == block_id then return node, parent end
  if node.split then
    local pane, split = find_pane(node.split.before, block_id, node)
    if pane then return pane, split end
    return find_pane(node.split.after, block_id, node)
  end
end

-- Keep recovery data beside init.lua, not in a Lua closure: config reloads
-- and separate CLI invocations must not strand a running, detached pane.
local function column_state_path(window_id)
  local config = os.getenv("REX_CONFIG")
  local directory = config and (config:match("^(.*)/[^/]+$") or ".")
    or ((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/rex")
  return directory .. "/.column-zoom-" .. window_id:gsub("[^%w_-]", "_") .. ".json"
end

local function read_column_state(path)
  local exists = checked(rex.exec({ "test", "-e", path }))
  if exists.code == 1 then return end
  assert(exists.ok, exists.stderr)
  local file = assert(io.open(path, "r"))
  local contents = file:read("*a")
  file:close()
  return checked(rex.json.decode(contents))
end

local function save_column_state(path, state)
  local contents = checked(rex.json.encode(state))
  local file = assert(io.open(path .. ".tmp", "w"))
  assert(file:write(contents))
  assert(file:close())
  assert(os.rename(path .. ".tmp", path))
end

rex.action{
  name = "toggle_column_zoom",
  title = "Toggle Column Zoom",
  category = "Pane",
  description = "Fill only this column, keeping other columns visible; repeat to restore.",
  run = function(ctx)
    assert(ctx.block_id, "Focus a tiled pane first")
    local view = checked(rex.session.view{})
    local window, layer, parent
    for _, candidate in ipairs(view.windows or {}) do
      for _, candidate_layer in ipairs(candidate.layers or {}) do
        local found, found_parent = find_pane(candidate_layer.layout, ctx.block_id)
        if found then
          window, layer, parent = candidate, candidate_layer, found_parent
        end
      end
    end
    assert(window, "Focused pane was not found in the session layout")
    assert(not window.zoomed_block_id, "Exit whole-tab zoom before changing column height")
    local path = column_state_path(window.window_id)
    local state = read_column_state(path)
    if state then
      assert(state.session_id == view.session_id and state.window_id == window.window_id,
        "Column restore data belongs to another session or window")
      local hidden
      for _, block in ipairs(checked(rex.session.list_blocks{}).blocks or {}) do
        if block.block_id == state.hidden_id then hidden = block end
      end
      if not hidden or hidden.placement ~= "detached" then
        assert(os.remove(path))
        error("Saved pane exited or was already placed; cleared column restore data without moving panes", 0)
      end
      local anchor
      for _, candidate_layer in ipairs(window.layers or {}) do
        if candidate_layer.kind == "tiled" and candidate_layer.layer_id == state.layer_id then
          anchor = find_pane(candidate_layer.layout, state.anchor_id)
        end
      end
      assert(anchor and math.abs(anchor.rect[2]) < 1e-9 and math.abs(anchor.rect[4] - 1) < 1e-9,
        "Expanded pane was moved or split; restore it to this column before retrying")
      local result = checked(rex.session.move_block{
        block_id = state.hidden_id,
        anchor_block_id = state.anchor_id,
        direction = "vertical",
        side = state.side,
        ratio = state.ratio,
      })
      assert(os.remove(path))
      return result
    end
    assert(layer.kind == "tiled" and parent and parent.split.direction == "vertical"
      and parent.split.before.block_id and parent.split.after.block_id
      and math.abs(parent.rect[2]) < 1e-9 and math.abs(parent.rect[4] - 1) < 1e-9,
      "Column height requires exactly two stacked tiled panes in a full-height column")
    local split = parent.split
    local is_top = split.before.block_id == ctx.block_id
    state = {
      session_id = view.session_id,
      window_id = window.window_id,
      layer_id = layer.layer_id,
      anchor_id = ctx.block_id,
      hidden_id = is_top and split.after.block_id or split.before.block_id,
      side = is_top and "after" or "before",
      ratio = split.ratio,
    }
    -- Save first. If detaching fails, the next invocation safely clears stale
    -- state; if restoring fails, keep the file so the operation can be retried.
    save_column_state(path, state)
    return checked(rex.session.detach_block{ block_id = state.hidden_id })
  end,
}

rex.bind("cmd+s>z", "toggle_column_zoom")
rex.bind("cmd+s>2", "split_two_columns")
rex.bind("cmd+s>3", "split_three_columns")
rex.bind("cmd+s>s", "swap_two_panes")
