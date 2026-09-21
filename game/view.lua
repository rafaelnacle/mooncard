local match = require("game.match")
local animation = require("game.animation")
local card_art = require("game.card_art")
local inspection = require("game.inspection")
local layout = require("game.layout")
local spells = require("game.spells")
local view = {}
local effect
local hover = {}
local inspected
local inspection_time = 0
local opacity = 1
local fonts = {}
local colors = {
    background = { 0.045, 0.060, 0.075 }, panel = { 0.075, 0.097, 0.115 },
    card = { 0.115, 0.145, 0.160 }, ink = { 0.91, 0.91, 0.84 },
    muted = { 0.57, 0.65, 0.66 }, gold = { 0.84, 0.70, 0.40 },
    green = { 0.42, 0.77, 0.62 }, red = { 0.91, 0.48, 0.43 },
    border = { 0.22, 0.29, 0.31 },
}

local function color(name)
    local c = colors[name]
    love.graphics.setColor(c[1], c[2], c[3], opacity)
end
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

function view.load()
    for _, size in ipairs({ 12, 14, 16, 18, 22, 28 }) do
        fonts[size] = love.graphics.newFont(size)
    end
end

view.regions = layout.regions

function view.reset()
    effect, hover = nil, {}
    inspected, inspection_time = nil, 0
end

function view.animate(before, side, action, events)
    effect = animation.new(before, side, action, events)
    hover = {}
    inspected, inspection_time = nil, 0
end

function view.busy()
    return effect ~= nil
end

function view.update(dt, state)
    effect = animation.update(effect, dt)
    local x, y = love.mouse.getPosition()
    local hit = not effect and not state.winner and view.hit(state, x, y)
    if hit and (hit.kind == "hand" or hit.kind == "unit") then
        if inspected and hit.kind == inspected.kind and hit.index == inspected.index and hit.id == inspected.id then
            inspection_time = inspection_time + dt
        else
            inspected, inspection_time = hit, 0
        end
    else
        inspected, inspection_time = nil, 0
    end
    local regions = view.regions(state)
    for i = 1, #state.players[1].hand do
        local r
        for _, candidate in ipairs(regions) do
            if candidate.kind == "hand" and candidate.index == i then r = candidate; break end
        end
        local amount = hover[i] or 0
        local over = r and x >= r.x and x <= r.x + r.w and y >= r.y - amount * 8 and y <= r.y + r.h
        local target = over and not effect and state.active == 1 and not state.winner and 1 or 0
        hover[i] = amount + (target - amount) * (1 - math.exp(-18 * dt))
    end
end

function view.hit(state, x, y)
    for _, region in ipairs(view.regions(state)) do
        if region.kind == "hand" then
            local lift = (hover[region.index] or 0) * 8
            if x >= region.x and x <= region.x + region.w and y >= region.y - lift
                and y <= region.y + region.h then return region end
        elseif layout.contains(region, x, y) then
            return region
        end
    end
end

