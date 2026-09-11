local match = require("game.match")
local view = {}
local fonts = {}
local colors = {
    background = { 0.045, 0.060, 0.075 }, panel = { 0.075, 0.097, 0.115 },
    card = { 0.115, 0.145, 0.160 }, ink = { 0.91, 0.91, 0.84 },
    muted = { 0.57, 0.65, 0.66 }, gold = { 0.84, 0.70, 0.40 },
    green = { 0.42, 0.77, 0.62 }, red = { 0.91, 0.48, 0.43 },
    border = { 0.22, 0.29, 0.31 },
}

local function color(name) love.graphics.setColor(colors[name]) end
local function text(value, x, y, size, shade, width, align)
    color(shade or "ink")
    love.graphics.setFont(fonts[size or 16])
    love.graphics.printf(tostring(value), x, y, width or 200, align or "left")
end
local function box(x, y, w, h, fill, edge)
    color(fill or "panel")
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    color(edge or "border")
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
end
local function contains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function view.load()
    for _, size in ipairs({ 12, 14, 16, 18, 22, 28 }) do
        fonts[size] = love.graphics.newFont(size)
    end
end

function view.regions(state)
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
    if state.winner then
        return { { kind = "restart", x = 530, y = 411, w = 220, h = 46 } }
    end
    return regions
end

function view.hit(state, x, y)
    for _, region in ipairs(view.regions(state)) do
        if contains(region, x, y) then return region end
    end
end

local function creature(r, card, health, label, edge, hovered)
    box(r.x, r.y, r.w, r.h, hovered and "panel" or "card", edge)
    text(card.cost, r.x + 10, r.y + 7, 22, "gold", 25)
    text(card.guard and "GUARD" or "CREATURE", r.x + 39, r.y + 13, 12,
        card.guard and "gold" or "muted", r.w - 47, "right")
    text(card.name, r.x + 10, r.y + 42, 16, "ink", r.w - 20, "center")
    text(card.attack .. " ATK", r.x + 10, r.y + r.h - 48, 14, "gold", 60)
    text(health .. " HP", r.x + r.w - 65, r.y + r.h - 48, 14,
        health < card.health and "red" or "green", 55, "right")
    text(label, r.x + 5, r.y + r.h - 24, 12, edge == "green" and "green" or "muted", r.w - 10, "center")
end

function view.draw(state, selected, notice)
    color("background")
    love.graphics.clear(colors.background)
    text("MOONCARD", 24, 18, 28, "ink", 300)
    text("THE GROVE DUEL", 26, 54, 12, "gold", 250)
    text("TURN " .. state.turn .. "  /  " .. (state.active == 1 and "YOUR TURN" or "WARDEN'S TURN"),
        440, 26, 18, state.active == 1 and "green" or "gold", 400, "center")
    text("20 health. One surviving hero.", 944, 30, 14, "muted", 310, "right")

    box(224, 158, 850, 354)
    color("border")
    love.graphics.line(244, 337, 1054, 337)
    text("WARDEN'S FIELD", 242, 162, 12, "muted", 240)
    text("YOUR FIELD", 242, 342, 12, "muted", 240)
    for side = 1, 2 do
        if #state.players[side].board == 0 then
            text("No creatures summoned", 390, side == 2 and 248 or 425, 16, "muted", 500, "center")
        end
    end

    local enemy = state.players[2]
    for i = 1, #enemy.hand do
        local x = 640 - (#enemy.hand * 48 - 8) / 2 + (i - 1) * 48
        box(x, 86, 40, 55, "card")
        text("*", x, 99, 28, "gold", 40, "center")
    end
    text("WARDEN'S HAND  " .. #enemy.hand .. "/7", 890, 105, 12, "muted", 184, "right")

    -- Draw the board even when the end-of-match overlay replaces hit regions.
    local winner = state.winner
    local display_state = { players = state.players }
    local mouse_x, mouse_y = love.mouse.getPosition()
    for _, r in ipairs(view.regions(display_state)) do
        local hovered = not winner and contains(r, mouse_x, mouse_y)
        if r.kind == "hero" then
            local player = state.players[r.side]
            local legal = selected and r.side == 2 and match.validate(state, 1,
                { kind = "attack", attacker = selected, target = "hero" })
            box(r.x, r.y, r.w, r.h, "panel", legal and "red" or "border")
            text(r.side == 1 and "YOU" or "THE WARDEN", r.x + 12, r.y + 12, 14, "gold", r.w - 24)
            text(math.max(0, player.health) .. " / 20 HP", r.x + 12, r.y + 37, 22, "ink", r.w - 24)
            text(player.mana .. " / " .. player.max_mana .. " mana", r.x + 12, r.y + 72, 16, "green", r.w - 24)
            text(#player.deck .. " in deck  /  " .. player.fatigue .. " fatigue", r.x + 12, r.y + 101, 12, "muted", r.w - 24)
        elseif r.kind == "unit" then
            local unit = match.unit(state.players[r.side], r.id)
            local edge, label = "border", "Resting"
            if r.side == state.active and unit.ready and not winner then
                edge, label = r.side == 1 and "green" or "border", "Ready"
            end
            if r.id == selected then edge, label = "gold", "Choose a target" end
            if r.side == 2 and selected and match.validate(state, 1,
                { kind = "attack", attacker = selected, target = unit.id }) then
                edge, label = "red", "Attack target"
            end
            creature(r, match.cards[unit.card], unit.health, label, edge, hovered)
        elseif r.kind == "hand" then
            local card = match.cards[state.players[1].hand[r.index]]
            local valid = match.validate(state, 1, { kind = "play", hand = r.index })
            creature(r, card, card.health, valid and "Click to summon" or "In hand",
                valid and "green" or "border", hovered)
        elseif r.kind == "end_turn" then
            box(r.x, r.y, r.w, r.h, hovered and "card" or "panel", state.active == 1 and "gold" or "border")
            text(state.active == 1 and "End turn" or "Warden thinking", r.x, r.y + 14,
                16, state.active == 1 and "gold" or "muted", r.w, "center")
        end
    end
    text("Summon. Defend.\nOutlast the Warden.", 26, 97, 14, "muted", 180)
    text("Right-click: cancel\nEscape: quit", 26, 307, 12, "muted", 180)
    text("RECENT ACTIONS", 1094, 168, 12, "gold", 162)
    for i, message in ipairs(state.log) do
        text(message, 1094, 194 + (i - 1) * 45, 12, i == 1 and "ink" or "muted", 162)
    end
    text(notice or (selected and "Choose a highlighted enemy. Right-click to cancel."
        or (state.active == 1 and "Summon a creature or select a ready attacker." or "The Warden is taking its turn...")),
        240, 521, 14, notice and "gold" or "muted", 820, "center")
    text("YOUR HAND  " .. #state.players[1].hand .. "/7", 24, 690, 12, "muted", 200)
    text("Green: available   /   Gold: selected   /   Red: legal target", 380, 690, 12, "muted", 850, "right")
    if winner then
        love.graphics.setColor(0.015, 0.025, 0.035, 0.88)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
        box(410, 246, 460, 235, "panel", "gold")
        text(winner == 1 and "Victory" or "Defeat", 430, 274, 28, "gold", 420, "center")
        text(winner == 1 and "The grove is yours." or "The Warden holds the grove.", 430, 324, 18, "ink", 420, "center")
        text("A fresh deck. Another duel.", 430, 365, 14, "muted", 420, "center")
        box(530, 411, 220, 46, "card", "gold")
        text("Play again", 530, 424, 16, "gold", 220, "center")
    end
end

return view
