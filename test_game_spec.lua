-- busted specs for game.lua (pure logic) and the content files.
package.path = "./?.lua;./common/?.lua;" .. package.path
local Game = dofile("game.lua")

-- Build a game whose roles are fixed: roles[i] is player i's role.
local function rigged(roles)
    local comp = {}
    for _, r in ipairs(roles) do
        if r ~= "villager" then comp[r] = (comp[r] or 0) + 1 end
    end
    local names = {}
    for i = 1, #roles do names[i] = "P" .. i end
    local g = Game.new{ names = names, comp = comp, rng = function() return 1 end }
    for i, r in ipairs(roles) do g.players[i].role = r end
    return g
end

-- Play the night with the given choices per step ({ wolves = 3, ... }).
local function night(g, choices)
    g:startNight()
    while not g:nightDone() do
        local step = g:currentStep()
        g:act(choices[step])
    end
    return g:resolveNight()
end

describe("composition", function()
    it("suggests a valid composition for every table size", function()
        for n = Game.MIN_PLAYERS, Game.MAX_PLAYERS do
            local comp = Game.suggest(n)
            assert.is_true(Game.isValid(comp, n), "n=" .. n)
            assert.is_true(Game.villagers(comp, n) >= 0)
        end
    end)

    it("refuses an unplayable change", function()
        local comp = Game.suggest(6)
        assert.is_nil(Game.adjust(comp, 6, "werewolf", -2))   -- no werewolf left
        assert.is_nil(Game.adjust(comp, 6, "werewolf", 1))    -- wolves not a minority
        assert.is_nil(Game.adjust(comp, 6, "seer", 1))        -- one seer at most
        local c2 = Game.adjust(comp, 6, "hunter", 1)
        assert.equals(1, c2.hunter)
        assert.equals(Game.villagers(comp, 6) - 1, Game.villagers(c2, 6))
        assert.is_nil(comp.hunter)                              -- original untouched
    end)

    it("deals exactly the composition", function()
        local names = {}
        for i = 1, 12 do names[i] = "N" .. i end
        local comp = Game.suggest(12)
        local g = Game.new{ names = names, comp = comp }
        local count = {}
        for _, p in ipairs(g.players) do count[p.role] = (count[p.role] or 0) + 1 end
        for role, c in pairs(comp) do assert.equals(c, count[role]) end
        assert.equals(Game.villagers(comp, 12), count.villager or 0)
    end)
end)

