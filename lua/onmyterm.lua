local M = {}

local state = {
    floating = {
        current_buf = -1,
        win = -1,
        bufs = {},
        wins = {},
    },
}

local DEFAULT_WINBLEND = 0
local FADED_WINBLEND = 60

local idx_of = function(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end
    return nil
end

local shift_term = function(shift_by)
    local idx = idx_of(state.floating.bufs, state.floating.current_buf)
    if not idx then
        return
    end

    local current_buf = state.floating.bufs[idx + shift_by]
    if not current_buf then
        return
    end

    vim.api.nvim_win_set_buf(state.floating.win, current_buf)
    state.floating.current_buf = current_buf
end

local function create_floating_window(opts)
    opts = opts or {}

    local ui = vim.api.nvim_list_uis()[1]
    local width = opts.width or math.floor(ui.width * 0.8)
    local height = opts.height or math.floor(ui.height * 0.8)

    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    local buf = nil
    if opts.buf ~= -1 or vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, win_opts)
    -- reset toggle_transparency()
    vim.wo[win].winblend = 0

    return { current_buf = buf, win = win }
end

local is_term = function(buf)
    return vim.bo[buf].buftype == "terminal"
end

M.new_term = function()
    local win = state.floating.win
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    if not is_term(buf) then
        local shell = os.getenv("SHELL")
        vim.cmd.terminal(shell)
        vim.cmd("startinsert")
        vim.api.nvim_create_autocmd({ "TermLeave", "TermEnter" }, {
            callback = function(ctx)
                M.set_win_style(ctx)
            end,
            buffer = buf,
        })
        vim.api.nvim_create_autocmd({ "TermClose" }, {
            callback = function(ctx)
                M.delete_buffer(ctx.buf)
            end,
            buffer = buf,
        })
    end
    state.floating.current_buf = buf
    table.insert(state.floating.bufs, buf)

    M.set_keymaps(buf)
end

M.set_keymaps = function(buf)
    vim.keymap.set("n", "n", function()
        shift_term(1)
    end, { buffer = buf, desc = "next term " })
    vim.keymap.set("n", "p", function()
        shift_term(-1)
    end, { buffer = buf, desc = "prev term " })

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_hide(state.floating.win)
    end, { buffer = buf, desc = "hide term" })

    vim.keymap.set("n", "C", function()
        M.new_term()
    end, { buffer = buf, desc = "new term " })

    vim.keymap.set("n", "t", function()
        M.toggle_transparency()
    end, { buffer = buf, desc = "new term " })

    vim.keymap.set("n", "D", function()
        M.delete_buffer(buf, true)
    end, { buffer = buf, desc = "new term " })
end

M.delete_buffer = function(buf, confirm)
    local buf_idx = idx_of(state.floating.bufs, buf)
    if not buf_idx then -- buf_delete below calls this function recursively. This ensures we have a way out.
        return
    end

    if confirm then
        local choice = vim.fn.confirm("Are you sure?", "&Yes\n&No", 2)
        if choice == 2 then
            return
        end
    end

    local new_idx
    if #state.floating.bufs == 1 then
        state.floating.current_buf = -1
    else
        if state.floating.bufs[buf_idx - 1] ~= nil then
            new_idx = buf_idx - 1
        else
            new_idx = buf_idx + 1
        end
        state.floating.current_buf = state.floating.bufs[new_idx]
        vim.api.nvim_set_current_buf(state.floating.current_buf)
    end

    table.remove(state.floating.bufs, buf_idx) -- ensure this is called before buf_delete so we don't loop in recrsion.
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

M.toggle_term = function()
    if not vim.api.nvim_win_is_valid(state.floating.win) then
        local floating = create_floating_window({ buf = state.floating.current_buf })

        state.floating.current_buf = floating.current_buf
        state.floating.win = floating.win
        if not is_term(floating.current_buf) then
            M.new_term()
        else
            vim.cmd("startinsert")
        end
    else
        vim.api.nvim_win_hide(state.floating.win)
    end
end

M.set_win_style = function(ctx)
    local winid = state.floating.win
    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    local cfg = vim.api.nvim_win_get_config(winid)

    if ctx.event == "TermLeave" then
        cfg.border = "double"
    else
        cfg.border = "single"
    end

    vim.api.nvim_win_set_config(winid, cfg)
end

M.toggle_transparency = function()
    local winid = state.floating.win
    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    if vim.wo[winid].winblend ~= DEFAULT_WINBLEND then
        vim.wo[winid].winblend = DEFAULT_WINBLEND
    else
        vim.wo[winid].winblend = FADED_WINBLEND
    end
end

return M