local function creature(r, card, health, label, edge, hovered)
    local style = card_art.style(card)
    local tint = style.color
    love.graphics.setColor(tint[1] * 0.15 + 0.04, tint[2] * 0.15 + 0.04, tint[3] * 0.15 + 0.04, opacity)
    card_art.frame("fill", r, card.guard)
    love.graphics.setColor(tint[1], tint[2], tint[3], opacity * 0.65)
    love.graphics.setLineWidth(card.guard and 2 or 1)
    card_art.frame("line", r, card.guard)
    -- Inner colored frame identifies the creature; the outer ring shows available actions.
    if edge ~= "border" or hovered then
        color(edge ~= "border" and edge or "ink")
        love.graphics.setLineWidth(2)
        card_art.frame("line", { x = r.x - 3, y = r.y - 3, w = r.w + 6, h = r.h + 6 }, card.guard)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(tint[1], tint[2], tint[3], opacity * 0.13)
    love.graphics.circle("fill", r.x + r.w / 2, r.y + 44, 21)
    card_art.icon(style.symbol, r.x + r.w / 2, r.y + 44, 34, tint, opacity)

    love.graphics.setColor(0.16, 0.26, 0.42, opacity)
    love.graphics.polygon("fill", r.x + 18, r.y + 3, r.x + 32, r.y + 17,
        r.x + 18, r.y + 31, r.x + 4, r.y + 17)
    love.graphics.setColor(0.57, 0.76, 0.98, opacity)
    love.graphics.polygon("line", r.x + 18, r.y + 3, r.x + 32, r.y + 17,
        r.x + 18, r.y + 31, r.x + 4, r.y + 17)
    text(card.cost, r.x + 4, r.y + 7, 18, "ink", 28, "center")
    if card.guard then
        card_art.icon("shield", r.x + r.w - 57, r.y + 14, 17, colors.gold, opacity)
    end
    text(style.role, r.x + 39, r.y + 8, 12, card.guard and "gold" or "muted", r.w - 46, "right")
    text(card.name, r.x + 5, r.y + 68, 14, "ink", r.w - 10, "center")

    local stat_y = r.y + r.h - 34
    if card.kind == "spell" then
        text(card.amount .. (card.effect == "heal" and " HEAL" or " DAMAGE"), r.x + 5, stat_y - 9,
            14, card.effect == "heal" and "green" or "gold", r.w - 10, "center")
    else
        card_art.icon("sword", r.x + 17, stat_y, 17, colors.gold, opacity)
        text(card.attack, r.x + 29, stat_y - 10, 18, "gold", 26)
        card_art.icon("heart", r.x + r.w - 40, stat_y, 16,
            health < card.health and colors.red or colors.green, opacity)
        text(health, r.x + r.w - 28, stat_y - 10, 18,
            health < card.health and "red" or "green", 24)
    end
    text(label, r.x + 5, r.y + r.h - (card.guard and 22 or 19), 12, edge == "green" and "green" or "muted", r.w - 10, "center")
end

local function moved(r, x, y)
    return { x = x, y = y, w = r.w, h = r.h }
end

local function visual_region(r)
    if not effect or (effect.kind ~= "attack" and effect.kind ~= "cast") or effect.elapsed < effect.impact or r.kind ~= "unit" then return r end
    local from = layout.find(effect.before, r.side, r.id)
    local progress = animation.progress(effect)
    -- Let defeated cards dissolve before closing gaps in the board.
    local slide = math.max(0, (progress - 0.65) / 0.35)
    local x, y = from.x + (r.x - from.x) * slide, from.y + (r.y - from.y) * slide
    if r.id == effect.attacker then
        local target = layout.find(effect.before, 3 - effect.side, effect.target)
        local dx = target.x + target.w / 2 - from.x - from.w / 2
        local dy = target.y + target.h / 2 - from.y - from.h / 2
        local distance = math.sqrt(dx * dx + dy * dy)
        local travel = math.min(110, distance * 0.6)
        local remaining = (1 - progress) ^ 3
        x = x + (from.x + dx / math.max(1, distance) * travel - x) * remaining
        y = y + (from.y + dy / math.max(1, distance) * travel - y) * remaining
    end
    return moved(r, x, y)
end

local function animated_creature(r, card, health, label, edge, hovered, scale)
    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
    love.graphics.scale(scale or 1)
    creature(moved(r, -r.w / 2, -r.h / 2), card, health, label, edge, hovered)
    love.graphics.pop()
end

