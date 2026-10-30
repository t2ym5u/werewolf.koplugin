local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Blitbuffer      = require("ffi/blitbuffer")
local ButtonTable     = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox      = require("ui/widget/confirmbox")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InputDialog     = require("ui/widget/inputdialog")
local LineWidget      = require("ui/widget/linewidget")
local RenderText      = require("ui/rendertext")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextViewer      = require("ui/widget/textviewer")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local MenuHelper = require("menu_helper")
local ScreenBase = require("screen_base")

local Game = lrequire("game")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- Text sizing helpers
--
-- Font:getFace() scales its size by the screen DPI, so a size worked out from
-- pixel dimensions is divided back first (see taboo).
-- ---------------------------------------------------------------------------

local DPI_SCALE = DeviceScreen:scaleBySize(1000) / 1000

local function pxFace(px)
    return Font:getFace("cfont", math.max(8, math.floor(px / DPI_SCALE)))
end

-- One line of text at up to `px` pixels, shrunk until it fits `max_w`.
local function fitLine(text, px, max_w, bold)
    local face = pxFace(px)
    while px > 12 do
        local m = RenderText:sizeUtf8Text(0, max_w * 10, face, text, true, bold)
        if m.x <= max_w then break end
        px   = math.floor(px * 0.9)
        face = pxFace(px)
    end
    return TextWidget:new{ text = text, face = face, max_width = max_w, bold = bold }
end

-- A centred paragraph at up to `px` pixels, shrunk until it fits w × h.
local function fitBox(text, px, w, h, align)
    local box
    while true do
        box = TextBoxWidget:new{
            text = text, face = pxFace(px), width = w, alignment = align or "center",
        }
        if box:getSize().h <= h or px <= 14 then break end
        box:free()
        px = math.floor(px * 0.9)
    end
    return box
end


local DEFAULT_PLAYERS = 8
local DEBATE_CHOICES  = { 0, 60, 120, 180, 300 }
local THEMES          = { "classic", "famous", "medieval", "space", "pirate" }

-- Views whose content is secret: leaving them forces a full refresh so the
-- e-ink ghost of a role card cannot be read by the next person.
local PRIVATE = { card = true, act = true, seer_result = true, fox_result = true, thief_result = true }

