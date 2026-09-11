-- Original geometric emblems. Drawing stays independent of combat rules.
local art = {}
local styles = {
    ["Moon Wisp"] = { symbol = "moon", role = "SPIRIT", color = { 0.63, 0.68, 0.98 } },
    ["Goblin Raider"] = { symbol = "blades", role = "RAIDER", color = { 0.93, 0.59, 0.35 } },
    ["Grove Sentinel"] = { symbol = "leaf", role = "GUARD", color = { 0.40, 0.79, 0.58 } },
    ["Stone Ogre"] = { symbol = "mountain", role = "BRUTE", color = { 0.72, 0.70, 0.62 } },
    ["Dusk Wolf"] = { symbol = "wolf", role = "BEAST", color = { 0.55, 0.77, 0.89 } },
    ["Iron Warder"] = { symbol = "tower", role = "GUARD", color = { 0.85, 0.73, 0.43 } },
    ["Ember Drake"] = { symbol = "drake", role = "DRAGON", color = { 0.98, 0.43, 0.34 } },
    ["Elder Treant"] = { symbol = "tree", role = "GUARD", color = { 0.67, 0.81, 0.37 } },
}

function art.style(card)
    return assert(styles[card.name], "Missing card art: " .. card.name)
end

-- Icons use a normalized 32-unit canvas, so HUD badges and emblems share strokes.
function art.icon(symbol, x, y, size, tint, alpha)
    local g = love.graphics
    g.push("all")
    g.translate(x, y)
    g.scale(size / 32)
    g.setColor(tint[1], tint[2], tint[3], alpha or 1)
    g.setLineWidth(2)
    g.setLineJoin("bevel")
    if symbol == "shield" then
        g.polygon("line", -11, -13, 11, -13, 10, 3, 0, 14, -10, 3)
        g.line(0, -8, 0, 7)
        g.line(-6, -2, 6, -2)
    elseif symbol == "sword" or symbol == "blades" then
        if symbol == "blades" then
            g.line(-11, -12, 10, 12)
            g.line(5, 5, 12, 0)
        end
        g.polygon("fill", 8, -13, 12, -14, 12, -9, -4, 7, -7, 4)
        g.line(-10, 2, 0, 12)
        g.line(-5, 7, -11, 13)
    elseif symbol == "heart" then
        g.circle("fill", -6, -4, 7)
        g.circle("fill", 6, -4, 7)
        g.polygon("fill", -13, -3, 13, -3, 0, 14)
    elseif symbol == "moon" then
        g.arc("line", "open", 0, 0, 12, math.pi * 0.3, math.pi * 1.7)
        g.arc("line", "open", 7, 0, 12, math.pi * 0.53, math.pi * 1.47)
        g.line(10, -6, 10, 2)
        g.line(6, -2, 14, -2)
    elseif symbol == "leaf" then
        g.polygon("line", 0, -14, 12, -6, 10, 6, 0, 14, -10, 6, -12, -6)
        g.line(0, -9, 0, 15)
        g.line(-8, -3, 0, 3, 8, -3)
        g.line(-6, 4, 0, 9, 6, 4)
    elseif symbol == "mountain" then
        g.polygon("line", -15, 11, -3, -12, 4, -1, 9, -8, 16, 11)
        g.line(-7, -4, -3, -1, 0, -6)
        g.line(-8, 11, -2, 3, 3, 11)
    elseif symbol == "wolf" then
        g.polygon("line", -12, -13, -2, -6, 2, -6, 12, -13, 11, 4, 0, 14, -11, 4)
        g.line(-8, -1, -3, 1)
        g.line(3, 1, 8, -1)
        g.polygon("fill", -3, 6, 3, 6, 0, 10)
    elseif symbol == "tower" then
        g.polygon("line", -11, -13, -5, -13, -5, -8, 5, -8, 5, -13, 11, -13,
            11, -3, 8, -3, 8, 12, -8, 12, -8, -3, -11, -3)
        g.line(-3, 12, -3, 4, 3, 4, 3, 12)
    elseif symbol == "drake" then
        g.polygon("line", -1, 12, -13, 2, -15, -11, -5, -5, 0, -14,
            5, -5, 15, -11, 13, 2, 1, 12)
        g.line(0, -6, 4, 2, 0, 10, -4, 2, 0, -6)
    elseif symbol == "tree" then
        g.line(0, -13, 0, 9, -7, 14)
        g.line(0, 9, 8, 14)
        g.line(0, 1, -10, -5, -12, -12)
        g.line(0, -3, 9, -8, 10, -14)
        g.line(-10, -5, -15, -4)
        g.line(0, 5, 11, 0, 14, -5)
        g.line(11, 0, 15, 3)
    end
    g.pop()
end

function art.frame(mode, r, guard)
    if guard then
        love.graphics.polygon(mode, r.x + 7, r.y, r.x + r.w - 7, r.y,
            r.x + r.w, r.y + 7, r.x + r.w, r.y + r.h - 8,
            r.x + r.w / 2, r.y + r.h, r.x, r.y + r.h - 8, r.x, r.y + 7)
    else
        love.graphics.rectangle(mode, r.x, r.y, r.w, r.h, 8, 8)
    end
end

return art
