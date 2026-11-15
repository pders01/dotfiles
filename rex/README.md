# Rex

Custom split and swap shortcuts for Rex. Only the active `init.lua` is tracked;
local debugging scripts, backups, and logs are not part of this configuration.

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

Splits divide the focused pane's space, not necessarily the entire tab. New
shells inherit the focused terminal's foreground working directory, falling
back to its child process's working directory when available.

Swapping requires exactly two panes in the focused pane's tiled layer; other
layouts are rejected rather than choosing an arbitrary pair. The 1/3 and 2/3
slots stay in place while their contents trade places. Repeat to swap back.

The actions use Rex's server API directly; they don't need a CLI helper or the
app's Remote Control setting. Inspect the loaded shortcuts with `rex keymap`.
