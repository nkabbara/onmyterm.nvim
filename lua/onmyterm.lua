local M = {}

local state = {
    tabs = {},
    buf_tabs = {},
    closing_tab = nil,
}

local DEFAULT_WINBLEND = 0
local FADED_WINBLEND = 90
local WIN_WIDTH_RATIO = 0.8
local WIN_HEIGHT_RATIO = 0.8
local DEFAULT_ZINDEX = 1000

local config = {
    zindex = DEFAULT_ZINDEX,
}

-- Forward declarations. Is this idiomatic lua?
local idx_of
local is_term
local is_running_term
local current_tab
local get_tab_state
local get_existing_tab_state
local current_floating
local get_tab_cwd
local shift_term
local set_win_style
local create_floating_window
local delete_buffer
local delete_tab_buffers
local set_keymaps
local calc_dims
local setup_term_events
local setup_events

-- Public API
M.setup = function(opts)
    opts = opts or {}
    config = vim.tbl_extend("force", config, opts)
end

M.new_term = function()
    local tab = current_tab()
    local floating = get_tab_state(tab).floating

    if not vim.api.nvim_win_is_valid(floating.win) then
        M.open_term()
        floating = get_tab_state(tab).floating
    end

    local win = floating.win
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    if not is_term(buf) then
        local shell = os.getenv("SHELL") or vim.o.shell
        local cwd = get_tab_cwd()
        if cwd and cwd ~= "" then
            vim.cmd("lcd " .. vim.fn.fnameescape(cwd))
        end
        vim.cmd.terminal(shell)
        vim.cmd("startinsert")
        setup_term_events(buf, tab)
    end
    state.buf_tabs[buf] = tab
    floating.current_buf = buf
    table.insert(floating.bufs, buf)

    set_keymaps(buf)
end

M.toggle_term = function()
    local floating = current_floating()

    if not vim.api.nvim_win_is_valid(floating.win) then
        M.open_term()
        floating = current_floating()
        if not is_term(floating.current_buf) then
            M.new_term()
        end
    else
        vim.api.nvim_win_hide(floating.win)
        floating.win = -1
    end
end

M.open_term = function()
    local floating_state = current_floating()

    if vim.api.nvim_win_is_valid(floating_state.win) then
        return
    end

    local floating = create_floating_window({ buf = floating_state.current_buf })

    floating_state.current_buf = floating.current_buf
    floating_state.win = floating.win

    if is_term(floating_state.current_buf) then
        vim.cmd("startinsert")
    end
end

M.toggle_transparency = function()
    local winid = current_floating().win
    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    if vim.wo[winid].winblend ~= DEFAULT_WINBLEND then
        vim.wo[winid].winblend = DEFAULT_WINBLEND
    else
        vim.wo[winid].winblend = FADED_WINBLEND
    end
end

-- Implementation
idx_of = function(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end
    return nil
end

is_term = function(buf)
    return buf and buf ~= -1 and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal"
end

is_running_term = function(buf)
    if not is_term(buf) then
        return false
    end

    local ok, job_id = pcall(function()
        return vim.b[buf].terminal_job_id
    end)
    if not ok or not job_id then
        return false
    end

    local wait_ok, result = pcall(vim.fn.jobwait, { job_id }, 0)
    return wait_ok and result[1] == -1
end

current_tab = function()
    return vim.api.nvim_get_current_tabpage()
end

get_tab_state = function(tab)
    if not state.tabs[tab] then
        state.tabs[tab] = {
            floating = {
                current_buf = -1,
                win = -1,
                bufs = {},
            },
        }
    end

    return state.tabs[tab]
end

get_existing_tab_state = function(tab)
    return state.tabs[tab]
end

current_floating = function()
    return get_tab_state(current_tab()).floating
end

get_tab_cwd = function()
    local ok, cwd = pcall(vim.fn.getcwd, -1, vim.fn.tabpagenr())
    if ok and cwd ~= "" then
        return cwd
    end

    return vim.fn.getcwd()
end

shift_term = function(shift_by)
    local floating = current_floating()
    local idx = idx_of(floating.bufs, floating.current_buf)
    if not idx then
        return
    end

    local current_buf = floating.bufs[idx + shift_by]
    if not current_buf then
        return
    end

    if not vim.api.nvim_win_is_valid(floating.win) then
        return
    end

    vim.api.nvim_win_set_buf(floating.win, current_buf)
    floating.current_buf = current_buf
end

set_win_style = function(ctx)
    local tab_state = get_existing_tab_state(state.buf_tabs[ctx.buf] or current_tab())
    if not tab_state then
        return
    end

    local winid = tab_state.floating.win
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

calc_dims = function()
    local ui = vim.api.nvim_list_uis()[1] or { width = vim.o.columns, height = vim.o.lines }
    local width = math.floor(ui.width * WIN_WIDTH_RATIO)
    local height = math.floor(ui.height * WIN_HEIGHT_RATIO)

    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
    }
    return win_opts
end