local function draw_effects(state)
    if not effect then return end
    local progress = animation.progress(effect)
    if effect.elapsed >= effect.impact then
        for _, death in ipairs(effect.dead) do
            local r = layout.find(effect.before, death.side, death.unit.id)
            local scale = 1 - progress * 0.25
            opacity = math.max(0, 1 - progress / 0.65)
            animated_creature(moved(r, r.x, r.y + progress * 14), match.cards[death.unit.card],
                0, "Defeated", "red", false, scale)
            opacity = 1
        end
        for _, damage in ipairs(effect.damage) do
            local r = layout.find(state, damage.side, damage.id)
            r = r and visual_region(r) or layout.find(effect.before, damage.side, damage.id)
            love.graphics.setColor(0.95, 0.35, 0.28, (1 - progress) * 0.4)
            local unit = damage.id ~= "hero" and match.unit(effect.before.players[damage.side], damage.id)
            card_art.frame("fill", r, unit and match.cards[unit.card].guard)
            love.graphics.setFont(fonts[28])
            love.graphics.setColor(1, 0.65, 0.55, 1 - progress)
            love.graphics.printf("-" .. damage.amount, r.x, r.y - 10 - progress * 24, r.w, "center")
        end
    end
    for _, healing in ipairs(effect.healing) do
        local r = layout.find(state, healing.side, healing.id)
        love.graphics.setColor(0.38, 0.94, 0.67, (1 - progress) * 0.3)
        local unit = match.unit(state.players[healing.side], healing.id)
        card_art.frame("fill", r, match.cards[unit.card].guard)
        love.graphics.setFont(fonts[28])
        love.graphics.setColor(0.5, 1, 0.75, 1 - progress)
        love.graphics.printf("+" .. healing.amount, r.x, r.y - 10 - progress * 24, r.w, "center")
    end
    if effect.kind == "cast" then
        local r = layout.find(effect.before, effect.target_side, effect.target)
        local tint = card_art.style(effect.spell).color
        love.graphics.setColor(tint[1], tint[2], tint[3], 1 - progress)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", r.x + r.w / 2, r.y + r.h / 2, 18 + progress * 60)
        card_art.icon(card_art.style(effect.spell).symbol, r.x + r.w / 2, r.y + r.h / 2,
            32 + progress * 20, tint, 1 - progress)
        love.graphics.setLineWidth(1)
    end
    if effect.kind == "attack" and effect.elapsed < effect.impact then
        local r = layout.find(effect.before, effect.side, effect.attacker)
        local target = layout.find(effect.before, 3 - effect.side, effect.target)
        local amount = math.sin((effect.elapsed / effect.impact) * math.pi / 2)
        local dx, dy = target.x + target.w / 2 - r.x - r.w / 2, target.y + target.h / 2 - r.y - r.h / 2
        local distance = math.sqrt(dx * dx + dy * dy)
        local travel = math.min(110, distance * 0.6) * amount
        local unit = match.unit(effect.before.players[effect.side], effect.attacker)
        animated_creature(moved(r, r.x + dx / math.max(1, distance) * travel,
            r.y + dy / math.max(1, distance) * travel), match.cards[unit.card], unit.health, "Attacking", "gold", false, 1.03)
    elseif effect.kind == "play" then
        local r = layout.find(state, effect.side, effect.summoned)
        local unit = match.unit(state.players[effect.side], effect.summoned)
        local from_x, from_y = 640 - r.w / 2, 86
        if effect.side == 1 then
            for _, hand in ipairs(view.regions(effect.before)) do
                if hand.kind == "hand" and hand.index == effect.hand then from_x, from_y = hand.x, hand.y end
            end
        end
        local eased = 1 - (1 - progress) ^ 3
        animated_creature(moved(r, from_x + (r.x - from_x) * eased, from_y + (r.y - from_y) * eased),
            match.cards[unit.card], unit.health, "Summoning", "gold", false, 0.85 + 0.15 * eased)
    end
end

local function draw_inspection(state)
    if not inspected or inspection_time < 0.35 or effect then return end
    local details = inspection.describe(state, inspected)
    if not details then return end
    local r = inspection.bounds(inspected)
    local card = details.card
    local style = card_art.style(card)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", r.x + 5, r.y + 7, r.w, r.h, 10, 10)
    box(r.x, r.y, r.w, r.h, "panel", "gold")
    text(style.role .. "  /  " .. card.cost .. " MANA", r.x + 16, r.y + 14, 14, "gold", r.w - 32)
    card_art.icon(style.symbol, r.x + r.w / 2, r.y + 72, 58, style.color)
    text(card.name, r.x + 12, r.y + 111, 22, "ink", r.w - 24, "center")
    local stats = card.kind == "spell" and "One use / choose a creature"
        or (card.attack .. " attack   /   " .. details.health .. " / " .. card.health .. " health")
    text(stats, r.x + 12, r.y + 148, 16, "green", r.w - 24, "center")
    text(details.description, r.x + 16, r.y + 184, 16, "ink", r.w - 32)
    text(details.status, r.x + 16, r.y + 296, 12, "muted", r.w - 32)
