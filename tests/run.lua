local passed = 0
local function test(name, run)
    run()
    passed = passed + 1
    print("PASS " .. name)
end

local suites = {
    "tests.match_test",
    "tests.spells_test",
    "tests.ai_test",
    "tests.animation_test",
    "tests.layout_test",
    "tests.inspection_test",
    "tests.menu_test",
}

for _, name in ipairs(suites) do
    local suite = require(name)
    suite(test)
end

print(passed .. " tests passed")
