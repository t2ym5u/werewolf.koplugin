-- Werewolf game engine: roles, composition, night/day resolution, win check.
-- Pure Lua, no UI and no translations, so the specs can drive a whole game.
-- Players are referred to by index (1..n) everywhere; the list order is the
-- seating order around the table (it matters for the fox, the bear tamer and
-- the knight).

local Game = {}
Game.__index = Game

Game.MIN_PLAYERS = 6
Game.MAX_PLAYERS = 18

-- Display / editor order. "villager" is never edited: it is what is left.
Game.ROLE_ORDER = {
    "werewolf", "bigwolf", "father", "whitewolf",
    "seer", "witch", "hunter", "cupid", "guard", "littlegirl", "elder", "idiot",
    "fox", "raven", "beartamer", "knight", "scapegoat", "sister", "wildchild",
    "piper", "thief", "villager",
}

-- team: which side the role plays for. The white werewolf wakes with the
-- pack but wins only as the last one standing; the pied piper wins alone.
-- step: how many cards one +/- adds (the two sisters come as a pair).
Game.ROLES = {
    villager   = { team = "village" },
    werewolf   = { team = "wolves", max = 6 },
    bigwolf    = { team = "wolves", max = 1 },
    father     = { team = "wolves", max = 1 },
    whitewolf  = { team = "solo",   max = 1 },
    seer       = { team = "village", max = 1 },
    witch      = { team = "village", max = 1 },
    hunter     = { team = "village", max = 1 },
    cupid      = { team = "village", max = 1 },
    guard      = { team = "village", max = 1 },
    littlegirl = { team = "village", max = 1 },
    elder      = { team = "village", max = 1 },
    idiot      = { team = "village", max = 1 },
    fox        = { team = "village", max = 1 },
    raven      = { team = "village", max = 1 },
    beartamer  = { team = "village", max = 1 },
    knight     = { team = "village", max = 1 },
    scapegoat  = { team = "village", max = 1 },
    sister     = { team = "village", max = 2, step = 2 },
    wildchild  = { team = "village", max = 1 },
    piper      = { team = "solo",   max = 1 },
    thief      = { team = "village", max = 1 },
}

-- Cards that are werewolves from the start.
local WOLF_ROLES = { werewolf = true, bigwolf = true, father = true, whitewolf = true }
Game.WOLF_ROLES = WOLF_ROLES

-- Village roles whose power the elder's death (at the village's hands) takes away.
local VILLAGE_POWERS = {
    seer = true, witch = true, guard = true, hunter = true,
    fox = true, raven = true, beartamer = true, knight = true,
}

-- ---------------------------------------------------------------------------
-- Composition
-- ---------------------------------------------------------------------------

-- Special roles added one by one as the table grows.
local SPECIAL_LADDER = {
    "seer", "witch", "hunter", "cupid", "guard", "littlegirl", "elder", "idiot",
    "fox", "knight", "raven", "beartamer", "wildchild", "scapegoat",
}

