# mpv.nvim

A music player inside neovim that uses [mpv](https://github.com/mpv-player/mpv).

Extracted from [stuff.nvim](https://github.com/tamton-aquib/stuff.nvim).

> **Note**
> This is an experimental plugin without any proper testing.

### Showcase
https://user-images.githubusercontent.com/77913442/209674116-7a4bd2e8-e286-4aa6-b66c-57be2a646e4b.mp4

### Requirements:
- neovim (0.7+)
- mpv
- youtube-dl

### Installation and default setup

```lua
-- Using lazy.nvim:
{ "tamton-aquib/mpv.nvim", config=true }
```

### Usage/Configuration
- The command: `:MpvToggle`
- The actual api: `require("mpv").toggle_player()`

- Keymaps:

|key| action |
|:--:|---|
| `<CR>` | Input song/link |
|`p` / `<space\>` | pause/play
| `q` | quit |
| `>` / `<` | next/prev in playlist |
| `m` | mute/unmute |

<details>

<summary>Statusline/Tabline components</summary>

> make sure you set `setup_widgets` to `true` inside `setup()`
```lua
local mpv = require("mpv")

require("lualine").setup {
    sections = {
        lualine_c = {
            {
                function() return ' ' end,
                color='green',
                on_click=mpv.toggle_player
            },
            'g:mpv_title'
        },
    }
}
```

</details>

### Features
- search by keyword.
- paste links from youtube (playlists too).
- mouse support (quite buggy)
- statusline/tabline components.

### Todo's
moved to [todo.norg](https://github.com/tamton-aquib/mpv.nvim/tree/main/todo.norg)

### Inspiration/Credits
- [music.nvim](https://github.com/Saverio976/music.nvim)
- [vhyrro](https://github.com/vhyrro) and [vsedov](https://github.com/vsedov)
