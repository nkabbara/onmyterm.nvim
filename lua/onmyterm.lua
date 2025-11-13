--[[
TODO: 
- [BUG] Remove the buffer from the list when we exit terminal.
- [FEATURE] Make usable with lazy
- [FEATURE] Load proper shell env
- [FEATURE] D for delete with confirmation
- [FEATURE] N for new
- [FEATURE] Add resize support
]]

local state = {
    floating = {
        current_buf = -1,
        win = -1,
        bufs = {},
        wins = {},
    },
}

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

-- Function to create a centered floating window
local function create_floating_window(opts)
    opts = opts or {}

    -- Get editor dimensions
    local ui = vim.api.nvim_list_uis()[1]
    local width = opts.width or math.floor(ui.width * 0.8)
    local height = opts.height or math.floor(ui.height * 0.8)

    -- Calculate center position
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    -- Create buffer
    -- local buf = vim.api.nvim_create_buf(false, true) -- not listed, scratch buffer
    local buf = nil
    if vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        buf = vim.api.nvim_create_buf(false, true) -- not listed, scratch buffer
    end

    -- Window configuration
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded", -- 'single', 'double', 'rounded', 'solid', 'shadow'
    }

    -- Open the window
    local win = vim.api.nvim_open_win(buf, true, win_opts)

    -- Optional: Add keybinding to close with 'q' or ESC
    vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })

    return { current_buf = buf, win = win }
end

local is_term = function(buf)
    return vim.bo[buf].buftype == "terminal"
end

local new_term = function()
    local win = state.floating.win
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    if not is_term(buf) then
        vim.cmd.terminal()
        vim.cmd("startinsert")
    end
    state.floating.current_buf = buf
    table.insert(state.floating.bufs, buf)

    vim.keymap.set("n", "n", function()
        shift_term(1)
    end, { buffer = vim.api.nvim_get_current_buf(), desc = "next term " })
    vim.keymap.set("n", "p", function()
        shift_term(-1)
    end, { buffer = vim.api.nvim_get_current_buf(), desc = "prev term " })

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_hide(state.floating.win)
    end, { buffer = vim.api.nvim_get_current_buf(), desc = "prev term " })
end

local toggle_term = function()
    if not vim.api.nvim_win_is_valid(state.floating.win) then
        local floating = create_floating_window({ buf = state.floating.current_buf })

        state.floating.current_buf = floating.current_buf
        state.floating.win = floating.win
        if not is_term(floating.current_buf) then
            new_term()
        end
    else
        vim.api.nvim_win_hide(state.floating.win)
    end
end

vim.api.nvim_create_user_command("FloatingTerm", toggle_term, {})
vim.keymap.set("n", "<leader>tt", toggle_term, { desc = "Toggle terminal" })
vim.keymap.set("n", "<leader>tn", function()
    toggle_term()
    new_term()
end, { desc = "New terminal" })
