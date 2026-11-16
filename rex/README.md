# Rex

Custom split, swap, and column-zoom shortcuts for Rex. Only the active `init.lua`
is tracked alongside this documentation. Local tests, debugging scripts, runtime
state, backups, and logs are not part of the tracked configuration.

## Install

From the root of this repository, copy the configuration into place (back up any
existing `init.lua` first):

```sh
mkdir -p ~/.config/rex
cp rex/init.lua ~/.config/rex/init.lua
rex config check
rex config reload
```

If using `XDG_CONFIG_HOME` or `REX_CONFIG`, use that configuration path instead.
Keep Rex's **Autobalance** setting **off** so it preserves the split ratios.

## Shortcuts

Press **Cmd+S**, release it, then press the second key:

| Second key | Action |
| --- | --- |
| `2` | Add a shell on the left at 1/3 width; keep the existing pane on the right at 2/3. |
| `3` | Keep the existing pane on the left and add two shells on the right, in three equal columns. |
| `S` | Exchange the two tiled panes without changing the split ratio. Focus follows the same block. |
| `Z` | Toggle column zoom for one of two stacked panes, leaving other columns visible. Repeat to restore. |

Splits divide the focused pane's space, not necessarily the entire tab. New
shells inherit the focused terminal's foreground working directory, falling
back to its child process's working directory when available.

Swapping requires exactly two panes in the focused pane's tiled layer; other
layouts are rejected rather than choosing an arbitrary pair. The 1/3 and 2/3
slots stay in place while their contents trade places. Repeat to swap back.

## Column zoom

Focus either of the two stacked right-hand panes and press **Cmd+S, then Z**:

```text
Before                 Expanded
+------+----------+    +------+----------+
|      | top      |    |      |          |
| left +----------+ -> | left | focused  |
|      | bottom   |    |      |          |
+------+----------+    +------+----------+
```

The other stacked pane is temporarily detached, **not closed**: its process
keeps running. Repeat from any pane in the same tab to restore the original
top/bottom order and height ratio. Other columns and their widths stay unchanged.
Focus stays where it is. This supports exactly two sibling tiled panes whose
combined area spans the tab's full height; other layouts are rejected.

Rex has no native column-only zoom API. The action saves recovery information
in `.column-zoom-<window-id>.json` beside the installed `init.lua` before detaching
anything, so config reloads and separate CLI calls do not lose the restore data.
The file is deleted after restoration. Each tab has independent state. Avoid
closing, moving, or further splitting the expanded pane until you restore the
column. A changed layout is checked before restoration; already-placed panes
are never pulled out of another layout. Whole-tab zoom must be exited first.

If the expanded pane is closed or moved out of the tab, the detached pane can be
recovered manually with `rex move -s SESSION HIDDEN below ANCHOR`, where `HIDDEN`
is the saved `hidden_id` and `ANCHOR` is an existing pane. The JSON file contains
the session ID, pane IDs, side, and original ratio; remove the obsolete state
file after manual recovery. `rex block ls -s SESSION --json` also lists detached
panes. Closing a tab while expanded does **not** close its detached pane.

Rex's built-in **Cmd+Shift+Enter** remains the separate whole-tab zoom shortcut.

The actions use Rex's server API directly; they don't need a CLI helper or the
app's Remote Control setting. Column-zoom state checks use the standard `test`
executable through `rex.exec`. Inspect the loaded shortcuts with `rex keymap`.

## Checks

```sh
rex config check rex/init.lua
```