function Game.suggest(n)
    n = math.max(Game.MIN_PLAYERS, math.min(Game.MAX_PLAYERS, n))
    local comp = {}
    if n <= 8 then comp.werewolf = 2
    elseif n <= 12 then comp.werewolf = 3
    elseif n <= 16 then comp.werewolf = 3; comp.whitewolf = 1
    else comp.werewolf = 4; comp.whitewolf = 1 end
    local wolves = comp.werewolf + (comp.whitewolf or 0)
    local specials = math.min(#SPECIAL_LADDER, n - wolves - 2)
    for k = 1, specials do comp[SPECIAL_LADDER[k]] = 1 end
    return comp
end

-- Cards in the deck: one per player, plus two leftover cards with a thief.
function Game.deckSize(comp, n)
    return n + (((comp.thief or 0) > 0) and 2 or 0)
end

-- Number of plain villagers left once every other role is placed.
function Game.villagers(comp, n)
    local used = 0
    for role, c in pairs(comp) do
        if role ~= "villager" then used = used + c end
    end
    return Game.deckSize(comp, n) - used
end

function Game.maxCount(role, n)
    if role == "werewolf" then
        return math.max(1, math.min(Game.ROLES.werewolf.max, math.floor((n - 1) / 2)))
    end
    return Game.ROLES[role] and Game.ROLES[role].max or 0
end

function Game.wolfCount(comp)
    local w = 0
    for role in pairs(WOLF_ROLES) do w = w + (comp[role] or 0) end
    return w
end

-- A composition is playable when there is at least one werewolf, the wolf
-- side is a minority, and the roles do not outnumber the cards.
function Game.isValid(comp, n)
    if n < Game.MIN_PLAYERS or n > Game.MAX_PLAYERS then return false end
    if (comp.werewolf or 0) < 1 then return false end
    if Game.villagers(comp, n) < 0 then return false end
    if Game.wolfCount(comp) * 2 >= n then return false end
    local s = comp.sister or 0
    if s ~= 0 and s ~= 2 then return false end
    for role, c in pairs(comp) do
        if role ~= "villager" and c > Game.maxCount(role, n) then return false end
    end
    return true
end

-- Change one role's count by one step up or down (delta = 1 / -1); returns
-- the new comp, or nil if that would make it unplayable.
function Game.adjust(comp, n, role, delta)
    local new = {}
    for k, v in pairs(comp) do new[k] = v end
    local step = Game.ROLES[role] and Game.ROLES[role].step or 1
    local c = (new[role] or 0) + delta * step
    if c < 0 or c > Game.maxCount(role, n) then return nil end
    new[role] = c > 0 and c or nil
    if not Game.isValid(new, n) then return nil end
    return new
end

-- ---------------------------------------------------------------------------
-- New game
-- ---------------------------------------------------------------------------

local function shuffle(t, rng)
    for i = #t, 2, -1 do
        local j = rng(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end
Game.shuffle = shuffle

-- opts: names (list), comp, aliases (optional list, used in order),
--       mayor (bool: elect a mayor on day 1), rng (optional)
function Game.new(opts)
    local rng   = opts.rng or math.random
    local names = opts.names
    local n     = #names
    local deck  = {}
    for _, role in ipairs(Game.ROLE_ORDER) do
        if role ~= "villager" then
            for _ = 1, (opts.comp[role] or 0) do deck[#deck + 1] = role end
        end
    end
    for _ = 1, Game.villagers(opts.comp, n) do deck[#deck + 1] = "villager" end
    assert(#deck == Game.deckSize(opts.comp, n), "composition does not match the player count")
    shuffle(deck, rng)

    -- With a thief, the last two cards stay face down. The thief and at
    -- least one werewolf must be in the players' hands.
    local extra = {}
    if #deck > n then
        local function bringIn(role)
            for k = n + 1, #deck do
                if deck[k] == role then
                    local has = false
                    for i = 1, n do if deck[i] == role then has = true end end
                    if not has then
                        local j = rng(n)
                        if deck[j] == "thief" then j = j % n + 1 end
                        deck[j], deck[k] = deck[k], deck[j]
                    end
                    return
                end
            end
        end
        bringIn("thief")
        bringIn("werewolf")
        extra = { deck[n + 1], deck[n + 2] }
    end

    local self = setmetatable({}, Game)
    self.players = {}
    for i = 1, n do
        self.players[i] = {
            name  = names[i],
            alias = opts.aliases and opts.aliases[i] or nil,
            role  = deck[i],
            alive = true,
        }
        if deck[i] == "thief" then self.thief_idx = i end
    end
    self.extra           = extra
    self.comp            = {}
    for k, v in pairs(opts.comp) do self.comp[k] = v end
    self.mayor_enabled   = opts.mayor and true or false
    self.phase           = "deal"   -- deal → night → day → ... → over
    self.deal_index      = 1
    self.night           = 0
    self.day             = 0
    self.elder_lives     = 2
    self.heal_used       = false
    self.poison_used     = false
    self.infect_used     = false
    self.fox_lost        = false
    self.wolf_died       = false
    self.guard_last      = nil
    self.powers_lost     = false
    self.idiot_revealed  = false
    self.lovers          = nil
    self.pending_hunters = {}
    self.log             = {}
    self.winner          = nil
    return self
end

function Game.load(t)
    if type(t) ~= "table" or type(t.players) ~= "table" or not t.phase then return nil end
    t.pending_hunters = t.pending_hunters or {}
    t.log = t.log or {}
    t.extra = t.extra or {}
    return setmetatable(t, Game)
end

function Game:serialize()
    local t = {}
    for k, v in pairs(self) do t[k] = v end
    return t
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function Game:count() return #self.players end

function Game:has(role)
    return (self.comp[role] or 0) > 0
end

function Game:holder(role)
    for i, p in ipairs(self.players) do
        if p.role == role then return i end
    end
end

function Game:holders(role)
    local out = {}
    for i, p in ipairs(self.players) do
        if p.role == role then out[#out + 1] = i end
    end
    return out
end

function Game:aliveCount()
    local c = 0
    for _, p in ipairs(self.players) do if p.alive then c = c + 1 end end
    return c
end

function Game:alive(i) return self.players[i] ~= nil and self.players[i].alive end

function Game:role(i) return self.players[i].role end

function Game:team(i) return Game.ROLES[self.players[i].role].team end

-- On the werewolves' side right now: a wolf card, an infected player, or a
-- wild child whose model has died.
function Game:isWolf(i)
    local p = self.players[i]
    return WOLF_ROLES[p.role] or p.infected or (p.role == "wildchild" and p.turned) or false
end

function Game:isLover(i)
    return self.lovers ~= nil and (self.lovers[1] == i or self.lovers[2] == i)
end

function Game:partner(i)
    if not self.lovers then return nil end
    if self.lovers[1] == i then return self.lovers[2] end
    if self.lovers[2] == i then return self.lovers[1] end
end

-- The nearest living players on each side of i (seating order wraps).
function Game:neighbours(i)
    local n = #self.players
    local left, right
    for k = 1, n - 1 do
        local j = ((i - 1 - k) % n) + 1
        if self.players[j].alive then left = j; break end
    end
    for k = 1, n - 1 do
        local j = ((i - 1 + k) % n) + 1
        if self.players[j].alive then right = j; break end
    end
    return left, right
end

-- The role still has its power: alive, and for the village specialists, the
-- elder has not been killed by the village.
function Game:roleActive(role)
    for _, i in ipairs(self:holders(role)) do
        if self.players[i].alive then
            return not (VILLAGE_POWERS[role] and self.powers_lost)
        end
    end
    return false
end

function Game:anyAlive(pred)
    for i, p in ipairs(self.players) do
        if p.alive and pred(i, p) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Distribution
-- ---------------------------------------------------------------------------

function Game:dealNext()
    self.deal_index = self.deal_index + 1
    return self.deal_index <= #self.players
end

-- ---------------------------------------------------------------------------
-- Night
-- ---------------------------------------------------------------------------

function Game:startNight()
    self.phase = "night"
    self.night = self.night + 1
    self.raven_mark = nil
    self.bear = nil
    local first = self.night == 1
    local steps = {}
    local function add(s) steps[#steps + 1] = s end
    if first and self:has("thief") then add("thief") end
    if first and self:has("cupid") then add("cupid"); add("lovers") end
    if first and self:has("wildchild") then add("wildchild") end
    if self:has("sister") and self.night % 2 == 1 then add("sisters") end
    if self:has("guard") then add("guard") end
    if self:has("seer") then add("seer") end
    if self:has("fox") then add("fox") end
    add("wolves")
    if self:has("father") then add("father") end
    if self:has("bigwolf") then add("bigwolf") end
    if self:has("whitewolf") and self.night % 2 == 0 then add("whitewolf") end
    if self:has("witch") then add("witch") end
    if self:has("father") then add("infected") end
    if self:has("piper") then add("piper"); add("charmed") end
    if self:has("raven") then add("raven") end
    self.ns = { steps = steps, idx = 1 }
end

function Game:currentStep()
    return self.ns and self.ns.steps[self.ns.idx]
end

function Game:nightDone()
    return self.ns ~= nil and self.ns.idx > #self.ns.steps
end

-- Whether the step's player(s) can act tonight. Steps of dead or powerless
-- roles are still called (so the table cannot tell who is gone), but there
-- is nothing to choose.
function Game:stepActive(step)
    local ns = self.ns or {}
    if step == "thief" then
        local t = self.thief_idx
        return t ~= nil and self.players[t].alive and self.players[t].role == "thief" and #self.extra == 2
    end
    if step == "cupid"     then return self:roleActive("cupid") end
    if step == "lovers"    then return self.lovers ~= nil end
    if step == "wildchild" then return self:roleActive("wildchild") and not self.model end
    if step == "sisters"   then return self:roleActive("sister") end
    if step == "guard"     then return self:roleActive("guard") end
    if step == "seer"      then return self:roleActive("seer") end
    if step == "fox"       then return self:roleActive("fox") and not self.fox_lost end
    if step == "wolves"    then return #self:targets("wolves") > 0 end
    if step == "father"    then
        return self:roleActive("father") and not self.infect_used and ns.wolves ~= nil
    end
    if step == "infected"  then
        return ns.infect == true and not ns.heal and ns.guard ~= ns.wolves
    end
    if step == "bigwolf"   then
        return self:roleActive("bigwolf") and not self.wolf_died and #self:targets("bigwolf") > 0
    end
    if step == "whitewolf" then return self:roleActive("whitewolf") and #self:targets("whitewolf") > 0 end
    if step == "witch"     then
        return self:roleActive("witch") and not (self.heal_used and self.poison_used)
    end
    if step == "piper"     then return self:roleActive("piper") and #self:targets("piper") > 0 end
    if step == "charmed"   then return self:anyAlive(function(_, p) return p.charmed end) end
    if step == "raven"     then return self:roleActive("raven") and #self:targets("raven") > 0 end
    return false
end

-- Players the step may pick.
function Game:targets(step)
    local ns = self.ns or {}
    local out = {}
    for i, p in ipairs(self.players) do
        if p.alive then
            local ok = true
            if step == "wolves" then ok = not self:isWolf(i)
            elseif step == "bigwolf" then ok = not self:isWolf(i) and i ~= ns.wolves
            elseif step == "whitewolf" then ok = self:isWolf(i) and p.role ~= "whitewolf"
            elseif step == "guard" then ok = i ~= self.guard_last
            elseif step == "seer" then ok = p.role ~= "seer"
            elseif step == "raven" then ok = p.role ~= "raven"
            elseif step == "wildchild" then ok = p.role ~= "wildchild"
            elseif step == "piper" then ok = p.role ~= "piper" and not p.charmed
            end
            if ok then out[#out + 1] = i end
        end
    end
    return out
end

function Game:canTarget(step, i)
    for _, t in ipairs(self:targets(step)) do
        if t == i then return true end
    end
    return false
end

function Game:_log(ev)
    ev.night = self.night
    ev.day   = self.day
    ev.phase = self.phase
    self.log[#self.log + 1] = ev
end

-- The fox's group: i and its living neighbours.
function Game:foxGroup(i)
    local l, r = self:neighbours(i)
    local g = { i }
    if l then table.insert(g, 1, l) end
    if r and r ~= l then g[#g + 1] = r end
    return g
end

-- The thief must take a card when both leftover cards are werewolves.
function Game:thiefMustTake()
    return #self.extra == 2 and WOLF_ROLES[self.extra[1]] and WOLF_ROLES[self.extra[2]] and true or false
end

-- Record the current step's choice and move to the next step.
--   thief: 1 / 2 (leftover card) or nil (keep: plain villager) → new role
--   cupid, piper: { a, b }      guard, seer, wolves, bigwolf, raven, wildchild: i
--   whitewolf: i or nil          fox: i → { found = bool, group = {...} }
--   father: true to infect       witch: { heal = bool, poison = i or nil }
--   seer returns the role seen.  lovers, sisters, infected, charmed: nil
function Game:act(choice)
    local step = self:currentStep()
    assert(step, "no night step to act on")
    local ns = self.ns
    local result
    if self:stepActive(step) then
        if step == "thief" then
            local t = self.thief_idx
            if not choice and self:thiefMustTake() then choice = 1 end
            if choice then
                local new = self.extra[choice]
                self.extra[choice] = "thief"
                self.players[t].role = new
                self:_log{ kind = "thief", a = t, role = new }
            else
                self.players[t].role = "villager"
                self:_log{ kind = "thief_keep", a = t }
            end
            result = self.players[t].role
        elseif step == "cupid" and choice then
            self.lovers = { choice[1], choice[2] }
            self:_log{ kind = "lovers", a = choice[1], b = choice[2] }
        elseif step == "wildchild" and choice then
            self.model = choice
            self:_log{ kind = "wildchild", a = self:holder("wildchild"), b = choice }
        elseif step == "guard" and choice then
            ns.guard        = choice
            self.guard_last = choice
            self:_log{ kind = "guard", a = choice }
        elseif step == "seer" and choice then
            result = self.players[choice].role
            self:_log{ kind = "seer", a = choice, role = result }
        elseif step == "fox" and choice then
            local group = self:foxGroup(choice)
            local found = false
            for _, j in ipairs(group) do if self:isWolf(j) then found = true end end
            if not found then self.fox_lost = true end
            self:_log{ kind = found and "fox_yes" or "fox_no", a = choice }
            result = { found = found, group = group }
        elseif step == "wolves" and choice then
            ns.wolves = choice
            self:_log{ kind = "attack", a = choice }
        elseif step == "father" and choice then
            ns.infect        = true
            self.infect_used = true
            self:_log{ kind = "infect", a = ns.wolves }
        elseif step == "bigwolf" and choice then
            ns.big = choice
            self:_log{ kind = "bigwolf", a = choice }
        elseif step == "whitewolf" and choice then
            ns.white = choice
            self:_log{ kind = "white", a = choice }
        elseif step == "witch" and choice then
            if choice.heal and not self.heal_used and ns.wolves then
                ns.heal        = true
                self.heal_used = true
                self:_log{ kind = "heal", a = ns.wolves }
            end
            if choice.poison and not self.poison_used then
                ns.poison        = choice.poison
                self.poison_used = true
                self:_log{ kind = "poison", a = choice.poison }
            end
        elseif step == "piper" and choice then
            for _, j in ipairs(choice) do self.players[j].charmed = true end
            self:_log{ kind = "charm", a = choice[1], b = choice[2] }
        elseif step == "raven" and choice then
            self.raven_mark = choice
            self:_log{ kind = "raven", a = choice }
        end
    elseif step == "guard" then
        -- A guard who cannot act protects nobody: next night anyone may be picked.
        self.guard_last = nil
    end
    ns.idx = ns.idx + 1
    return result
end

-- The pack's victim tonight (what the witch is shown).
function Game:wolvesVictim()
    return self.ns and self.ns.wolves
end

-- Kill i (if still alive) and everything that follows from it: the lover
-- dies of grief, the hunter gets a last shot, the elder killed by the
-- village takes the specialists' powers with him, the wild child's model
-- turns the child, the knight's sword poisons a wolf, the mayor's sash has
-- to be passed on. Appends to deaths.
function Game:_kill(i, cause, deaths)
    local p = self.players[i]
    if not p or not p.alive then return end
    local was_wolf = self:isWolf(i)
    p.alive = false
    p.cause = cause
    deaths[#deaths + 1] = { i = i, cause = cause }
    self:_log{ kind = "death", a = i, cause = cause, role = p.role }
    if was_wolf and p.role ~= "whitewolf" then self.wolf_died = true end
    if p.role == "elder" and (cause == "vote" or cause == "poison" or cause == "shot") then
        if not self.powers_lost then
            self.powers_lost = true
            self:_log{ kind = "powers_lost", a = i }
        end
    end
    if p.role == "hunter" and not self.powers_lost then
        self.pending_hunters[#self.pending_hunters + 1] = i
    end
    if p.role == "knight" and not self.powers_lost and not p.infected
        and (cause == "wolves" or cause == "bigwolf") then
        self.tetanus_pending = i
    end
    if self.mayor == i then
        self.mayor = nil
        self.mayor_pending = i
    end
    if self.model == i then
        local c = self:holder("wildchild")
        if c and self.players[c].alive and not self.players[c].turned then
            self.players[c].turned = true
            self:_log{ kind = "turned", a = c }
        end
    end
    local partner = self:partner(i)
    if partner then self:_kill(partner, "grief", deaths) end
end

-- First living werewolf to the knight's left (next seats in list order).
function Game:_tetanusVictim(k)
    local n = #self.players
    for s = 1, n - 1 do
        local j = ((k - 1 + s) % n) + 1
        if self.players[j].alive and self:isWolf(j) then return j end
    end
end

-- Apply the night's choices. Returns the list of deaths ({ i, cause }).
-- Moves to the day; self.bear tells whether the bear growled.
function Game:resolveNight()
    local ns, deaths = self.ns, {}
    if self.tetanus_pending then
        local w = self:_tetanusVictim(self.tetanus_pending)
        self.tetanus_pending = nil
        if w then self:_kill(w, "tetanus", deaths) end
    end
    local function attack(v, by)
        if not v or not self.players[v].alive then return end
        if ns.guard == v then
            self:_log{ kind = "saved", a = v, by = "guard" }
        elseif by == "wolves" and ns.heal then
            self:_log{ kind = "saved", a = v, by = "witch" }
        elseif by == "wolves" and ns.infect then
            self.players[v].infected = true
        elseif self.players[v].role == "elder" and self.elder_lives > 1 then
            self.elder_lives = self.elder_lives - 1
            self:_log{ kind = "saved", a = v, by = "elder" }
        else
            self:_kill(v, by, deaths)
        end
    end
    attack(ns.wolves, "wolves")
    attack(ns.big, "bigwolf")
    attack(ns.white, "white")
    if ns.poison then self:_kill(ns.poison, "poison", deaths) end
    self.ns    = nil
    self.phase = "day"
    self.day   = self.night
    -- The bear growls when a werewolf sits next to its tamer (or is the tamer).
    if self:roleActive("beartamer") then
        local t = self:holder("beartamer")
        local l, r = self:neighbours(t)
        local growl = self:isWolf(t) or (l and self:isWolf(l)) or (r and self:isWolf(r))
        self.bear = growl and "growl" or "quiet"
        if growl then self:_log{ kind = "bear" } end
    end
    self:_checkEnd()
    return deaths
end

-- ---------------------------------------------------------------------------
-- Day
-- ---------------------------------------------------------------------------

function Game:pendingHunter()
    return self.pending_hunters[1]
end

-- The hunter at the head of the queue shoots `target` (nil: holds fire).
-- Returns the deaths it causes.
function Game:hunterShoot(target)
    local h = table.remove(self.pending_hunters, 1)
    local deaths = {}
    if h and target and self.players[target] and self.players[target].alive then
        self:_log{ kind = "shot", a = h, b = target }
        self:_kill(target, "shot", deaths)
    end
    self:_checkEnd()
    return deaths
end

-- Mayor --------------------------------------------------------------------

function Game:needsElection()
    return self.mayor_enabled and self.mayor == nil and not self.mayor_pending
        and self.election_day ~= self.day and not self:isOver()
end

-- i, or nil to postpone to the next day.
function Game:elect(i)
    self.election_day = self.day
    if i and self.players[i].alive then
        self.mayor = i
        self:_log{ kind = "mayor", a = i }
    end
end

function Game:pendingSuccession()
    return self.mayor_pending
end

-- The dying mayor names a successor (nil: the village elects a new one).
function Game:passSash(i)
    local old = self.mayor_pending
    self.mayor_pending = nil
    if i and self.players[i].alive then
        self.mayor = i
        self:_log{ kind = "successor", a = old, b = i }
    end
end

-- The village's verdict: i, or nil for no elimination.
-- Returns { kind = "none" | "idiot" | "death", deaths = {...} }.
function Game:vote(i)
    local deaths = {}
    if not i then
        self:_log{ kind = "novote" }
        return { kind = "none", deaths = deaths }
    end
    local p = self.players[i]
    if p.role == "idiot" and not self.idiot_revealed then
        self.idiot_revealed = true
        p.revealed = true
        self:_log{ kind = "idiot", a = i }
        return { kind = "idiot", deaths = deaths }
    end
    self:_log{ kind = "vote", a = i }
    self:_kill(i, "vote", deaths)
    self:_checkEnd()
    return { kind = "death", deaths = deaths }
end

function Game:scapegoatAlive()
    local s = self:holder("scapegoat")
    return s ~= nil and self.players[s].alive
end

-- A tied vote: the scapegoat pays for it, or nobody goes.
function Game:voteTie()
    local deaths = {}
    self:_log{ kind = "tie" }
    if self:scapegoatAlive() then
        local s = self:holder("scapegoat")
        self:_kill(s, "scapegoat", deaths)
        self:_checkEnd()
        return { kind = "scapegoat", deaths = deaths, who = s }
    end
    return { kind = "none", deaths = deaths }
end

-- ---------------------------------------------------------------------------
-- Win check
-- ---------------------------------------------------------------------------

-- "village", "wolves", "lovers", "white", "piper", "nobody" or nil (game goes on).
function Game:checkWin()
    local alive, village, wolves, white, piper, uncharmed = 0, 0, 0, 0, 0, 0
    for i, p in ipairs(self.players) do
        if p.alive then
            alive = alive + 1
            if p.role == "whitewolf" then white = white + 1
            elseif self:isWolf(i) then wolves = wolves + 1
            elseif p.role == "piper" then piper = piper + 1
            else village = village + 1 end
            if p.role ~= "piper" and not p.charmed then uncharmed = uncharmed + 1 end
        end
    end
    if alive == 0 then return "nobody" end
    if piper == 1 and uncharmed == 0 then return "piper" end
    if alive == 1 and white == 1 then return "white" end
    if alive == 2 and self.lovers then
        local a, b = self.lovers[1], self.lovers[2]
        if self.players[a].alive and self.players[b].alive and self:isWolf(a) ~= self:isWolf(b) then
            return "lovers"
        end
    end
    if wolves + white == 0 and piper == 0 then return "village" end
    if village == 0 and white == 0 and piper == 0 then return "wolves" end
    return nil
end

-- Ends the game once a side has won, but not while a hunter still has his
-- shot to fire (it can change who wins).
function Game:_checkEnd()
    if #self.pending_hunters > 0 then return end
    local w = self:checkWin()
    if w then
        self.winner = w
        self.phase  = "over"
        self:_log{ kind = "win", winner = w }
    end
end

function Game:isOver()
    return self.phase == "over"
end

-- Does player i share the win?
function Game:isWinner(i)
    local w, p = self.winner, self.players[i]
    if w == "village" then return Game.ROLES[p.role].team == "village" and not self:isWolf(i) end
    if w == "wolves"  then return self:isWolf(i) and p.role ~= "whitewolf" end
    if w == "white"   then return p.role == "whitewolf" end
    if w == "piper"   then return p.role == "piper" end
    if w == "lovers"  then return self:isLover(i) end
    return false
end

return Game
