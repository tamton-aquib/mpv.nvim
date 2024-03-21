local M = {}

M.left_mouse = function(state, conf)
    local mouse = vim.fn.getmousepos()
    if state.win ~= mouse.winid then return end

    local image_width = state.image.rendered_geometry and state.image.rendered_geometry.width or 0
    print("conf width: ", conf.width)
    print("image width: ", image_width)
    print("win width: ", vim.api.nvim_win_get_config(0).width)
    -- local pause = math.floor(conf.width/2)
    -- local prev = math.floor(conf.width/4)
    -- local next = math.floor(3 * (conf.width/4))
    local pause = math.floor((conf.width - image_width)/2) + image_width
    local prev = math.floor((conf.width - image_width)/4) + image_width
    local next = math.floor(3 * ((conf.width - image_width)/4)) + image_width
    print("Pause: ", pause)
    if (mouse.winrow-1) == conf.height and math.abs(pause - mouse.wincol) < 3 then
        state.paused = not state.paused
        vim.api.nvim_chan_send(state.jobid, 'p')
    elseif (mouse.winrow-1) == conf.height and math.abs(prev - mouse.wincol) < 3 then
        vim.api.nvim_chan_send(state.jobid, '<')
    elseif (mouse.winrow-1) == conf.height and math.abs(next - mouse.wincol) < 3 then
        vim.api.nvim_chan_send(state.jobid, '>')
    end
end


return M
