local layout = {}

function layout.contains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function layout.regions(state, include_board)
    local regions = {
        { kind = "hero", side = 2, x = 24, y = 170, w = 182, h = 126 },
        { kind = "hero", side = 1, x = 24, y = 366, w = 182, h = 126 },
        { kind = "end_turn", x = 1094, y = 438, w = 162, h = 48 },
    }
    for side = 1, 2 do
        local board = state.players[side].board
        local start = 640 - (#board * 146 - 12) / 2
        for i, unit in ipairs(board) do
            table.insert(regions, { kind = "unit", side = side, id = unit.id,
                x = start + (i - 1) * 146, y = side == 2 and 180 or 362, w = 134, h = 136 })
        end
    end
    local hand = state.players[1].hand
    local start = 640 - (#hand * 148 - 10) / 2
    for i = 1, #hand do
        table.insert(regions, { kind = "hand", index = i,
            x = start + (i - 1) * 148, y = 548, w = 138, h = 130 })
    end
    if state.winner and not include_board then
        return { { kind = "restart", x = 530, y = 411, w = 220, h = 46 } }
    end
    return regions
end

-- Animation still needs board positions while the result overlay is visible.
function layout.find(state, side, id)
    for _, r in ipairs(layout.regions(state, true)) do
        if r.side == side and ((id == "hero" and r.kind == "hero") or r.id == id) then return r end
    end
end

return layout