create_floating_window = function(opts)
    opts = opts or {}

    local buf = nil
    if opts.buf and opts.buf ~= -1 and vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win_opts = {
        style = "minimal",
        border = "rounded",
        zindex = config.zindex,
    }
    win_opts = vim.tbl_extend("force", win_opts, calc_dims())

    local win = vim.api.nvim_open_win(buf, true, win_opts)

    -- reset toggle_transparency()
    vim.wo[win].winblend = 0

    return { current_buf = buf, win = win }
end

delete_buffer = function(buf, confirm, tab)
    tab = tab or state.buf_tabs[buf] or current_tab()
    local tab_state = get_existing_tab_state(tab)
    if not tab_state then
        state.buf_tabs[buf] = nil
        return
    end

    local floating = tab_state.floating
    local buf_idx = idx_of(floating.bufs, buf)
    if not buf_idx then -- buf_delete below calls this function recursively. This ensures we have a way out.
        return
    end

    if confirm then
        local choice = vim.fn.confirm("Are you sure?", "&Yes\n&No", 2)
        if choice ~= 1 then
            return
        end
    end

    local deleting_current = floating.current_buf == buf
    local new_idx
    if #floating.bufs == 1 then
        if deleting_current then
            floating.current_buf = -1
        end
    elseif deleting_current then
        if floating.bufs[buf_idx - 1] ~= nil then
            new_idx = buf_idx - 1
        else
            new_idx = buf_idx + 1
        end
        floating.current_buf = floating.bufs[new_idx]

        if vim.api.nvim_win_is_valid(floating.win) then
            vim.api.nvim_win_set_buf(floating.win, floating.current_buf)

            if vim.api.nvim_get_current_win() == floating.win then
                -- We delay startinsert to ensure the buffer switch has fully completed
                -- and the UI is ready to accept input mode.
                vim.defer_fn(function()
                    vim.cmd("startinsert")
                end, 10)
            end
        end
    end

    table.remove(floating.bufs, buf_idx) -- ensure this is called before buf_delete so we don't loop in recursion.
    state.buf_tabs[buf] = nil
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

delete_tab_buffers = function(tab)
    local tab_state = get_existing_tab_state(tab)
    if not tab_state then
        return
    end

    local bufs = vim.deepcopy(tab_state.floating.bufs)
    state.tabs[tab] = nil

    for _, buf in ipairs(bufs) do
        state.buf_tabs[buf] = nil
        if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end
end

set_keymaps = function(buf)
    vim.keymap.set("n", "n", function()
        shift_term(1)
    end, { buffer = buf, desc = "next term " })
    vim.keymap.set("n", "p", function()
        shift_term(-1)
    end, { buffer = buf, desc = "prev term " })

    vim.keymap.set("n", "q", function()
        local tab_state = get_existing_tab_state(state.buf_tabs[buf] or current_tab())
        if tab_state and vim.api.nvim_win_is_valid(tab_state.floating.win) then
            vim.api.nvim_win_hide(tab_state.floating.win)
            tab_state.floating.win = -1
        end
    end, { buffer = buf, desc = "hide term" })

    vim.keymap.set("n", "C", function()
        M.new_term()
    end, { buffer = buf, desc = "new term " })

    vim.keymap.set("n", "t", function()
        M.toggle_transparency()
    end, { buffer = buf, desc = "toggle transparency" })

    vim.keymap.set("n", "D", function()
        delete_buffer(buf, true)
    end, { buffer = buf, desc = "delete term" })
end

setup_term_events = function(buf, tab)
    vim.api.nvim_create_autocmd({ "TermLeave", "TermEnter" }, {
        callback = function(ctx)
            set_win_style(ctx)
        end,
        buffer = buf,
    })
    vim.api.nvim_create_autocmd({ "TermClose" }, {
        callback = function(ctx)
            delete_buffer(ctx.buf, false, tab)
        end,
        buffer = buf,
    })
end

setup_events = function()
    local group = vim.api.nvim_create_augroup("OnMyTerm", { clear = true })

    vim.api.nvim_create_autocmd({ "WinResized" }, {
        group = group,
        callback = function()
            for _, tab_state in pairs(state.tabs) do
                local win = tab_state.floating.win
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_set_config(win, calc_dims())
                end
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "TabClosedPre" }, {
        group = group,
        callback = function()
            local tab = current_tab()
            state.closing_tab = tab

            if vim.g.onmyterm_confirm_tab_close == false then
                return
            end

            local running_terms = 0
            local tab_state = get_existing_tab_state(tab)
            if tab_state then
                for _, buf in ipairs(tab_state.floating.bufs) do
                    if is_running_term(buf) then
                        running_terms = running_terms + 1
                    end
                end
            end

            if running_terms == 0 then
                return
            end

            local label = running_terms == 1 and "terminal" or "terminals"
            local choice = vim.fn.confirm(
                string.format("OnMyTerm: close this tab and kill %d running %s?", running_terms, label),
                "&Yes\n&No",
                2
            )

            if choice ~= 1 then
                state.closing_tab = nil
                error("OnMyTerm tab close cancelled", 0)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "TabClosed" }, {
        group = group,
        callback = function()
            local tab = state.closing_tab
            state.closing_tab = nil
            delete_tab_buffers(tab)
        end,
    })
end

setup_events()

return M
