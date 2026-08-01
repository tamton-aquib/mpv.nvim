-- TODO: Code cleanup
--- Basically call the toggle_player function to toggle the player window (runs on mpv + yt-dlp)
--- <CR> will prompt for song name or youtube link to play
--- p: pause/play         q: quit                      m: mute
--- >: next               <: prev (in playlists)

local border = { { "▁", "None" }, { "▁", "None" }, { "▁", "None" }, { "▕", "NormalFloat" }, { "▔", "None" }, { "▔", "None" }, { "▔", "None" }, { "▏", "NormalFloat" } }
local M = {win=nil, ns=vim.api.nvim_create_namespace("mpv"), content_id=nil, title_id=nil}
local conf = {width=50, height=5, border= border, setup_widgets=false, timer={after=1000, throttle=250}}
local base_width = conf.width
local state = {thumbnail = nil, buf=nil, playing=false, jobid=nil, title=nil, paused=false, timing="", percent=0, muted=false, loaded=false, image=nil, image_width=0}
local win_opts = {relative='editor', style='minimal', border=conf.border, row=1, col=vim.o.columns-conf.width-2, height=conf.height, width=conf.width } -- , title='Mpv', title_pos='center' }
local hls = {title="String", timer="Identifier", progress="Function"}
local queue = {}

local actions = require("mpv.actions")

-- NOTE: for statusline components
M.music_info = function() return state end

local by3 = function()
    local w = 0
    if state.image then
        w = conf.width - (state.image.rendered_geometry.width or 0)
        return (" "):rep(math.floor(w/4)-1)
    else
        return (" "):rep(math.floor(conf.width/4)-1)
    end
end

