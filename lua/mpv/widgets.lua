local Widgets = {}

Widgets.setup_widgets = function(state, conf)
    local sub = 1
    local block_chars = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }
    local blocks = {}
    for _=1, 8 do table.insert(blocks, {n=math.random(8), diff=math.random(2)==1 and 1 or -1}) end

    local timer = vim.loop.new_timer()
    timer:start(conf.timer.after, conf.timer.throttle, vim.schedule_wrap(function()
        if state.playing then
            if state.title then
                local t = state.title
                if t:len() <= 15 then return end
                if sub + 15 >= t:len() then sub = 1 end

                t = t:sub(sub, sub+15)
                sub = sub + 1
                vim.g.mpv_title = t
            end

            local cleaned_blocks = {}
            for i=1,8 do
                local b = blocks[i]
                if (b.n == 1 and b.diff == -1) or (b.n == 8 and b.diff == 1) then
                    blocks[i].diff = -(blocks[i].diff)
                end

                blocks[i].n = b.n + b.diff
                table.insert(cleaned_blocks, block_chars[blocks[i].n])
            end

            vim.g.mpv_visualizer = table.concat(cleaned_blocks)
            vim.cmd.redrawstatus()
        end
    end))
end

return Widgets
