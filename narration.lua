-- Narration line picker: which variant of a narration / announcement line to
-- read next. Pure Lua (no UI), so the specs can drive it headless.
--
-- Within a game, a line is not read twice while another one is left: the
-- theme's own lines first, then — once they have all been read — the
-- classic village's lines for the same step, and only then a new cycle.
-- Across games, an optional SeenHistory (one per theme + language) makes
-- the next game start with the lines the players have not heard yet.

local Narration = {}

-- Lines as { id, text } items; `src` tells the theme's lines ("p") from the
-- classic fallback ("c") so both can share one history.
local function items(src, key, list)
    local out = {}
    for i, text in ipairs(list or {}) do
        out[#out + 1] = { id = src .. ":" .. key .. ":" .. i, text = text }
    end
    return out
end

local function unused(pool, used)
    local out = {}
    for _i, it in ipairs(pool) do
        if not used[it.id] then out[#out + 1] = it end
    end
    return out
end

-- state:    table saved with the game (one entry per deck key)
-- deck_key: key of this step's deck in `state` (theme-qualified)
-- key:      the step's key in the content ("wolves", "sleep_fox", "grief"…)
-- list:     the theme's lines; fallback: the classic lines (nil when the same)
-- seen:     SeenHistory or nil; rng: function(n) -> 1..n
function Narration.pick(state, deck_key, key, list, fallback, seen, rng)
    if type(list) ~= "table" then return list end
    rng = rng or math.random
    if fallback == list or type(fallback) ~= "table" then fallback = nil end
    if #list == 0 and not fallback then return "" end
    local d = state[deck_key]
    if type(d) ~= "table" or type(d.used) ~= "table" then
        d = { used = {} }          -- also drops the older { order, pos } decks
        state[deck_key] = d
    end
    local own = items("p", key, list)
    local cands = unused(own, d.used)
    if #cands == 0 and fallback then
        cands = unused(items("c", key, fallback), d.used)
    end
    if #cands == 0 then
        d.used = {}
        cands = #own > 0 and own or items("c", key, fallback)
    end
    local item
    if seen then
        item = seen:pick(cands, rng)
    else
        item = cands[rng(#cands)]
    end
    d.used[item.id] = true
    return item.text
end

return Narration