local refresh_screen = function()
    if not state.loaded then return end

    local chars = { "󰽰" }
    local char = chars[math.random(#chars)]
    local image_width = 0
    if state.image and state.image.rendered_geometry then
        image_width = state.image.rendered_geometry.width + 1
    end
    local iw = (" "):rep(image_width)

    local dur = math.floor((state.percent/100) * conf.width)
    M.title_id = vim.api.nvim_buf_set_extmark(state.buf, M.ns, 0, 0, {
        virt_text = {
            {
                iw .. (state.title or (#queue >= 0 and queue[1] or 'Not Playing')), hls.title
            }
        },
        virt_text_pos = 'overlay',
        id = M.title_id
    })

    local t1, t2 = state.timing:match("([%d:]+) / ([%d:]+)")
    local time1, time2 = t1 or "", t2 or ""
    local virt_lines = {
        {
            {iw .. time1, hls.timer}, {(" "):rep(conf.width - 16 - image_width)}, {time2, hls.timer}
        },
        {
            {iw .. ("▁"):rep(dur), hls.progress},
            {char, hls.progress},
            {("▁"):rep(conf.width - dur - image_width), "Comment"}
        },
    }
    for _ = 1, conf.height - 4 do
        table.insert(virt_lines, {{"", ""}})
    end
    table.insert(virt_lines, {
        {iw .. by3() .."󰞓 ", hls.progress},
        {by3() ..(not state.paused and "" or ""), hls.progress},
        {by3() .."󰞔 ", hls.progress}
    })
    M.content_id = vim.api.nvim_buf_set_extmark(state.buf, M.ns, 0, 0, {
        virt_lines = virt_lines,
        id = M.content_id
    })
end

local function clear_thumbnail()
    if state.image then
        pcall(state.image.clear, state.image)
        state.image = nil
    end
    if state.image_width > 0 then
        if vim.api.nvim_win_is_valid(state.win) then
            local wo = vim.api.nvim_win_get_config(state.win)
            wo.width = base_width
            wo.col = wo.col + state.image_width
            pcall(vim.api.nvim_win_set_config, state.win, wo)
        end
        conf.width = base_width
        state.image_width = 0
    end
end

local function fetch_thumbnail(url)
    if not url or not vim.api.nvim_win_is_valid(state.win) then return end
    require("image").from_url(url, {
        window = state.win,
        buffer = state.buf,
        max_height_window_percentage = 100,
    }, function(image)
        if not image or not vim.api.nvim_win_is_valid(state.win) then return end

        if state.image and state.image ~= image then
            pcall(state.image.clear, state.image)
        end
        state.image = image
        image:render({
            x = 0, y = 0,
            height = conf.height,
        })

        -- image.nvim resizes/transforms asynchronously; rendered_geometry is only
        -- set once that finishes, so poll until it is ready.
        local function apply(tries)
            tries = tries or 0
            if not vim.api.nvim_win_is_valid(state.win) then return end
            if tries > 100 then return end
            if not image.rendered_geometry or not image.rendered_geometry.width then
                vim.defer_fn(function() apply(tries + 1) end, 50)
                return
            end

            local wo = vim.api.nvim_win_get_config(state.win)
            local image_width = image.rendered_geometry.width + 1
            state.image_width = image_width
            wo.width = wo.width + image_width
            wo.col = math.max(0, wo.col - image_width)
            conf.width = wo.width
            pcall(vim.api.nvim_win_set_config, state.win, wo)
            image:render()
            refresh_screen()
        end
        apply(0)
    end)
end

local function resolve_thumbnail(query)
    if not vim.fn.executable("yt-dlp") then return end
    local search
    if query:match("^ytdl://ytsearch:") then
        search = query:sub(#"ytdl://ytsearch:" + 1):gsub("+", " ")
    else
        search = query
    end
    if search == "" or vim.uv.fs_stat(search) then return end

    local lines = {}
    vim.fn.jobstart({ "yt-dlp", "--default-search", "ytsearch1", "--print", "%(thumbnail)s", search }, {
        on_stdout = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then table.insert(lines, line) end
                end
            end
        end,
        on_exit = function()
            for _, line in ipairs(lines) do
                local url = line:match("https?://%S+")
                if url then
                    fetch_thumbnail(url)
                    return
                end
            end
        end,
    })
end

local function play_song(query)
    local command = { "mpv", "--term-playing-msg='${media-title}'", "--no-video", query }
    if state.thumbnail then
        fetch_thumbnail("https://i.ytimg.com/vi/" .. state.thumbnail .. "/mqdefault.jpg")
    else
        resolve_thumbnail(query)
    end
    state.jobid = vim.fn.jobstart(command, {
        pty = true,
        on_stdout = function(_, data)
            if data then
                local time = data[1]:match([[%d%d:%d%d:%d%d / %d%d:%d%d:%d%d]])
                local percent = data[1]:match([[(%d%d?%%)]])
                if percent then state.percent = percent:sub(1, -2) end

                if not data[1]:match("A:") and not data[1]:match("AO:") then
                    state.title = data[1]:match([['(.*)']]) or state.title
                end

                if time then
                    if state.timing ~= time then
                        state.timing = time
                        refresh_screen()
                    end
                end
            end
        end,

        on_exit = function()
            state.playing = false
            state.title = nil
            clear_thumbnail()
            refresh_screen()

            if #queue > 0 then
                play_song(queue[1])
                table.remove(queue, 1)
            end
        end
    })
    state.playing = true
end

local map = function(bind, to, fn)
    vim.keymap.set('n', bind, function()
        if state.jobid then
            vim.api.nvim_chan_send(state.jobid, to)
            if fn then fn() end
            refresh_screen()
        end
    end, { buffer = state.buf })
end


local function ask_input(query)
    if query == "" then vim.notify("Query not provided!") return end
    M.title_id = vim.api.nvim_buf_set_extmark(
        state.buf,
        M.ns,
        0, 0,
        {
            virt_text = {
                { (" "):rep(state.image_width) .. 'Searching for "'.. query ..'"...', hls.title }
            },
            virt_text_pos = 'overlay',
            id = M.title_id
        }
    )

	if not query:match([[^https://.*youtube.com]]) then
		---@diagnostic disable-next-line: undefined-field
		if not vim.uv.fs_stat(query) then
			query = "ytdl://ytsearch:"..table.concat(vim.split(query, ' '), '+')
		end
    end

    state.thumbnail = query:match("v=([a-zA-Z0-9_]*)")

    -- Examples for small music from youtube
    -- https://www.youtube.com/watch?v=0yZcDeVsj_Y
    -- https://www.youtube.com/watch?v=FUKmyRLOlAA
    if not state.playing then
        play_song(query)
    else
        vim.notify("Song added to queue!")
        table.insert(queue, query)
    end
end

M.toggle_player = function()
    if state.loaded and vim.api.nvim_win_is_valid(state.win) then
        clear_thumbnail()
        pcall(vim.api.nvim_buf_delete, state.buf, {force=true})
        pcall(vim.api.nvim_win_close, state.win, true)
        state.loaded = false
        return
    end

    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].filetype = 'mpv'
    state.win = vim.api.nvim_open_win(state.buf, true, win_opts)
    state.loaded = true
    refresh_screen()

    vim.keymap.set({'n', 'i'}, '<CR>', function()
        vim.ui.input({ width = 40 }, ask_input)
    end, { buffer = state.buf })

    map('q', 'q', function()
        state.title = 'Not Playing'
        state.percent = 0
        refresh_screen()
    end)
    map('p', 'p', function() state.paused = not state.paused end)
    map('<space>', 'p', function() state.paused = not state.paused end)
    map('m', 'm', function() state.muted = not state.muted end)
    map('>', '>')
    map('<', '<')
    map('<LeftMouse>', '',
        function()
            actions.left_mouse(state, conf)
            refresh_screen()
        end
    )
    -- TODO: add other keys like left and right
    -- map('<Left>', '\\e[[D')
    -- map('<Right>', "\\e[[C")
end

M.setup = function(opts)
    vim.g.mpv_title = ""
    conf = vim.tbl_deep_extend('force', conf, opts or {})
    base_width = conf.width
    vim.api.nvim_create_user_command('MpvToggle', M.toggle_player, {desc="Toggles the music player."})

    if conf.setup_widgets then
        vim.g.mpv_percent = state.percent
        require("mpv.widgets").setup_widgets(state, conf)
    end
end

return M