end

function view.draw(state, selected, notice, selected_spell)
    if effect and effect.kind == "attack" and effect.elapsed < effect.impact then state = effect.before end
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
    local winner = state.winner and not effect and state.winner
    local display_state = { players = state.players }
    local mouse_x, mouse_y = love.mouse.getPosition()
    for _, r in ipairs(view.regions(display_state)) do
        local hovered = not winner and not effect and layout.contains(r, mouse_x, mouse_y)
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
            if selected_spell and match.validate(state, 1,
                { kind = "cast", hand = selected_spell, target = unit.id }) then
                local spell = match.cards[state.players[1].hand[selected_spell]]
                edge, label = spell.effect == "heal" and "green" or "red", "Spell target"
            end
            local hidden = effect and ((effect.kind == "play" and unit.id == effect.summoned)
                or (effect.kind == "attack" and effect.elapsed < effect.impact and unit.id == effect.attacker))
            if not hidden then
                animated_creature(visual_region(r), match.cards[unit.card], unit.health, label, edge, hovered, 1)
            end
        elseif r.kind == "hand" then
            local card = match.cards[state.players[1].hand[r.index]]
            local valid = match.can_play(state, 1, r.index)
            local lift = (hover[r.index] or 0) * 8
            local scale = 1
            if effect and effect.drawn_side == 1 and effect.drawn_hand == r.index then
                local progress = animation.progress(effect)
                lift = lift - (1 - progress) * 18
                scale = 0.92 + 0.08 * progress
            end
            local label = valid and (card.kind == "spell" and "Click to target" or "Click to summon") or "In hand"
            local edge = valid and "green" or "border"
            if r.index == selected_spell then label, edge = "Choose a target", "gold" end
            animated_creature(moved(r, r.x, r.y - lift), card, card.health, label, edge, hovered, scale)
        elseif r.kind == "end_turn" then
            box(r.x, r.y, r.w, r.h, hovered and "card" or "panel", state.active == 1 and "gold" or "border")
            text(state.active == 1 and "End turn" or "Warden thinking", r.x, r.y + 14,
                16, state.active == 1 and "gold" or "muted", r.w, "center")
        end
    end
    card_art.icon("sword", 36, 98, 16, colors.gold)
    text("Attack", 50, 91, 12, "muted", 65)
    card_art.icon("heart", 124, 98, 14, colors.green)
    text("Health", 137, 91, 12, "muted", 64)
    card_art.icon("shield", 36, 126, 18, colors.gold)
    text("Guard: attack first", 50, 119, 12, "muted", 160)
    text("Hover: inspect card\nRight-click: cancel\nEscape: quit", 26, 307, 12, "muted", 180)
    text("RECENT ACTIONS", 1094, 168, 12, "gold", 162)
    for i, message in ipairs(state.log) do
        text(message, 1094, 194 + (i - 1) * 45, 12, i == 1 and "ink" or "muted", 162)
    end
    local spell_hint
    if selected_spell then
        local spell = match.cards[state.players[1].hand[selected_spell]]
        spell_hint = spell.name .. ": " .. spells.prompt(spell) .. " Right-click to cancel."
    end
    text(notice or spell_hint or (selected and "Choose a highlighted enemy. Right-click to cancel."
        or (state.active == 1 and "Summon a creature or select a ready attacker." or "The Warden is taking its turn...")),
        240, 521, 14, notice and "gold" or "muted", 820, "center")
    text("YOUR HAND  " .. #state.players[1].hand .. "/7", 24, 690, 12, "muted", 200)
    text("Green: available   /   Gold: selected   /   Red: legal target", 380, 690, 12, "muted", 850, "right")
    draw_effects(state)
    if not winner and not selected and not selected_spell then draw_inspection(state) end
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
