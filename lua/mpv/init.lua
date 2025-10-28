-- TODO: Code cleanup
--- Basically call the toggle_player function to toggle the player window (runs on mpv + yt-dlp)
--- <CR> will prompt for song name or youtube link to play
--- p: pause/play         q: quit                      m: mute
--- >: next               <: prev (in playlists)

local M = {buf=nil, win=nil, ns=vim.api.nvim_create_namespace("mpv"), content_id=nil, title_id=nil}
local conf = { width=50, height=5, border='single', setup_widgets=false, timer={after=1000, throttle=250} }
local state = {playing=false, jobid=nil, title=nil, paused=false, timing="", percent=0, muted=false, loaded=false}
local win_opts = {relative='editor', style='minimal', border=conf.border, row=1, col=vim.o.columns-conf.width-2, height=conf.height, width=conf.width } -- , title='Mpv', title_pos='center' }
local hls = {title="String", timer="Identifier", progress="Function"}
local queue = {}

local actions = require("mpv.actions")

-- NOTE: for statusline components
M.music_info = function() return state end

local by3 = (" "):rep(math.floor(conf.width/4)-1)
local refresh_screen = function()
    if not state.loaded then return end

    local chars = { "󰽰" }
    local char = chars[math.random(#chars)]

    local dur = math.floor((state.percent/100) * conf.width)
    vim.api.nvim_buf_set_extmark(M.buf, M.ns, 0, 0, {
        virt_text = {{state.title or (#queue >= 0 and queue[1] or 'Not Playing'), hls.title}}, virt_text_pos='overlay',
        id = M.title_id
    })

    local time1, time2 = unpack(vim.split(state.timing, ' / '))
    vim.api.nvim_buf_set_extmark(M.buf, M.ns, 0, 0, {
        virt_lines = {
            {
                {time1, hls.timer}, {(" "):rep(conf.width - 16)}, {time2, hls.timer}
            },
            {
                {("▁"):rep(dur), hls.progress}, {char, hls.progress}, {("▁"):rep(conf.width-dur), "Comment"}
            },
            {{"", ""}},
            {
                {by3.."󰞓 ", hls.progress}, {by3..(not state.paused and "" or ""), hls.progress}, {by3.."󰞔 ", hls.progress}
            }
        },
        id = M.content_id
    })
end

local function play_song(query)
    local command = { "mpv", "--term-playing-msg='${media-title}'", "--no-video", query }
    state.jobid = vim.fn.jobstart(command, {
        pty = true,
        on_stdout = function(_, data)
            if data then
                -- vim.print(vim.api.nvim_list_bufs())
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
    end, { buffer = M.buf })
end


local function ask_input(query)
        if query == "" then vim.notify("Query not provided!") return end
        M.title_id = vim.api.nvim_buf_set_extmark(M.buf, M.ns, 0, 0, { virt_text = {{'Searching for "'..query..'"...', hls.title}}, virt_text_pos='overlay', id=M.title_id })
        if not query:match([[^https://.*youtube.com]]) then query = "ytdl://ytsearch:"..table.concat(vim.split(query, ' '), '+') end

        -- Examples for small music from youtube
        -- https://www.youtube.com/watch?v=0yZcDeVsj_Y
        -- https://www.youtube.com/watch?v=FUKmyRLOlAA
        if not state.playing then
            play_song(query)
        else
            table.insert(queue, query)
        end
end

M.toggle_player = function()
    if state.loaded and vim.api.nvim_win_is_valid(M.win) then
        pcall(vim.api.nvim_buf_delete, M.buf, {force=true})
        pcall(vim.api.nvim_win_close, M.win, true)
        state.loaded = false
        return
    end

    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].filetype = 'mpv'
    M.win = vim.api.nvim_open_win(M.buf, true, win_opts)

    -- Title for mpv window
    M.title_id = vim.api.nvim_buf_set_extmark(M.buf, M.ns, 0, 0, {
        virt_text = {
            {state.title or (#queue >= 0 and queue[1] or 'Not Playing'), hls.title}
        }, virt_text_pos = 'overlay'
    })

    -- Contents inside mpv window
    M.content_id = vim.api.nvim_buf_set_extmark(M.buf, M.ns, 0, 0, {
        virt_lines = {
            -- Time progress / Total time
            { {state.timing, hls.timer} },
            -- Progress line
            { {("▁"):rep(math.floor((state.percent/100) * conf.width)), hls.progress} },
            -- Empty line
            {{"", ""}},
            -- Controls on the window
            { {by3.."󰞓 ", hls.progress}, {by3..(state.paused and "" or ""), hls.progress}, {by3.."󰞔 ", hls.progress} }
        },
    })

    vim.keymap.set({'n', 'i'}, '<CR>', function()
        vim.ui.input({ width = 40 }, ask_input)
    end, { buffer = M.buf })

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
            actions.left_mouse(state, conf, M.win)
            refresh_screen()
        end
    )
    -- TODO: add other keys like left and right
    -- map('<Left>', '\\e[[D')
    -- map('<Right>', "\\e[[C")
    state.loaded = true
end

M.setup = function(opts)
    vim.g.mpv_title = ""
    conf = vim.tbl_deep_extend('force', conf, opts or {})
    vim.api.nvim_create_user_command('MpvToggle', M.toggle_player, {desc="Toggles the music player."})

    if conf.setup_widgets then
        vim.g.mpv_percent = state.percent
        require("mpv.widgets").setup_widgets(state, conf)
    end
end

return M