describe("night", function()
    it("orders the steps and calls cupid only on night 1", function()
        local g = rigged{ "werewolf", "werewolf", "cupid", "guard", "seer", "witch", "whitewolf", "villager" }
        g:startNight()
        assert.same({ "cupid", "lovers", "guard", "seer", "wolves", "witch" }, g.ns.steps)
        while not g:nightDone() do g:act(nil) end
        g:resolveNight()
        g:startNight()
        assert.same({ "guard", "seer", "wolves", "whitewolf", "witch" }, g.ns.steps)
    end)

    it("kills the wolves' victim", function()
        local g = rigged{ "werewolf", "villager", "villager", "villager", "villager", "villager" }
        local deaths = night(g, { wolves = 3 })
        assert.equals(1, #deaths)
        assert.equals(3, deaths[1].i)
        assert.is_false(g.players[3].alive)
        assert.equals("day", g.phase)
    end)

    it("wolves cannot target a wolf, the seer sees roles", function()
        local g = rigged{ "werewolf", "seer", "villager", "villager", "villager", "villager" }
        g:startNight()
        assert.is_false(g:canTarget("wolves", 1))
        assert.is_false(g:canTarget("seer", 2))
        assert.equals("seer", g:currentStep())
        assert.equals("werewolf", g:act(1))
    end)

    it("the guard saves, but not the same player twice in a row", function()
        local g = rigged{ "werewolf", "guard", "villager", "villager", "villager", "villager" }
        local deaths = night(g, { guard = 3, wolves = 3 })
        assert.equals(0, #deaths)
        g:vote(nil)
        g:startNight()
        assert.is_false(g:canTarget("guard", 3))
        assert.is_true(g:canTarget("guard", 4))
    end)

    it("the witch heals once and poisons once", function()
        local g = rigged{ "werewolf", "witch", "villager", "villager", "villager", "villager", "villager" }
        local deaths = night(g, { wolves = 3, witch = { heal = true, poison = 4 } })
        assert.equals(1, #deaths)
        assert.equals(4, deaths[1].i)
        assert.equals("poison", deaths[1].cause)
        assert.is_true(g.heal_used and g.poison_used)
        g:vote(nil)
        g:startNight()
        assert.is_false(g:stepActive("witch"))
        while not g:nightDone() do
            g:act(g:currentStep() == "wolves" and 3 or { heal = true, poison = 5 })
        end
        deaths = g:resolveNight()
        assert.equals(1, #deaths)
        assert.equals(3, deaths[1].i)
    end)

    it("the elder survives the first attack only", function()
        local g = rigged{ "werewolf", "elder", "villager", "villager", "villager", "villager" }
        assert.equals(0, #night(g, { wolves = 2 }))
        g:vote(nil)
        local deaths = night(g, { wolves = 2 })
        assert.equals(1, #deaths)
        assert.is_false(g.powers_lost)  -- killed by wolves: no curse
    end)

    it("lovers die together", function()
        local g = rigged{ "werewolf", "cupid", "villager", "villager", "villager", "villager", "villager" }
        local deaths = night(g, { cupid = { 3, 4 }, wolves = 3 })
        assert.equals(2, #deaths)
        assert.equals("grief", deaths[2].cause)
        assert.equals(4, deaths[2].i)
    end)
end)

describe("day", function()
    it("the hunter shoots before the game can end", function()
        local g = rigged{ "werewolf", "hunter", "villager", "villager", "villager", "villager" }
        night(g, { wolves = 2 })
        assert.equals(2, g:pendingHunter())
        assert.is_false(g:isOver())
        g:hunterShoot(1)
        assert.is_true(g:isOver())
        assert.equals("village", g.winner)
    end)

    it("the idiot is spared once", function()
        local g = rigged{ "werewolf", "idiot", "villager", "villager", "villager", "villager" }
        night(g, { wolves = 3 })
        assert.equals("idiot", g:vote(2).kind)
        assert.is_true(g.players[2].alive)
        assert.equals("death", g:vote(2).kind)
        assert.is_false(g.players[2].alive)
    end)

    it("killing the elder by vote takes the powers away", function()
        local g = rigged{ "werewolf", "elder", "seer", "hunter", "villager", "villager", "villager" }
        night(g, { wolves = 5 })
        g:vote(2)
        assert.is_true(g.powers_lost)
        g:startNight()
        assert.is_false(g:stepActive("seer"))
        while not g:nightDone() do g:act(g:currentStep() == "wolves" and 4 or nil) end
        g:resolveNight()
        assert.is_nil(g:pendingHunter())  -- the hunter lost his shot too
    end)
end)

describe("win", function()
    it("werewolves win when only they remain", function()
        local g = rigged{ "werewolf", "werewolf", "villager", "villager", "villager", "villager" }
        night(g, { wolves = 3 }); g:vote(4)
        night(g, { wolves = 5 }); assert.is_false(g:isOver())
        g:vote(6)
        assert.equals("wolves", g.winner)
        assert.is_true(g:isWinner(1))
        assert.is_false(g:isWinner(3))
    end)

    it("a werewolf–villager couple wins as the last two", function()
        local g = rigged{ "werewolf", "cupid", "villager", "villager", "villager", "villager" }
        night(g, { cupid = { 1, 3 }, wolves = 2 })
        g:vote(4); night(g, { wolves = 5 })
        assert.is_false(g:isOver())
        g:vote(6)
        assert.equals("lovers", g.winner)
        assert.is_true(g:isWinner(1) and g:isWinner(3))
    end)

    it("the white werewolf wins alone, and blocks the pack's win", function()
        local g = rigged{ "werewolf", "whitewolf", "villager", "villager", "villager", "villager" }
        night(g, { wolves = 3 }); g:vote(4)
        night(g, { wolves = 5, whitewolf = nil }); g:vote(6)
        assert.is_false(g:isOver())          -- wolf + white wolf: not over yet
        night(g, {})                          -- night 3: no white wolf, no target
        g:vote(nil)
        night(g, { whitewolf = 1 })           -- night 4: he devours the last wolf
        assert.equals("white", g.winner)
    end)
end)

describe("save", function()
    it("round-trips through serialize/load", function()
        local g = rigged{ "werewolf", "seer", "villager", "villager", "villager", "villager" }
        g:startNight()
        g:act(3)
        local copy = Game.load(g:serialize())
        assert.equals("wolves", copy:currentStep())
        copy:act(4)
        assert.equals(1, #copy:resolveNight())
        assert.is_nil(Game.load({}))
    end)
end)

describe("random games", function()
    it("always end with a winner", function()
        math.randomseed(42)
        for round = 1, 300 do
            local n = Game.MIN_PLAYERS + (round % (Game.MAX_PLAYERS - Game.MIN_PLAYERS + 1))
            local names = {}
            for i = 1, n do names[i] = "R" .. i end
            local g = Game.new{ names = names, comp = Game.suggest(n) }
            local function any(list) return list[math.random(#list)] end
            local turns = 0
            while not g:isOver() and turns < 60 do
                turns = turns + 1
                g:startNight()
                while not g:nightDone() do
                    local step = g:currentStep()
                    local t = g:targets(step)
                    local choice
                    if #t > 0 and g:stepActive(step) then
                        if step == "cupid" then choice = { t[1], t[#t] }
                        elseif step == "witch" then choice = { heal = math.random() < 0.3, poison = math.random() < 0.3 and any(g:targets("witch")) or nil }
                        elseif step ~= "lovers" then choice = any(t) end
                    end
                    g:act(choice)
                end
                g:resolveNight()
                while g:pendingHunter() do
                    local alive = {}
                    for i, p in ipairs(g.players) do if p.alive then alive[#alive + 1] = i end end
                    g:hunterShoot(#alive > 0 and any(alive) or nil)
                end
                if not g:isOver() then
                    local alive = {}
                    for i, p in ipairs(g.players) do if p.alive then alive[#alive + 1] = i end end
                    g:vote(any(alive))
                    while g:pendingHunter() do
                        local al = {}
                        for i, p in ipairs(g.players) do if p.alive then al[#al + 1] = i end end
                        g:hunterShoot(#al > 0 and any(al) or nil)
                    end
                end
            end
            assert.is_true(g:isOver(), "game " .. round .. " did not end")
            assert.is_not_nil(g.winner)
        end
    end)
end)

describe("content", function()
    local NIGHT = { "thief", "cupid", "lovers", "wildchild", "sisters", "guard", "seer", "fox", "wolves",
                    "father", "infected", "bigwolf", "whitewolf", "witch", "piper", "charmed", "raven" }
    local LISTS = { night_deaths = 80, vote_deaths = 40, no_deaths = 20, no_vote = 10, grief = 10, shot = 10,
                    hunter_spares = 5, idiot = 10, scapegoat = 10, tetanus = 10, bear_growl = 10, bear_quiet = 10,
                    raven = 10, mayor_elected = 10, mayor_successor = 10, powers_lost = 5 }
    local function count(v) return type(v) == "table" and #v or (type(v) == "string" and 1 or 0) end
    for _, lang in ipairs({ "en", "fr" }) do
        it("has every role, step and line in " .. lang, function()
            local c = dofile("content_" .. lang .. ".lua")
            for _i, role in ipairs(Game.ROLE_ORDER) do
                assert.is_string(c.roles[role].name, role)
                assert.is_string(c.roles[role].a, role)
                assert.is_string(c.roles[role].desc, role)
            end
            for role in pairs(Game.ROLES) do assert.is_table(c.roles[role], role) end
            for _i, step in ipairs(NIGHT) do
                assert.is_true(count(c.narr[step]) >= 10, step)
                assert.is_true(count(c.narr.sleep[step]) >= 1, "sleep " .. step)
                assert.is_string(c.titles[step], "title " .. step)
            end
            for k, n in pairs({ night_start = 15, dawn = 12, debate = 12, vote = 10, election = 10,
                                seer = 12, wolves = 12 }) do
                assert.is_true(count(c.narr[k]) >= n, k)
            end
            assert.is_true(count(c.narr.littlegirl) >= 3)
            for k, n in pairs(LISTS) do assert.is_true(count(c[k]) >= n, k) end
            for _i, l in ipairs(c.night_deaths) do assert.truthy(l:find("%1", 1, true), l) end
            for _i, l in ipairs(c.tetanus) do assert.truthy(l:find("%2", 1, true), l) end
            for _i, w in ipairs({ "village", "wolves", "lovers", "white", "piper", "nobody" }) do
                assert.is_string(c.win_title[w], w)
                assert.is_true(count(c.win[w]) >= 1, w)
            end
            for _i, k in ipairs({ "wolves", "white", "bigwolf", "poison", "vote", "shot", "grief", "tetanus", "scapegoat" }) do
                assert.is_string(c.causes[k], k)
            end
            for _i, k in ipairs({ "infected", "turned", "charmed", "lover", "mayor" }) do assert.is_string(c.marks[k], k) end
            for _i, k in ipairs({ "night", "day", "death", "thief", "thief_keep", "wildchild", "turned", "raven",
                                  "infect", "bigwolf", "charm", "mayor", "successor", "bear", "tie" }) do
                assert.is_string(c.log[k], k)
            end
        end)
        it("has at least 250 distinct aliases in " .. lang, function()
            local a = dofile("aliases_" .. lang .. ".lua")
            assert.is_true(#a >= 250, #a)
            local seen = {}
            for _i, x in ipairs(a) do
                assert.is_nil(seen[x:lower()], x)
                seen[x:lower()] = true
            end
        end)
    end

    it("excludes the forbidden names", function()
        local BAD = { "hitler", "stalin", "staline", "pol pot", "mussolini", "ben laden", "bin laden",
                      "mao zedong", "pinochet", "kim jong", "saddam", "kadhafi", "gaddafi", "idi amin",
                      "franco", "ceausescu", "himmler", "landru", "ripper", "éventreur", "attila" }
        for _, lang in ipairs({ "en", "fr" }) do
            for _i, f in ipairs({ "content_" .. lang .. ".lua", "aliases_" .. lang .. ".lua",
                                  "pack_famous_" .. lang .. ".lua", "pack_medieval_" .. lang .. ".lua",
                                  "pack_space_" .. lang .. ".lua", "pack_pirate_" .. lang .. ".lua" }) do
                local h = io.open(f); local text = h:read("*a"):lower(); h:close()
                for _j, bad in ipairs(BAD) do
                    assert.is_nil(text:find("%f[%w]" .. bad:gsub("%p", "%%%0") .. "%f[%W]"), f .. ": " .. bad)
                end
            end
        end
    end)
end)

describe("theme packs", function()
    local STEPS = { "night_start", "thief", "cupid", "lovers", "wildchild", "sisters", "guard", "seer", "fox",
                    "wolves", "father", "infected", "bigwolf", "whitewolf", "witch", "piper", "charmed",
                    "raven", "dawn", "election", "debate", "vote" }
    local ARGS = { night_deaths = 1, vote_deaths = 1, grief = 1, shot = 2, idiot = 1, scapegoat = 1,
                   tetanus = 2, raven = 1, mayor_elected = 1, mayor_successor = 2 }
    for _, lang in ipairs({ "en", "fr" }) do
        for _, theme in ipairs({ "medieval", "space", "pirate" }) do
            it(theme .. " has its own narration and flavour in " .. lang, function()
                local pk = dofile("pack_" .. theme .. "_" .. lang .. ".lua")
                for _i, st in ipairs(STEPS) do assert.is_true(#pk.narr[st] >= 8, st) end
                assert.is_true(#pk.narr.littlegirl >= 8)
                local dup = {}
                for k, l in pairs(pk.narr) do
                    if type(l[1]) == "string" then
                        for _j, line in ipairs(l) do
                            assert.is_nil(dup[line], theme .. " " .. k .. " duplicate: " .. line)
                            dup[line] = true
                        end
                    end
                end
                assert.is_true(#pk.night_deaths >= 20)
                assert.is_true(#pk.vote_deaths >= 10)
                assert.is_true(#pk.no_deaths >= 6)
                for _i, w in ipairs({ "village", "wolves", "lovers", "white", "piper", "nobody" }) do
                    assert.is_true(#pk.win[w] >= 1, w)
                end
            end)
        end
        it("packs use the right placeholders in " .. lang, function()
            for _i, theme in ipairs({ "famous", "medieval", "space", "pirate" }) do
                local pk = dofile("pack_" .. theme .. "_" .. lang .. ".lua")
                for key, n in pairs(ARGS) do
                    for _j, l in ipairs(pk[key] or {}) do
                        assert.truthy(l:find("%1", 1, true), theme .. " " .. key .. ": " .. l)
                        if n == 2 then assert.truthy(l:find("%2", 1, true), theme .. " " .. key .. ": " .. l) end
                    end
                end
            end
        end)
    end
end)

describe("new roles", function()
    it("the thief swaps with a leftover card on night 1", function()
        local g = rigged{ "thief", "werewolf", "villager", "villager", "villager", "villager" }
        g.extra = { "seer", "villager" }
        g.thief_idx = 1
        g:startNight()
        assert.equals("thief", g:currentStep())
        assert.equals("seer", g:act(1))
        assert.equals("seer", g.players[1].role)
        assert.same({ "thief", "villager" }, g.extra)
    end)

    it("the thief must take a werewolf when both leftovers are", function()
        local g = rigged{ "thief", "werewolf", "villager", "villager", "villager", "villager" }
        g.extra = { "werewolf", "werewolf" }
        g.thief_idx = 1
        g:startNight()
        assert.is_true(g:thiefMustTake())
        assert.equals("werewolf", g:act(nil))
        assert.is_true(g:isWolf(1))
    end)

    it("a dealt thief game keeps the thief and a werewolf in hand", function()
        for seed = 1, 50 do
            math.randomseed(seed)
            local names = {}
            for i = 1, 8 do names[i] = "T" .. i end
            local comp = { werewolf = 1, thief = 1, seer = 1 }
            local g = Game.new{ names = names, comp = comp }
            assert.equals(2, #g.extra)
            assert.is_not_nil(g.thief_idx)
            assert.is_not_nil(g:holder("werewolf"))
        end
    end)

    it("the fox smells a wolf among neighbours, or loses the scent", function()
        local g = rigged{ "fox", "villager", "werewolf", "villager", "villager", "villager", "villager" }
        g:startNight()
        while g:currentStep() ~= "fox" do g:act(nil) end
        local r = g:act(2)
        assert.is_true(r.found)
        assert.same({ 1, 2, 3 }, r.group)
        while not g:nightDone() do g:act(nil) end
        g:resolveNight(); g:vote(nil)
        g:startNight()
        while g:currentStep() ~= "fox" do g:act(nil) end
        r = g:act(5)
        assert.is_false(r.found)
        assert.is_true(g.fox_lost)
    end)

    it("the raven marks a player for the next vote", function()
        local g = rigged{ "raven", "werewolf", "villager", "villager", "villager", "villager" }
        night(g, { raven = 4 })
        assert.equals(4, g.raven_mark)
        g:vote(nil); g:startNight()
        assert.is_nil(g.raven_mark)
    end)

    it("the bear growls next to a werewolf", function()
        local g = rigged{ "villager", "beartamer", "werewolf", "villager", "villager", "villager" }
        night(g, {})
        assert.equals("growl", g.bear)
        local h = rigged{ "beartamer", "villager", "villager", "werewolf", "villager", "villager" }
        night(h, {})
        assert.equals("quiet", h.bear)
    end)

    it("the knight's rusty sword kills the next wolf on his left the following night", function()
        local g = rigged{ "knight", "villager", "werewolf", "werewolf", "villager", "villager", "villager", "villager" }
        night(g, { wolves = 1 })
        assert.is_false(g.players[1].alive)
        g:vote(nil)
        local deaths = night(g, {})
        assert.equals(3, deaths[1].i)
        assert.equals("tetanus", deaths[1].cause)
    end)

    it("the scapegoat pays for a tie", function()
        local g = rigged{ "scapegoat", "werewolf", "villager", "villager", "villager", "villager" }
        night(g, {})
        local r = g:voteTie()
        assert.equals("scapegoat", r.kind)
        assert.is_false(g.players[1].alive)
        assert.equals("none", g:voteTie().kind)
    end)

    it("the wild child turns when the model dies", function()
        local g = rigged{ "wildchild", "werewolf", "villager", "villager", "villager", "villager", "villager" }
        night(g, { wildchild = 4, wolves = 4 })
        assert.is_true(g.players[1].turned)
        assert.is_true(g:isWolf(1))
    end)

    it("the sisters wake together on odd nights", function()
        local g = rigged{ "sister", "sister", "werewolf", "villager", "villager", "villager" }
        g:startNight()
        assert.equals("sisters", g:currentStep())
        assert.is_true(g:stepActive("sisters"))
        assert.is_nil(Game.adjust({ werewolf = 1, sister = 2 }, 6, "sister", 1))
        assert.equals(2, Game.adjust({ werewolf = 1 }, 6, "sister", 1).sister)
    end)

    it("the big bad wolf kills a second victim while no wolf has died", function()
        local g = rigged{ "bigwolf", "werewolf", "villager", "villager", "villager", "villager", "villager", "villager" }
        local deaths = night(g, { wolves = 3, bigwolf = 4 })
        assert.equals(2, #deaths)
        g:vote(2)
        g:startNight()
        assert.is_false(g:stepActive("bigwolf"))
    end)

    it("the wolf-father infects once; the infected joins the pack", function()
        local g = rigged{ "father", "werewolf", "seer", "villager", "villager", "villager", "villager" }
        g:startNight()
        local infected_step_seen
        while not g:nightDone() do
            local st = g:currentStep()
            if st == "wolves" then g:act(3)
            elseif st == "father" then g:act(true)
            elseif st == "infected" then infected_step_seen = g:stepActive("infected"); g:act(nil)
            else g:act(nil) end
        end
        local deaths = g:resolveNight()
        assert.equals(0, #deaths)
        assert.is_true(infected_step_seen)
        assert.is_true(g.players[3].infected and g:isWolf(3))
        assert.is_true(g.infect_used)
        assert.is_false(g:canTarget("wolves", 3))
    end)

    it("the pied piper wins when everyone else alive is charmed", function()
        local g = rigged{ "piper", "werewolf", "villager", "villager", "villager", "villager" }
        night(g, { piper = { 3, 4 }, wolves = 5 })
        g:vote(6)
        assert.is_false(g:isOver())
        night(g, { piper = { 2 }, wolves = 3 })
        assert.equals("piper", g.winner)
        assert.is_true(g:isWinner(1))
    end)

    it("the mayor is elected and passes the sash on death", function()
        local names = {}
        for i = 1, 6 do names[i] = "M" .. i end
        local g = Game.new{ names = names, comp = { werewolf = 1 }, mayor = true, rng = function() return 1 end }
        for i = 1, 6 do g.players[i].role = i == 1 and "werewolf" or "villager" end
        night(g, {})
        assert.is_true(g:needsElection())
        g:elect(3)
        assert.is_false(g:needsElection())
        g:vote(3)
        assert.equals(3, g:pendingSuccession())
        g:passSash(4)
        assert.equals(4, g.mayor)
    end)
end)

describe("random games with every role", function()
    it("always end with a winner", function()
        local roles = {}
        for _, r in ipairs(Game.ROLE_ORDER) do if r ~= "villager" and r ~= "werewolf" then roles[#roles + 1] = r end end
        local function any(list) return list[math.random(#list)] end
        local function alive(g)
            local out = {}
            for i, p in ipairs(g.players) do if p.alive then out[#out + 1] = i end end
            return out
        end
        local function hunters(g)
            while g:pendingHunter() do
                local a = alive(g)
                g:hunterShoot(#a > 0 and any(a) or nil)
            end
            if g:pendingSuccession() then
                local a = alive(g)
                g:passSash(#a > 0 and any(a) or nil)
            end
        end
        for round = 1, 400 do
            math.randomseed(1000 + round)
            local n = math.random(Game.MIN_PLAYERS, Game.MAX_PLAYERS)
            local comp = { werewolf = math.random(1, math.max(1, math.floor(n / 5))) }
            for _ = 1, math.random(2, 10) do
                local new = Game.adjust(comp, n, any(roles), 1)
                if new then comp = new end
            end
            assert.is_true(Game.isValid(comp, n))
            local names = {}
            for i = 1, n do names[i] = "R" .. i end
            local g = Game.new{ names = names, comp = comp, mayor = math.random() < 0.5 }
            local turns = 0
            while not g:isOver() and turns < 80 do
                turns = turns + 1
                g:startNight()
                while not g:nightDone() do
                    local step = g:currentStep()
                    local t = g:targets(step)
                    local choice
                    if g:stepActive(step) then
                        if step == "thief" then choice = g:thiefMustTake() and 1 or any({ 1, 2, false }) or nil
                        elseif step == "cupid" or step == "piper" then
                            if #t >= 2 then choice = { t[1], t[#t] } elseif #t == 1 then choice = { t[1] } end
                        elseif step == "witch" then
                            choice = { heal = math.random() < 0.3,
                                       poison = math.random() < 0.3 and any(alive(g)) or nil }
                        elseif step == "father" then choice = math.random() < 0.5 or nil
                        elseif step == "fox" then choice = any(alive(g))
                        elseif #t > 0 and step ~= "lovers" and step ~= "sisters" and step ~= "charmed"
                            and step ~= "infected" then choice = any(t) end
                    end
                    g:act(choice)
                end
                g:resolveNight()
                hunters(g)
                if not g:isOver() then
                    if g:needsElection() then g:elect(any(alive(g))) end
                    local r = math.random()
                    if r < 0.1 then g:voteTie() elseif r < 0.15 then g:vote(nil) else g:vote(any(alive(g))) end
                    hunters(g)
                end
            end
            assert.is_true(g:isOver(), "game " .. round .. " did not end")
            assert.is_not_nil(g.winner)
        end
    end)
end)

describe("narration picker", function()
    local Narration = dofile("narration.lua")
    local SeenHistory = require("seen_history")
    local function fakePlugin()
        local store = {}
        return { getSetting = function(_, k, d) if store[k] == nil then return d end return store[k] end,
                 saveSetting = function(_, k, v) store[k] = v end, store = store }
    end
    local base = dofile("content_fr.lua")

    for _, theme in ipairs({ "medieval", "space", "pirate" }) do
        it(theme .. ": the pack's lines, then the classic ones, before any repeat in a game", function()
            local pk = dofile("pack_" .. theme .. "_fr.lua")
            local own, classic = pk.narr.wolves, base.narr.wolves
            local isOwn = {}
            for _i, l in ipairs(own) do isOwn[l] = true end
            local state, heard = {}, {}
            for n = 1, #own + #classic do
                local l = Narration.pick(state, theme .. ":wolves", "wolves", own, classic, nil, math.random)
                assert.is_nil(heard[l], "repeated: " .. l)
                heard[l] = true
                if n <= #own then assert.is_true(isOwn[l]) else assert.is_nil(isOwn[l]) end
            end
            -- everything heard: a new cycle starts with the pack's lines
            local l = Narration.pick(state, theme .. ":wolves", "wolves", own, classic, nil, math.random)
            assert.is_true(isOwn[l])
        end)
    end

    it("does not repeat a line in the next game while unheard ones are left", function()
        local plugin = fakePlugin()
        local pk = dofile("pack_pirate_en.lua")
        local own, classic = pk.narr.seer, dofile("content_en.lua").narr.seer
        local heard = {}
        -- three games of three nights; history reopened from the settings each game
        for _game = 1, 3 do
            local seen = SeenHistory.open(plugin, "narr_pirate_en", { max = 1500 })
            local state = {}
            for _night = 1, 3 do
                local l = Narration.pick(state, "pirate:seer", "seer", own, classic, seen, math.random)
                assert.is_nil(heard[l], "heard in an earlier game: " .. l)
                heard[l] = true
            end
        end
        assert.is_table(plugin.store.seen_narr_pirate_en)
    end)

    it("upgrades an old { order, pos } deck and handles a classic theme", function()
        local list = base.narr.seer
        local state = { ["classic:seer"] = { order = { 1, 2 }, pos = 3 } }
        local l = Narration.pick(state, "classic:seer", "seer", list, list, nil, math.random)
        assert.is_string(l)
        assert.is_table(state["classic:seer"].used)
        for _i = 1, #list * 2 do Narration.pick(state, "classic:seer", "seer", list, nil, nil, math.random) end
        assert.are.equal("x", Narration.pick({}, "k", "k", "x"))
        assert.are.equal("", Narration.pick({}, "k", "k", {}))
    end)
end)