local GAME_RULES_EN = _([[
Werewolf — Rules

A village of 6 to 18 players hides a few werewolves. Every night the werewolves devour a villager; every day the village debates and votes to drive out a suspect. The village wins when every werewolf is gone; the werewolves win when nobody else is left. Sit in the order of the player list: some roles care about who sits next to whom.

Setup
• Players: type everybody's name (the list is remembered), in seating order.
• Roles: a composition is suggested for the number of players; adjust it with − and +. Plain villagers fill the remaining seats.

Distribution
Pass the reader around. Each player, alone, taps "Show my role", reads the card, then taps "Hide my role" and passes the reader on.

Night
Everybody closes their eyes. Whoever holds the reader (ideally a narrator who does not play, otherwise each player in turn, eyes closed except when called) reads the text aloud. The role that is called opens their eyes, takes the reader, makes their choice in secret, taps it, then puts the reader back and closes their eyes. A role that is dead is still called, so nobody can tell: just wait a moment and tap Done.

Day
The reader announces who died during the night. If the hunter dies, he shoots someone. With the Mayor option, the village first elects a mayor whose vote counts double; a dying mayor names a successor. The village debates (with an optional timer), votes by show of hands, and taps the player eliminated, "No elimination", or "Tie vote" when the scapegoat is in play.

The werewolves
• Werewolf: devours a villager each night, with the pack.
• Big bad wolf: devours a second victim each night, as long as no werewolf has died.
• Accursed wolf-father: once per game, may infect the pack's victim instead: that player secretly becomes a werewolf (and keeps their power).
• White werewolf: wakes with the pack, may devour a werewolf every other night, wins only if he is the last one alive.

The village
• Seer: sees one player's role each night.
• Witch: one healing potion (saves the werewolves' victim) and one death potion, each usable once.
• Hunter: shoots someone when he dies.
• Cupid: binds two lovers on the first night. If one dies, the other dies of grief. A werewolf–villager couple wins if they are the last two alive.
• Guard: protects one player each night, never the same twice in a row.
• Little girl: may peek while the werewolves are awake.
• Elder: survives the first werewolf attack. If the village kills him, the seer, witch, guard, hunter, fox, raven, bear tamer and knight lose their powers.
• Village idiot: if voted out, he is spared but can no longer vote.
• Fox: each night, points at a player: learns whether a werewolf is among that player and their two neighbours. If not, the fox loses the power.
• Raven: each night, marks a player, who starts the next vote with 2 votes against them.
• Bear tamer: each morning, the bear growls if a werewolf sits next to its tamer.
• Knight with the rusty sword: if the werewolves kill him, the first werewolf to his left (next in the list) dies of tetanus the following night.
• Scapegoat: if the vote is a tie, the scapegoat is eliminated.
• Two sisters: wake up together every other night and may silently agree on who to trust.
• Wild child: picks a role model on the first night. If the model dies, the wild child becomes a werewolf.
• Thief: two extra cards are left over. On the first night the thief may swap their card for one of them (must take one if both are werewolves), or keep none and play as a plain villager.

Alone
• Pied piper: charms two players each night; the charmed wake up together to see each other. The piper wins alone when every other living player is charmed.

Menu
• Theme: the narration and the announcements change with the setting: classic village, famous village (every player also gets a famous alias, used in the announcements), medieval, space station, pirate ship.
• Mayor: elect a mayor on the first day.
• Reveal roles on death: whether the announcements say who the dead were.
• Debate timer: off, or 1 to 5 minutes.
• The game is saved after every step: you can close KOReader and resume. The game log (everything that happened, night by night) is shown at the end.
]])

local GAME_RULES_FR = [[
Loup-garou — Règles

Un village de 6 à 18 joueurs cache quelques loups-garous. Chaque nuit, les loups-garous dévorent un villageois ; chaque jour, le village débat et vote pour chasser un suspect. Le village gagne quand tous les loups-garous sont éliminés ; les loups-garous gagnent quand il ne reste plus qu'eux. Asseyez-vous dans l'ordre de la liste des joueurs : certains rôles dépendent des voisins de table.

Préparation
• Joueurs : saisissez le nom de chacun (la liste est mémorisée), dans l'ordre de la table.
• Rôles : une composition est proposée selon le nombre de joueurs ; ajustez-la avec − et +. Les simples villageois complètent les places restantes.

Distribution
Faites passer la liseuse. Chaque joueur, seul, touche « Voir mon rôle », lit sa carte, puis touche « Cacher mon rôle » et passe la liseuse au suivant.

La nuit
Tout le monde ferme les yeux. Celui qui tient la liseuse (idéalement un meneur qui ne joue pas, sinon chacun son tour, les yeux fermés sauf quand on l'appelle) lit le texte à voix haute. Le rôle appelé ouvre les yeux, prend la liseuse, fait son choix en secret, le touche, puis repose la liseuse et ferme les yeux. Un rôle mort est quand même appelé, pour que personne ne le devine : attendez un instant et touchez Terminé.

Le jour
La liseuse annonce les morts de la nuit. Si le chasseur meurt, il tire sur quelqu'un. Avec l'option Maire, le village élit d'abord un maire dont la voix compte double ; un maire mourant désigne son successeur. Le village débat (chrono facultatif), vote à main levée et touche le joueur éliminé, « Pas d'élimination », ou « Égalité » quand le bouc émissaire est en jeu.

Les loups-garous
• Loup-garou : dévore un villageois chaque nuit, avec la meute.
• Grand méchant loup : dévore une deuxième victime chaque nuit, tant qu'aucun loup-garou n'est mort.
• Infect père des loups : une fois par partie, peut infecter la victime de la meute au lieu de la dévorer : ce joueur devient secrètement loup-garou (et garde son pouvoir).
• Loup-garou blanc : se réveille avec la meute, peut dévorer un loup-garou une nuit sur deux, et ne gagne que s'il reste le dernier en vie.

Le village
• Voyante : découvre le rôle d'un joueur chaque nuit.
• Sorcière : une potion de vie (sauve la victime des loups) et une potion de mort, chacune utilisable une fois.
• Chasseur : tire sur quelqu'un quand il meurt.
• Cupidon : unit deux amoureux la première nuit. Si l'un meurt, l'autre meurt de chagrin. Un couple loup-villageois gagne s'il reste seul en vie.
• Salvateur : protège un joueur chaque nuit, jamais le même deux fois de suite.
• Petite fille : peut espionner pendant que les loups-garous sont réveillés.
• Ancien : survit à la première attaque des loups. Si le village le tue, la voyante, la sorcière, le salvateur, le chasseur, le renard, le corbeau, le montreur d'ours et le chevalier perdent leurs pouvoirs.
• Idiot du village : s'il est éliminé par le vote, il est épargné mais ne vote plus.
• Renard : chaque nuit, désigne un joueur et apprend s'il y a un loup-garou parmi ce joueur et ses deux voisins. Sinon, il perd son flair.
• Corbeau : chaque nuit, désigne un joueur qui commencera le vote suivant avec 2 voix contre lui.
• Montreur d'ours : chaque matin, l'ours grogne si un loup-garou est assis à côté de son montreur.
• Chevalier à l'épée rouillée : si les loups-garous le tuent, le premier loup-garou à sa gauche (le suivant dans la liste) meurt du tétanos la nuit suivante.
• Bouc émissaire : en cas d'égalité au vote, c'est lui qui est éliminé.
• Deux sœurs : se réveillent ensemble une nuit sur deux et peuvent se concerter en silence.
• Enfant sauvage : choisit un modèle la première nuit. Si son modèle meurt, il devient loup-garou.
• Voleur : deux cartes restent en trop. La première nuit, le voleur peut échanger sa carte contre l'une d'elles (obligatoirement si ce sont deux loups-garous), ou n'en prendre aucune et jouer simple villageois.

Seul contre tous
• Joueur de flûte : charme deux joueurs chaque nuit ; les charmés se réveillent ensemble pour se reconnaître. Il gagne seul quand tous les autres joueurs vivants sont charmés.

Menu
• Thème : la narration et les annonces changent selon le décor : village classique, village célèbre (chaque joueur reçoit aussi un alias célèbre, repris dans les annonces), médiéval, station spatiale, bateau pirate.
• Maire : élire un maire le premier jour.
• Rôles révélés à la mort : les annonces disent ou non qui étaient les morts.
• Chrono du débat : désactivé, ou de 1 à 5 minutes.
• La partie est sauvegardée à chaque étape : vous pouvez fermer KOReader et reprendre. Le journal de la partie (tout ce qui s'est passé, nuit par nuit) s'affiche à la fin.
]]

-- ---------------------------------------------------------------------------
-- WerewolfScreen
-- ---------------------------------------------------------------------------

local WerewolfScreen = ScreenBase:extend{}

function WerewolfScreen:init()
    local p = self.plugin
    self.lang    = p:getSetting("lang", _.lang() == "fr" and "fr" or "en")
    self.names   = p:getSetting("names")
    self.theme   = p:getSetting("theme", "classic")
    self.reveal  = p:getSetting("reveal", true)
    self.debate  = p:getSetting("debate", 0)
    self.mayor   = p:getSetting("mayor", false)
    self.comp_auto = p:getSetting("comp_auto", true)
    self.comp    = p:getSetting("comp")
    if not self.names or #self.names < Game.MIN_PLAYERS then
        self.names = self:_defaultNames(DEFAULT_PLAYERS)
    end
    self:_fixComp()

    local state = p:loadState()
    if type(state) == "table" and state.game then
        self.game = Game.load(state.game)
        self.ui   = state.ui
    end
    if self.game and type(self.ui) == "table" then
        self:_restoreView()
    else
        self.game = nil
        self.ui   = { view = "setup" }
    end
    ScreenBase.init(self)
end

function WerewolfScreen:_defaultNames(n)
    local t = {}
    for i = 1, n do t[i] = T(_("Player %1"), i) end
    return t
end

-- Keep the composition playable for the current number of players; the
-- suggestion follows the player count until the roles are edited by hand.
function WerewolfScreen:_fixComp()
    local n = #self.names
    if self.comp_auto or type(self.comp) ~= "table" or not Game.isValid(self.comp, n) then
        self.comp = Game.suggest(n)
        self.comp_auto = true
    end
end

-- A saved game never resumes on a secret: a role card goes back to its
-- hand-over screen, a night step to its (public) narration, a step result
-- (already recorded) to the next narration.
function WerewolfScreen:_restoreView()
    local v = self.ui.view
    if v == "card" then
        self.ui = { view = "handover" }
    elseif v == "act" then
        self.ui = { view = "narr", text = self.ui.narr_text or "", title = self.ui.title }
    elseif v == "seer_result" or v == "fox_result" or v == "thief_result" then
        self:_afterAct(self.ui.step or "seer", true)
    elseif v == "debate" then
        self.ui.remaining = self.debate
    end
    if self.game:isOver() then
        self.ui = { view = "over", text = self.ui.view == "over" and self.ui.text or self:_winText() }
    end
end

function WerewolfScreen:serializeState()
    if not self.game then return nil end
    return { game = self.game:serialize(), ui = self.ui }
end

function WerewolfScreen:_save()
    self.plugin:saveState(self:serializeState())
end

-- ---------------------------------------------------------------------------
-- Content (narration, role cards…), in its own language, with the theme's
-- narration pack laid over the classic one.
-- ---------------------------------------------------------------------------

local function loadLua(path)
    local chunk = loadfile(path)
    if not chunk then return nil end
    local ok, t = pcall(chunk)
    return ok and type(t) == "table" and t or nil
end

local function overlay(base, top)
    local out = {}
    for k, v in pairs(base or {}) do out[k] = v end
    for k, v in pairs(top or {}) do out[k] = v end
    return out
end

function WerewolfScreen:_c()
    local key = self.lang .. ":" .. self.theme
    if not self._content or self._content_key ~= key then
        local base = assert(loadLua(_dir .. "content_" .. self.lang .. ".lua"))
        local pack = self.theme ~= "classic"
            and loadLua(_dir .. "pack_" .. self.theme .. "_" .. self.lang .. ".lua") or {}
        local c = overlay(base, pack)
        c.narr = overlay(base.narr, pack.narr)
        c.narr.sleep = overlay(base.narr.sleep, pack.narr and pack.narr.sleep)
        c.win = overlay(base.win, pack.win)
        -- Those always come from the base file, whatever the pack says.
        for _i, k in ipairs({ "roles", "teams", "log", "causes", "win_title", "titles", "marks" }) do
            c[k] = base[k]
        end
        self._content, self._content_key = c, key
    end
    return self._content
end

-- One line from a list, dealt from a shuffled deck kept in the saved game so
-- the same line does not come back until the others have been used.
function WerewolfScreen:_pick(key, list)
    if type(list) ~= "table" then return list end
    if #list == 0 then return "" end
    local g = self.game
    if not g then return list[math.random(#list)] end
    key = self.theme .. ":" .. key
    g.decks = g.decks or {}
    local d = g.decks[key]
    if not d or d.pos > #d.order or #d.order ~= #list then
        local order = {}
        for i = 1, #list do order[i] = i end
        Game.shuffle(order, math.random)
        d = { order = order, pos = 1 }
        g.decks[key] = d
    end
    local idx = d.order[d.pos]
    d.pos = d.pos + 1
    return list[((idx - 1) % #list) + 1]
end

function WerewolfScreen:_sleepLine(step)
    return self:_pick("sleep_" .. step, self:_c().narr.sleep[step])
end

-- Name used in announcements: with the famous alias when that theme is on.
function WerewolfScreen:_pname(i)
    local p = self.game.players[i]
    if self.theme == "famous" and p.alias then
        return T(self:_c().alias_fmt, p.name, p.alias)
    end
    return p.name
end

function WerewolfScreen:_names(list)
    local out = {}
    for k, i in ipairs(list) do out[k] = self.game.players[i].name end
    return table.concat(out, ", ")
end

function WerewolfScreen:_aliases()
    local list = {}
    for i, a in ipairs(loadLua(_dir .. "aliases_" .. self.lang .. ".lua") or {}) do list[i] = a end
    return Game.shuffle(list, math.random)
end

-- ---------------------------------------------------------------------------
-- View transitions
-- ---------------------------------------------------------------------------

function WerewolfScreen:_go(ui)
    local was_private = self.ui and PRIVATE[self.ui.view]
    self:_stopTimer()
    self.ui = ui
    if self.game then self:_save() end
    self:buildLayout()
    local mode = was_private and "full" or "ui"
    UIManager:setDirty(self, function() return mode, self.dimen end)
    if ui.view == "debate" then self:_startTimer() end
end

function WerewolfScreen:onStartGame()
    local n = #self.names
    if not Game.isValid(self.comp, n) then
        self:showMessage(_("This composition cannot be played. Adjust the roles."))
        return
    end
    self.game = Game.new{ names = self.names, comp = self.comp, aliases = self:_aliases(),
                          mayor = self.mayor }
    self:_go({ view = "handover" })
end

-- Night narration for the current step; prev_step's "goes back to sleep"
-- line comes first, the nightfall line opens the night.
function WerewolfScreen:_goNarr(prev_step)
    local g, c = self.game, self:_c()
    local step = g:currentStep()
    local parts = {}
    if prev_step then parts[#parts + 1] = self:_sleepLine(prev_step) end
    if g.ns.idx == 1 then parts[#parts + 1] = self:_pick("night_start", c.narr.night_start) end
    parts[#parts + 1] = self:_pick(step, c.narr[step])
    if step == "wolves" and g:has("littlegirl") then
        parts[#parts + 1] = self:_pick("littlegirl", c.narr.littlegirl)
    end
    self:_go({ view = "narr", text = table.concat(parts, "\n\n"), title = T(_("Night %1"), g.night) })
end

function WerewolfScreen:_startNight()
    self.game:startNight()
    self:_goNarr(nil)
end

-- After a night step: the next narration, or dawn. `quiet` builds the view
-- without showing it (used while restoring a save).
function WerewolfScreen:_afterAct(step, quiet)
    local g = self.game
    if quiet then
        self.ui = { view = "narr", title = T(_("Night %1"), g.night),
                    text = self:_sleepLine(step), after_sleep = true }
        return
    end
    if g:nightDone() then
        self:_goDawn(step)
    else
        self:_goNarr(step)
    end
end

-- Lines for a list of deaths: a flavour line each, the role when roles are
-- revealed, and the elder's curse when it just struck.
function WerewolfScreen:_deathLines(deaths, kind, powers_before)
    local c, g, out = self:_c(), self.game, {}
    for k, d in ipairs(deaths) do
        local name = self:_pname(d.i)
        if d.cause == "grief" then
            out[#out + 1] = T(self:_pick("grief", c.grief), name)
        elseif d.cause == "tetanus" then
            local knight = g:holder("knight")
            out[#out + 1] = T(self:_pick("tetanus", c.tetanus), name, knight and self:_pname(knight) or "")
        elseif d.cause == "scapegoat" then
            out[#out + 1] = T(self:_pick("scapegoat", c.scapegoat), name)
        elseif d.cause == "shot" and k == 1 then
            -- the shot line itself is written by the caller
        elseif kind == "vote" and k == 1 then
            out[#out + 1] = T(self:_pick("vote_deaths", c.vote_deaths), name)
        else
            out[#out + 1] = T(self:_pick("night_deaths", c.night_deaths), name)
        end
        if self.reveal then
            out[#out + 1] = T(c.reveal, name, c.roles[g.players[d.i].role].a)
        end
    end
    if g.powers_lost and not powers_before then
        out[#out + 1] = self:_pick("powers_lost", c.powers_lost)
    end
    return out
end

function WerewolfScreen:_goDawn(prev_step)
    local g, c = self.game, self:_c()
    local powers = g.powers_lost
    local deaths = g:resolveNight()
    local parts = {}
    if prev_step then parts[#parts + 1] = self:_sleepLine(prev_step) end
    parts[#parts + 1] = self:_pick("dawn", c.narr.dawn)
    if #deaths == 0 then
        parts[#parts + 1] = self:_pick("no_deaths", c.no_deaths)
    else
        for _i, l in ipairs(self:_deathLines(deaths, "night", powers)) do parts[#parts + 1] = l end
    end
    if g.bear == "growl" then
        parts[#parts + 1] = self:_pick("bear_growl", c.bear_growl)
    elseif g.bear == "quiet" then
        parts[#parts + 1] = self:_pick("bear_quiet", c.bear_quiet)
    end
    if g.raven_mark and g:alive(g.raven_mark) then
        parts[#parts + 1] = T(self:_pick("raven", c.raven), self:_pname(g.raven_mark))
    end
    self:_go({ view = "news", title = T(_("Day %1"), g.day), text = table.concat(parts, "\n\n"),
               after = "debate" })
end

-- What follows an announcement: a hunter's last shot, the end, the mayor's
-- succession or election, the debate, or the next night.
function WerewolfScreen:_continue(after)
    local g = self.game
    local title = g.phase == "night" and T(_("Night %1"), g.night) or T(_("Day %1"), g.day)
    if g:pendingHunter() then
        self:_go({ view = "hunter", after = after, sel = {}, title = title })
    elseif g:isOver() then
        self:_go({ view = "over", text = self:_winText() })
    elseif g:pendingSuccession() then
        self:_go({ view = "successor", after = after, sel = {}, title = title })
    elseif after == "debate" and g:needsElection() then
        self:_go({ view = "election", sel = {}, title = title,
                   text = self:_pick("election", self:_c().narr.election) })
    elseif after == "debate" then
        self:_go({ view = "debate", text = self:_pick("debate", self:_c().narr.debate),
                   remaining = self.debate })
    else
        self:_startNight()
    end
end

function WerewolfScreen:_winText()
    local g, c = self.game, self:_c()
    local w = g.winner or "nobody"
    local line = self:_pick("win_" .. w, c.win[w])
    if w == "lovers" and g.lovers then
        line = T(line, self:_pname(g.lovers[1]), self:_pname(g.lovers[2]))
    elseif w == "white" then
        line = T(line, self:_pname(g:holder("whitewolf")))
    elseif w == "piper" then
        line = T(line, self:_pname(g:holder("piper")))
    end
    return line
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function WerewolfScreen:_actConfirm(choice)
    local step = self.ui.step
    local result = self.game:act(choice)
    if step == "seer" and choice then
        self:_go({ view = "seer_result", step = step, target = choice, role = result })
    elseif step == "fox" and result then
        self:_go({ view = "fox_result", step = step, found = result.found, group = result.group })
    elseif step == "thief" and result then
        self:_go({ view = "thief_result", step = step, role = result })
    else
        self:_afterAct(step)
    end
end

function WerewolfScreen:_onShoot(target)
    local g, c = self.game, self:_c()
    local hunter = g:pendingHunter()
    local powers = g.powers_lost
    local deaths = g:hunterShoot(target)
    local parts = {}
    if target then
        parts[#parts + 1] = T(self:_pick("shot", c.shot), self:_pname(hunter), self:_pname(target))
    else
        parts[#parts + 1] = T(self:_pick("hunter_spares", c.hunter_spares), self:_pname(hunter))
    end
    for _i, l in ipairs(self:_deathLines(deaths, "shot", powers)) do parts[#parts + 1] = l end
    self:_go({ view = "news", title = self.ui.title, text = table.concat(parts, "\n\n"),
               after = self.ui.after })
end

function WerewolfScreen:_onElect(target)
    local g, c = self.game, self:_c()
    g:elect(target)
    if not target then self:_continue("debate"); return end
    self:_go({ view = "news", title = self.ui.title, after = "debate",
               text = T(self:_pick("mayor_elected", c.mayor_elected), self:_pname(target)) })
end

function WerewolfScreen:_onSuccessor(target)
    local g, c = self.game, self:_c()
    local old = g:pendingSuccession()
    g:passSash(target)
    if not target then self:_continue(self.ui.after); return end
    self:_go({ view = "news", title = self.ui.title, after = self.ui.after,
               text = T(self:_pick("mayor_successor", c.mayor_successor), self:_pname(old), self:_pname(target)) })
end

function WerewolfScreen:_onVote(target, tie)
    local g, c = self.game, self:_c()
    local powers = g.powers_lost
    local res = tie and g:voteTie() or g:vote(target)
    local parts = {}
    if res.kind == "none" then
        parts[#parts + 1] = self:_pick("no_vote", c.no_vote)
    elseif res.kind == "idiot" then
        parts[#parts + 1] = T(self:_pick("idiot", c.idiot), self:_pname(target))
    else
        for _i, l in ipairs(self:_deathLines(res.deaths, "vote", powers)) do parts[#parts + 1] = l end
    end
    self:_go({ view = "news", title = T(_("Day %1"), g.day), text = table.concat(parts, "\n\n"),
               after = "night" })
end

-- ---------------------------------------------------------------------------
-- Debate timer: only the timer line is redrawn, once a second.
-- ---------------------------------------------------------------------------

function WerewolfScreen:_timerText()
    local r = self.ui.remaining or 0
    if r <= 0 then return _("Time's up!") end
    return string.format("%d:%02d", math.floor(r / 60), r % 60)
end

function WerewolfScreen:_startTimer()
    if (self.ui.remaining or 0) <= 0 then return end
    self._tick_gen = (self._tick_gen or 0) + 1
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function WerewolfScreen:_stopTimer()
    self._tick_gen = (self._tick_gen or 0) + 1
end

function WerewolfScreen:_onTick(gen)
    if gen ~= self._tick_gen or not self.ui or self.ui.view ~= "debate" then return end
    self.ui.remaining = math.max(0, (self.ui.remaining or 0) - 1)
    if self.timer_widget then
        self.timer_widget:setText(self:_timerText())
        local box = self.timer_box
        UIManager:setDirty(self, function() return "fast", box and box.dimen or self.dimen end)
    end
    if self.ui.remaining > 0 then
        UIManager:scheduleIn(1, function() self:_onTick(gen) end)
    end
end

-- ---------------------------------------------------------------------------
-- Setup: players and roles
-- ---------------------------------------------------------------------------

function WerewolfScreen:_savePlayers()
    self.plugin:saveSetting("names", self.names)
    self:_fixComp()
    self:_saveComp()
end

function WerewolfScreen:_saveComp()
    self.plugin:saveSetting("comp", self.comp)
    self.plugin:saveSetting("comp_auto", self.comp_auto)
end

function WerewolfScreen:_refresh()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function WerewolfScreen:_renamePlayer(i)
    local dialog
    dialog = InputDialog:new{
        title = T(_("Player %1"), i),
        input = self.names[i],
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Remove"), enabled = #self.names > Game.MIN_PLAYERS, callback = function()
                UIManager:close(dialog)
                table.remove(self.names, i)
                self:_savePlayers()
                self:_refresh()
            end },
            { text = _("OK"), is_enter_default = true, callback = function()
                local s = trim(dialog:getInputText() or "")
                UIManager:close(dialog)
                self.names[i] = s ~= "" and s or T(_("Player %1"), i)
                self:_savePlayers()
                self:_refresh()
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function WerewolfScreen:_addPlayer()
    if #self.names >= Game.MAX_PLAYERS then return end
    self.names[#self.names + 1] = T(_("Player %1"), #self.names + 1)
    self:_savePlayers()
    self:_refresh()
    self:_renamePlayer(#self.names)
end

-- All names at once, one per line.
function WerewolfScreen:_typeAllNames()
    local dialog
    dialog = InputDialog:new{
        title = _("Players (one per line)"),
        input = table.concat(self.names, "\n"),
        allow_newline = true,
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("OK"), callback = function()
                local names = {}
                for line in ((dialog:getInputText() or "") .. "\n"):gmatch("(.-)\n") do
                    line = trim(line)
                    if line ~= "" and #names < Game.MAX_PLAYERS then names[#names + 1] = line end
                end
                UIManager:close(dialog)
                for i = #names + 1, Game.MIN_PLAYERS do names[i] = T(_("Player %1"), i) end
                self.names = names
                self:_savePlayers()
                self:_refresh()
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function WerewolfScreen:_adjustRole(role, delta)
    local new = Game.adjust(self.comp, #self.names, role, delta)
    if not new then return end
    self.comp = new
    self.comp_auto = false
    self:_saveComp()
    self:_refresh()
end

-- "2 × Werewolf · Seer · Witch · 3 × Villager"
function WerewolfScreen:_compText()
    local c, n, parts = self:_c(), #self.names, {}
    for _i, role in ipairs(Game.ROLE_ORDER) do
        local k = role == "villager" and Game.villagers(self.comp, n) or (self.comp[role] or 0)
        if k > 0 then
            parts[#parts + 1] = k > 1 and (k .. " × " .. c.roles[role].name) or c.roles[role].name
        end
    end
    return table.concat(parts, " · ")
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

function WerewolfScreen:onNewGame()
    local function reset()
        self.game = nil
        self.plugin:saveState(nil)
        self:_go({ view = "setup" })
    end
    if self.game and not self.game:isOver() then
        UIManager:show(ConfirmBox:new{
            text = _("Abandon the current game?"),
            ok_text = _("New game"),
            ok_callback = reset,
        })
    else
        reset()
    end
end

function WerewolfScreen:openLangMenu()
    MenuHelper.openPickerMenu{
        title = _("Language"),
        items = { { id = "fr", text = "Français" }, { id = "en", text = "English" } },
        current_id = self.lang,
        parent = self,
        on_select = function(lang)
            self.lang = lang
            self.plugin:saveSetting("lang", lang)
            self:_refresh()
        end,
    }
end

function WerewolfScreen:_themeLabel(t)
    if t == "famous" then return _("Famous village") end
    if t == "medieval" then return _("Medieval") end
    if t == "space" then return _("Space station") end
    if t == "pirate" then return _("Pirate ship") end
    return _("Classic village")
end

function WerewolfScreen:openThemeMenu()
    local items = {}
    for _i, t in ipairs(THEMES) do items[#items + 1] = { id = t, text = self:_themeLabel(t) } end
    MenuHelper.openPickerMenu{
        title = _("Theme"),
        items = items,
        current_id = self.theme,
        parent = self,
        on_select = function(t)
            self.theme = t
            self.plugin:saveSetting("theme", t)
            self:_refresh()
        end,
    }
end

function WerewolfScreen:_debateLabel(secs)
    if secs <= 0 then return _("No timer") end
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

function WerewolfScreen:openDebateMenu()
    local items = {}
    for _i, s in ipairs(DEBATE_CHOICES) do items[#items + 1] = { id = s, text = self:_debateLabel(s) } end
    MenuHelper.openPickerMenu{
        title = _("Debate timer"),
        items = items,
        current_id = self.debate,
        parent = self,
        on_select = function(s)
            self.debate = s
            self.plugin:saveSetting("debate", s)
        end,
    }
end

function WerewolfScreen:_logText()
    local g, c = self.game, self:_c()
    local L, out = c.log, {}
    local header
    local function n(i) return i and self:_pname(i) or "?" end
    for _i, ev in ipairs(g.log) do
        local line
        local k = ev.kind
        if k == "saved" then
            if ev.by ~= "witch" then line = T(L["saved_" .. ev.by], n(ev.a)) end
        elseif k == "death" then
            line = T(L.death, n(ev.a), c.roles[ev.role].a, c.causes[ev.cause] or "")
        elseif k == "seer" then line = T(L.seer, n(ev.a), c.roles[ev.role].name)
        elseif k == "thief" then line = T(L.thief, n(ev.a), c.roles[ev.role].name)
        elseif k == "win" then line = "\n" .. c.win_title[ev.winner]
        elseif L[k] then line = T(L[k], n(ev.a), n(ev.b))
        end
        if line then
            local h = ev.phase == "night" and T(L.night, ev.night) or T(L.day, ev.day)
            if k ~= "win" and h ~= header then
                out[#out + 1] = (#out > 0 and "\n" or "") .. h
                header = h
            end
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

function WerewolfScreen:showLog()
    if not self.game then return end
    UIManager:show(TextViewer:new{
        title  = _("Game log"),
        text   = self:_logText(),
        width  = math.floor(DeviceScreen:getWidth() * 0.9),
        height = math.floor(DeviceScreen:getHeight() * 0.9),
    })
end

local function yesNo(v) return v and _("Yes") or _("No") end

function WerewolfScreen:_titleBar()
    return self:buildTitleBar(_("Werewolf"), function()
        local items = {
            { text = _("New game"), callback = function() self:onNewGame() end },
            { text = T(_("Language: %1"), self.lang:upper()), callback = function() self:openLangMenu() end },
        }
        if not self.game then
            items[#items + 1] = { text = T(_("Players: %1"), #self.names),
                                  callback = function() self:_go({ view = "players" }) end }
        end
        items[#items + 1] = { text = T(_("Theme: %1"), self:_themeLabel(self.theme)),
                              callback = function() self:openThemeMenu() end }
        items[#items + 1] = { text = T(_("Mayor: %1"), yesNo(self.mayor)), callback = function()
                                  self.mayor = not self.mayor
                                  self.plugin:saveSetting("mayor", self.mayor)
                              end }
        items[#items + 1] = { text = T(_("Reveal roles on death: %1"), yesNo(self.reveal)),
                              callback = function()
                                  self.reveal = not self.reveal
                                  self.plugin:saveSetting("reveal", self.reveal)
                              end }
        items[#items + 1] = { text = T(_("Debate timer: %1"), self:_debateLabel(self.debate)),
                              callback = function() self:openDebateMenu() end }
        if self.game and self.game:isOver() then
            items[#items + 1] = { text = _("Game log"), callback = function() self:showLog() end }
        end
        items[#items + 1] = self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR)
        return items
    end)
end

-- ---------------------------------------------------------------------------
-- Round over
-- ---------------------------------------------------------------------------

function WerewolfScreen:isRoundOver()
    return self.game ~= nil and self.game:isOver() and self.ui and self.ui.view == "over"
end

function WerewolfScreen:getRoundOverButtons()
    return {
        { text = _("Game log"), callback = function() self:showLog() end },
        { text = _("New game"), callback = function() self:onNewGame() end },
    }
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

-- Buttons for a set of players (2 or 3 per row). opts: sel (set), on_tap(i).
function WerewolfScreen:_grid(list, opts, width)
    local cols = #list > 8 and 3 or 2
    local rows, row = {}, {}
    for _k, i in ipairs(list) do
        local name = opts.labels and opts.labels[i] or (self.game and self.game.players[i].name or self.names[i])
        local sel = opts.sel and opts.sel[i]
        row[#row + 1] = {
            text = (sel and "✓ " or "") .. name,
            font_bold = sel and true or false,
            font_size = 22,
            callback = function() opts.on_tap(i) end,
        }
        if #row == cols then rows[#rows + 1] = row; row = {} end
    end
    if #row > 0 then
        while #row < cols do row[#row + 1] = { text = "", enabled = false, callback = function() end } end
        rows[#rows + 1] = row
    end
    if #rows == 0 then return nil end
    return ButtonTable:new{ width = width, buttons = rows }
end

local function selected(sel)
    local out = {}
    for i, v in pairs(sel or {}) do if v then out[#out + 1] = i end end
    table.sort(out)
    return out
end

-- Single-choice selection: tapping a player selects them only.
function WerewolfScreen:_selectOne(i)
    self.ui.sel = { [i] = true }
    self:_refresh()
end

-- Two-player selection (cupid, piper): a third tap replaces the last one.
function WerewolfScreen:_selectTwo(i)
    local ui = self.ui
    if ui.sel[i] then
        ui.sel[i] = nil
    else
        local cur = selected(ui.sel)
        if #cur >= 2 then ui.sel[ui.last or cur[1]] = nil end
        ui.sel[i] = true
        ui.last = i
    end
    self:_refresh()
end

function WerewolfScreen:_alivePlayers()
    local out = {}
    for i, p in ipairs(self.game.players) do if p.alive then out[#out + 1] = i end end
    return out
end

-- Pick-one-player screen: grid, optional extra button, Confirm.
function WerewolfScreen:_pickOne(s, list, confirm_text, on_confirm, extra)
    local ui = self.ui
    s.grid = { list = list, sel = ui.sel, on_tap = function(i) self:_selectOne(i) end }
    local t = selected(ui.sel)[1]
    local row = {}
    if extra then row[#row + 1] = extra end
    row[#row + 1] = { text = confirm_text or _("Confirm"), enabled = t ~= nil,
                      callback = function() on_confirm(t) end }
    s.rows = { row }
end

-- Describes the current view: header, text, optional player grid, action rows.
function WerewolfScreen:_spec()
    local ui, g, c = self.ui, self.game, self:_c()
    local v = ui.view
    local s = { rows = {} }

    if v == "setup" then
        local n = #self.names
        s.title = _("Werewolf")
        s.text = T(_("Players (%1): %2"), n, table.concat(self.names, ", "))
            .. "\n\n" .. T(_("Roles: %1"), self:_compText())
            .. "\n\n" .. T(_("Theme: %1"), self:_themeLabel(self.theme))
        if not Game.isValid(self.comp, n) then
            s.text = s.text .. "\n\n⚠ " .. _("This composition cannot be played. Adjust the roles.")
        end
        s.rows = {
            { { text = _("Players"), callback = function() self:_go({ view = "players" }) end },
              { text = _("Roles"),   callback = function() self:_go({ view = "roles", page = 1 }) end } },
            { { text = _("Start game"), enabled = Game.isValid(self.comp, n),
                callback = function() self:onStartGame() end } },
        }
        s.text_px = 0.05

    elseif v == "players" then
        s.title = T(_("Players: %1"), #self.names)
        s.text  = _("Tap a name to rename or remove it. Enter the players in seating order.")
        s.text_px = 0.045
        local list = {}
        for i = 1, #self.names do list[i] = i end
        s.grid = { list = list, labels = self.names, on_tap = function(i) self:_renamePlayer(i) end }
        s.rows = {
            { { text = _("Add player"), enabled = #self.names < Game.MAX_PLAYERS,
                callback = function() self:_addPlayer() end },
              { text = _("Type all names"), callback = function() self:_typeAllNames() end } },
            { { text = _("Done"), callback = function() self:_go({ view = "setup" }) end } },
        }

    elseif v == "roles" then
        local n = #self.names
        s.title = _("Roles")
        s.text  = T(_("Villagers: %1"), Game.villagers(self.comp, n))
            .. (self.comp.thief and ("  ·  " .. _("+2 leftover cards for the thief")) or "")
        s.text_px = 0.045
        s.roles_table = true
        s.rows = {
            { { text = _("Suggested"), callback = function()
                    self.comp_auto = true
                    self:_fixComp()
                    self:_saveComp()
                    self:_refresh()
                end },
              { text = _("Done"), callback = function() self:_go({ view = "setup" }) end } },
        }

    elseif v == "handover" then
        local name = g.players[g.deal_index].name
        s.title = T(_("Role %1/%2"), g.deal_index, g:count())
        s.text  = T(_("Pass the reader to\n%1"), name)
        s.sub   = _("Tap the button when nobody else is looking.")
        s.text_px = 0.09
        s.rows = { { { text = _("Show my role"), callback = function() self:_go({ view = "card" }) end } } }

    elseif v == "card" then
        s.card = g.deal_index
        s.rows = { { { text = _("Hide my role"), callback = function()
            if g:dealNext() then self:_go({ view = "handover" }) else self:_go({ view = "deal_done" }) end
        end } } }

    elseif v == "deal_done" then
        s.title = _("Everyone has a role")
        s.text  = _("Put the reader down where the narrator can reach it.\nWhen everyone is ready, start the night.")
        s.text_px = 0.06
        s.rows = { { { text = _("Night falls"), callback = function() self:_startNight() end } } }

    elseif v == "narr" then
        s.title = ui.title
        s.text  = ui.text
        s.read_aloud = true
        s.text_px = 0.07
        s.rows = { { { text = _("Continue"), callback = function()
            if ui.after_sleep then
                -- restored after a step whose result was already recorded
                if g:nightDone() then self:_goDawn(nil) else self:_goNarr(nil) end
                return
            end
            self:_go({ view = "act", step = g:currentStep(), sel = {}, narr_text = ui.text, title = ui.title })
        end } } }

    elseif v == "act" then
        self:_actSpec(s)

    elseif v == "seer_result" then
        s.title = c.roles.seer.name
        s.text  = T(_("%1 is…"), g.players[ui.target].name)
        s.big   = c.roles[ui.role].name
        s.sub   = c.teams[Game.ROLES[ui.role].team]
        s.text_px = 0.06
        s.rows = { { { text = _("Done"), callback = function() self:_afterAct("seer") end } } }

    elseif v == "fox_result" then
        s.title = c.roles.fox.name
        local names = self:_names(ui.group)
        s.text = ui.found and T(_("Your nose twitches: there is at least one werewolf among\n%1."), names)
            or T(_("No werewolf among\n%1.\nYou lose your sense of smell: no more power."), names)
        s.big = ui.found and _("Yes!") or _("No")
        s.text_px = 0.055
        s.rows = { { { text = _("Done"), callback = function() self:_afterAct("fox") end } } }

    elseif v == "thief_result" then
        local role = c.roles[ui.role]
        s.title = c.roles.thief.name
        s.text  = _("You are now:")
        s.big   = role.name
        s.sub   = c.teams[Game.ROLES[ui.role].team] .. "\n\n" .. role.desc
        s.text_px = 0.055
        s.rows = { { { text = _("Done"), callback = function() self:_afterAct("thief") end } } }

    elseif v == "news" then
        s.title = ui.title
        s.text  = ui.text
        s.read_aloud = true
        s.text_px = 0.06
        s.rows = { { { text = _("Continue"), callback = function() self:_continue(ui.after) end } } }

    elseif v == "hunter" then
        local h = g:pendingHunter()
        s.title = c.roles.hunter.name
        s.text  = T(_("%1, the hunter, is dying!\nChoose who goes down too."), self:_pname(h))
        s.text_px = 0.055
        self:_pickOne(s, self:_alivePlayers(), _("Shoot"), function(t) self:_onShoot(t) end,
            { text = _("Hold fire"), callback = function() self:_onShoot(nil) end })

    elseif v == "successor" then
        s.title = ui.title
        s.text  = T(_("%1 was the mayor.\nWith a last breath, they hand the sash to…"),
            self:_pname(g:pendingSuccession()))
        s.text_px = 0.055
        self:_pickOne(s, self:_alivePlayers(), _("Confirm"), function(t) self:_onSuccessor(t) end,
            { text = _("Nobody"), callback = function() self:_onSuccessor(nil) end })

    elseif v == "election" then
        s.title = ui.title
        s.text  = ui.text .. "\n\n" .. _("Tap the player elected mayor.")
        s.text_px = 0.05
        self:_pickOne(s, self:_alivePlayers(), _("Elect"), function(t) self:_onElect(t) end,
            { text = _("Later"), callback = function() self:_onElect(nil) end })

    elseif v == "debate" then
        s.title = T(_("Day %1"), g.day)
        s.text  = ui.text
        s.read_aloud = true
        s.text_px = 0.065
        s.timer = self.debate > 0
        s.rows = { { { text = _("Vote"), callback = function()
            self:_go({ view = "vote", text = self:_pick("vote", c.narr.vote), sel = {} })
        end } } }

    elseif v == "vote" then
        s.title = T(_("Day %1"), g.day)
        local parts = { ui.text }
        if g.mayor and g:alive(g.mayor) then
            parts[#parts + 1] = T(_("The mayor's vote (%1) counts double."), g.players[g.mayor].name)
        end
        if g.raven_mark and g:alive(g.raven_mark) then
            parts[#parts + 1] = T(_("%1 starts with 2 votes against them (the raven)."),
                g.players[g.raven_mark].name)
        end
        s.text  = table.concat(parts, "\n")
        s.text_px = 0.05
        s.grid  = { list = self:_alivePlayers(), sel = ui.sel, on_tap = function(i) self:_selectOne(i) end }
        local t = selected(ui.sel)[1]
        local first = { { text = _("No elimination"), callback = function() self:_onVote(nil) end } }
        if g:scapegoatAlive() then
            first[#first + 1] = { text = _("Tie vote"), callback = function() self:_onVote(nil, true) end }
        end
        s.rows = { first,
            { { text = _("Eliminate"), enabled = t ~= nil, callback = function() self:_onVote(t) end } } }

    elseif v == "over" then
        s.title = c.win_title[g.winner or "nobody"]
        local lines = { ui.text or "", "" }
        for i, p in ipairs(g.players) do
            local marks = {}
            if p.infected then marks[#marks + 1] = c.marks.infected end
            if p.role == "wildchild" and p.turned then marks[#marks + 1] = c.marks.turned end
            if p.charmed then marks[#marks + 1] = c.marks.charmed end
            if g:isLover(i) then marks[#marks + 1] = c.marks.lover end
            if g.mayor == i then marks[#marks + 1] = c.marks.mayor end
            lines[#lines + 1] = (g:isWinner(i) and "★ " or "") .. (p.alive and "" or "† ")
                .. self:_pname(i) .. " — " .. c.roles[p.role].name
                .. (#marks > 0 and (" (" .. table.concat(marks, ", ") .. ")") or "")
        end
        s.text = table.concat(lines, "\n")
        s.text_px = 0.045
        s.rows = { { { text = _("Game log"), callback = function() self:showLog() end } } }
    end
    return s
end

-- The private screen of a night step.
function WerewolfScreen:_actSpec(s)
    local ui, g, c = self.ui, self.game, self:_c()
    local step = ui.step
    local titles = c.titles
    s.title = titles[step]
    s.text_px = 0.055
    local done = { text = _("Done"), callback = function() self:_actConfirm(nil) end }

    if not g:stepActive(step) then
        s.text = _("Nobody can act here tonight.\nWait a few seconds, then tap Done.")
        s.rows = { { done } }
        return
    end

    if step == "lovers" then
        s.text = _("Lovers, here is your soulmate:")
        s.big  = g.players[g.lovers[1]].name .. "  ♥  " .. g.players[g.lovers[2]].name
        s.rows = { { done } }
        return
    end
    if step == "sisters" then
        local sis = {}
        for _k, i in ipairs(g:holders("sister")) do
            if g.players[i].alive then sis[#sis + 1] = g.players[i].name end
        end
        s.text = _("Sisters, look at each other and agree silently:")
        s.big  = table.concat(sis, "  &  ")
        s.rows = { { done } }
        return
    end
    if step == "charmed" then
        local list = {}
        for i, p in ipairs(g.players) do if p.alive and p.charmed then list[#list + 1] = i end end
        s.text = _("Charmed players, open your eyes and look at each other:") .. "\n\n" .. self:_names(list)
        s.rows = { { done } }
        return
    end
    if step == "infected" then
        s.text = _("The wolf-father has infected you!\nYou are now a werewolf: from the next night you wake up with the pack, and you win with them. You keep your power.")
        s.rows = { { done } }
        return
    end
    if step == "thief" then
        local e = g.extra
        s.text = g:thiefMustTake()
            and _("Both leftover cards are werewolves: you must take one.")
            or  _("Two cards are left over. Take one, or keep none and play as a plain villager.")
        local row = {
            { text = c.roles[e[1]].name, callback = function() self:_actConfirm(1) end },
            { text = c.roles[e[2]].name, callback = function() self:_actConfirm(2) end },
        }
        s.rows = { row }
        if not g:thiefMustTake() then
            s.rows[2] = { { text = _("Keep none"), callback = function() self:_actConfirm(nil) end } }
        end
        return
    end
    if step == "father" then
        local victim = g:wolvesVictim()
        s.text = T(_("The pack chose %1.\nInfect them instead of devouring them? (Once per game.)"),
            g.players[victim].name)
        s.rows = { {
            { text = _("Devour"), callback = function() self:_actConfirm(nil) end },
            { text = _("Infect"), callback = function() self:_actConfirm(true) end },
        } }
        return
    end

    if step == "witch" then
        local victim = g:wolvesVictim()
        if (ui.sub or "heal") == "heal" then
            s.text = victim and T(_("The werewolves attacked %1 tonight."), g.players[victim].name)
                or _("The werewolves attacked nobody tonight.")
            if victim and not g.heal_used then
                s.text = s.text .. "\n\n" .. _("Use your healing potion?")
                s.rows = { {
                    { text = _("Don't save"), callback = function()
                        ui.heal = false; ui.sub = "poison"; self:_refresh() end },
                    { text = T(_("Save %1"), g.players[victim].name), callback = function()
                        ui.heal = true; ui.sub = "poison"; self:_refresh() end },
                } }
            else
                if victim then s.text = s.text .. "\n\n" .. _("Your healing potion is used up.") end
                s.rows = { { { text = _("Continue"), callback = function()
                    ui.heal = false; ui.sub = "poison"; self:_refresh() end } } }
            end
            return
        end
        if g.poison_used then
            s.text = _("Your death potion is used up.")
            s.rows = { { { text = _("Done"), callback = function() self:_actConfirm({ heal = ui.heal }) end } } }
            return
        end
        s.text = _("Use your death potion on someone?")
        self:_pickOne(s, self:_alivePlayers(), _("Poison"),
            function(t) self:_actConfirm({ heal = ui.heal, poison = t }) end,
            { text = _("No poison"), callback = function() self:_actConfirm({ heal = ui.heal }) end })
        return
    end

    if step == "cupid" or step == "piper" then
        s.text = step == "cupid" and _("Choose the two lovers.") or _("Choose two players to charm.")
        local sel = selected(ui.sel)
        local list = g:targets(step)
        s.grid = { list = list, sel = ui.sel, on_tap = function(i) self:_selectTwo(i) end }
        local need = math.min(2, #list)
        s.rows = { { { text = _("Confirm"), enabled = #sel == need,
            callback = function() self:_actConfirm({ sel[1], sel[2] }) end } } }
        return
    end

    local instructions = {
        wildchild = _("Choose your role model. If they die, you become a werewolf."),
        guard     = _("Choose whom to protect tonight."),
        seer      = _("Choose a player to look at."),
        fox       = _("Point at a player: you will learn whether a werewolf is among them and their two neighbours."),
        wolves    = _("Choose your victim."),
        bigwolf   = _("Choose a second victim."),
        whitewolf = _("You may devour one of the werewolves."),
        raven     = _("Mark a player: they will start the next vote with 2 votes against them."),
    }
    s.text = instructions[step]
    local list = step == "fox" and self:_alivePlayers() or g:targets(step)
    local extra
    if step == "whitewolf" or step == "raven" then
        extra = { text = _("Nobody"), callback = function() self:_actConfirm(nil) end }
    end
    self:_pickOne(s, list, _("Confirm"), function(t) self:_actConfirm(t) end, extra)
end

-- The role card shown to player i during the distribution.
function WerewolfScreen:_buildCard(i, w, h)
    local g, c = self.game, self:_c()
    local p = g.players[i]
    local role = c.roles[p.role]
    local short = math.min(w, h)
    local pad = Size.padding.large
    local inner_w = w - 2 * (pad + Size.border.window)
    local vs = Size.span.vertical_large
    local top = VerticalGroup:new{ align = "center" }
    top[#top + 1] = fitLine(p.name, short * 0.08, inner_w)
    if self.theme == "famous" and p.alias then
        top[#top + 1] = fitLine(T(c.alias_card, p.alias), short * 0.05, inner_w)
    end
    top[#top + 1] = VerticalSpan:new{ width = vs * 2 }
    top[#top + 1] = fitLine(role.name, short * 0.13, inner_w, true)
    top[#top + 1] = VerticalSpan:new{ width = vs }
    top[#top + 1] = fitLine(c.teams[Game.ROLES[p.role].team], short * 0.05, inner_w)
    top[#top + 1] = VerticalSpan:new{ width = vs }
    top[#top + 1] = LineWidget:new{
        background = Blitbuffer.COLOR_DARK_GRAY,
        dimen = Geom:new{ w = math.floor(inner_w * 0.6), h = Size.line.medium },
    }
    top[#top + 1] = VerticalSpan:new{ width = vs }
    local inner_h = h - 2 * (pad + Size.border.window)
    local rest = math.max(40, inner_h - top:getSize().h)
    top[#top + 1] = fitBox(role.desc, short * 0.055, inner_w, rest)
    return FrameContainer:new{
        padding = pad, margin = 0, radius = Size.radius.window,
        bordersize = Size.border.thick,
        CenterContainer:new{ dimen = Geom:new{ w = inner_w, h = inner_h }, top },
    }
end

-- Composition editor: "Name: n  −  +", one role per row, in pages sized to
-- the room left, with a page switcher under the list.
function WerewolfScreen:_buildRolesTable(width, max_h)
    local c, n = self:_c(), #self.names
    local roles = {}
    for _i, role in ipairs(Game.ROLE_ORDER) do
        if role ~= "villager" then roles[#roles + 1] = role end
    end
    local small = math.floor(width * 0.16)
    local function row(role)
        local k = self.comp[role] or 0
        return {
            { text = T(_("%1: %2"), c.roles[role].name, k), align = "left", font_bold = k > 0,
              font_size = 20, callback = function() end },
            { text = "−", width = small, font_size = 24,
              enabled = Game.adjust(self.comp, n, role, -1) ~= nil,
              callback = function() self:_adjustRole(role, -1) end },
            { text = "+", width = small, font_size = 24,
              enabled = Game.adjust(self.comp, n, role, 1) ~= nil,
              callback = function() self:_adjustRole(role, 1) end },
        }
    end
    local function build(from, to)
        local rows = {}
        for k = from, to do rows[#rows + 1] = row(roles[k]) end
        return ButtonTable:new{ width = width, buttons = rows }
    end
    local t1, t2 = build(1, 1), build(1, 2)
    local per_row = t2:getSize().h - t1:getSize().h
    local base = t1:getSize().h - per_row
    t1:free(); t2:free()
    local nav_h = per_row + Size.span.vertical_large
    local fit = math.floor((max_h - base) / per_row)
    if fit >= #roles then return build(1, #roles) end
    local per_page = math.max(3, math.floor((max_h - base - nav_h) / per_row))
    local pages = math.ceil(#roles / per_page)
    local page = math.max(1, math.min(pages, self.ui.page or 1))
    self.ui.page = page
    local from = (page - 1) * per_page + 1
    local tbl = build(from, math.min(#roles, from + per_page - 1))
    local nav = ButtonTable:new{ width = width, buttons = { {
        { text = "◀", font_size = 24, enabled = page > 1, callback = function()
            self.ui.page = page - 1; self:_refresh() end },
        { text = T(_("Page %1/%2"), page, pages), callback = function() end },
        { text = "▶", font_size = 24, enabled = page < pages, callback = function()
            self.ui.page = page + 1; self:_refresh() end },
    } } }
    return VerticalGroup:new{ align = "center", tbl, VerticalSpan:new{ width = Size.span.vertical_large }, nav }
end

function WerewolfScreen:buildLayout()
    local s = self:_spec()
    local title_bar = self:_titleBar()
    self.status_text:setMaxWidth(self:getControlsWidth())
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar(s.rows),
    }
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short = math.min(bw, bh)
    local vs = Size.span.vertical_large
    self.timer_widget, self.timer_box = nil, nil

    local content
    if s.card then
        content = self:_buildCard(s.card, bw, bh)
    else
        local parts = VerticalGroup:new{ align = "center" }
        local used = 0
        local function add(w)
            parts[#parts + 1] = w
            used = used + w:getSize().h
        end
        if s.title then
            add(fitLine(s.title, short * 0.075, bw, true))
            add(VerticalSpan:new{ width = vs * 2 })
        end
        local grid
        if s.grid then grid = self:_grid(s.grid.list, s.grid, bw) end
        if s.roles_table then
            -- the line above the table takes one short line of text
            grid = self:_buildRolesTable(bw, bh - used - short * 0.08 - vs * 2)
        end
        local reserved = grid and (grid:getSize().h + vs * 2) or 0
        local big
        if s.big then big = fitLine(s.big, short * 0.11, bw, true); reserved = reserved + big:getSize().h + vs * 2 end
        local sub
        if s.sub then sub = fitBox(s.sub, short * 0.045, bw, short * 0.4); reserved = reserved + sub:getSize().h + vs * 2 end
        if s.timer then
            self.timer_widget = TextWidget:new{ text = self:_timerText(), face = pxFace(short * 0.12), bold = true }
            self.timer_box = CenterContainer:new{
                dimen = Geom:new{ w = bw, h = self.timer_widget:getSize().h },
                self.timer_widget,
            }
            reserved = reserved + self.timer_box:getSize().h + vs * 2
        end
        if s.text then
            local room = math.max(60, bh - used - reserved)
            local text_w = s.read_aloud and math.floor(bw * 0.95) or bw
            add(fitBox(s.text, short * (s.text_px or 0.06), text_w, room))
        end
        if big then add(VerticalSpan:new{ width = vs * 2 }); add(big) end
        if sub then add(VerticalSpan:new{ width = vs * 2 }); add(sub) end
        if self.timer_box then add(VerticalSpan:new{ width = vs * 2 }); add(self.timer_box) end
        if grid then add(VerticalSpan:new{ width = vs * 2 }); add(grid) end
        content = CenterContainer:new{ dimen = Geom:new{ w = bw, h = math.min(bh, math.max(used, 1)) }, parts }
    end

    if self:isLandscape() then
        self:buildLandscapeLayout(title_bar, HorizontalGroup:new{
            align = "center",
            content,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        })
    else
        self:buildPortraitLayout(title_bar, content,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
    self[1] = self.layout
    self:updateStatus()
end

function WerewolfScreen:updateStatus(msg)
    if msg then ScreenBase.updateStatus(self, msg); return end
    local g = self.game
    local text
    if not g then
        text = self:joinStatus(T(_("Players: %1"), #self.names),
            T(_("Werewolves: %1"), Game.wolfCount(self.comp)))
    elseif g.phase == "deal" then
        text = T(_("Role %1/%2"), math.min(g.deal_index, g:count()), g:count())
    else
        local when = g.phase == "night" and T(_("Night %1"), g.night) or T(_("Day %1"), g.day)
        if g:isOver() then when = self:_c().win_title[g.winner] end
        text = self:joinStatus(when, T(_("Alive: %1/%2"), g:aliveCount(), g:count()),
            self.theme ~= "classic" and self:_themeLabel(self.theme) or nil)
    end
    ScreenBase.updateStatus(self, text)
end

function WerewolfScreen:onClose()
    self:_stopTimer()
    ScreenBase.onClose(self)
end

return WerewolfScreen
