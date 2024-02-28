local M = {}

M.left_mouse = function(state, conf)
    local mouse = vim.fn.getmousepos()
    if M.win ~= mouse.winid then return end

    local pause = math.floor(conf.width/2)
    local prev = math.floor(conf.width/4)
    local next = math.floor(3 * (conf.width/4))
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
