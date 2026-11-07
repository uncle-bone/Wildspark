Warning: truncated output (original token count: 27181)
Total output lines: 2594

-- Wildspark : met en lumi�re l'objet interactif vis� (filons, plantes, objets de qu�te)
-- Principe : le "soft targeting" officiel de Blizzard d�signe � tout instant une seule cible
-- d'interaction (l'unit� "softinteract") et lui donne une nameplate. Wildspark accroche � cette
-- nameplate une wildspark unique, color�e selon le type d'objet (lu depuis son ic�ne de curseur)
-- et anim�e selon son �tat : hors de port�e, � port�e, indisponible. L'effet choisi
-- (Effects.lua) d�cide de son dessin ; les textes viennent du dossier Locales.

local ADDON_NAME, ns = ...
local L = ns.L
local EFFECTS = ns.EFFECTS
local Lerp, Sized, Tint, Place = ns.Lerp, ns.Sized, ns.Tint, ns.Place

local SOFT = "softinteract"
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local CURSORS = "Interface\\Cursor\\"
local FALLBACK_TEXTURE = "Interface\\Cooldown\\star4"
local SCHEMA = 9 -- version des r�glages sauvegard�s

-- R�glages communs � tous les personnages du compte (WildsparkDB)
local DEFAULTS = {
	enabled     = true,
	range       = 15,     -- port�e du soft targeting (m�tres)
	arc         = 2,      -- 0 = pile devant, 1 = devant, 2 = toutes directions
	offsetY     = -45,    -- d�calage vertical de la wildspark par rapport � la nameplate (pixels)
	size        = 120,    -- taille de la wildspark (pixels, � l'�chelle de la nameplate)
	effect      = "aura",
	categorySettings = {}, -- cat�gorie -> ses r�glages de personnalisation propres (voir LOOK)
	colors      = {       -- couleur de la wildspark de chaque cat�gorie
		ore   = { 1.00, 0.60, 0.18 },
		herb  = { 0.40, 1.00, 0.42 },
		quest = { 1.00, 0.84, 0.15 },
		chest = { 0.45, 0.78, 1.00 },
		bobber = { 1.00, 0.45, 0.40 },
		other = { 0.90, 0.90, 0.94 },
	},
	intensity   = 100,    -- luminosit� de la wildspark (%)
	followAlpha = false,  -- la wildspark s'estompe avec la nameplate (objet masqu� par le d�cor.)
	showName    = true,   -- nom de l'objet au-dessus de lui, �crit par Wildspark � la place de celui du jeu
	showIcon    = true,   -- et son ic�ne d'interaction, au-dessus du nom
	textSize    = 100,    -- taille de ce nom (% de celle de la police du jeu)
	textFont    = "game", -- sa police : celle du jeu, ou l'une des autres polices du jeu (Locales.lua)
	silhouette  = true,   -- la wildspark passe derri�re le personnage au lieu de le recouvrir
	exclusive   = true,   -- le jeu ne met en avant (nameplate, ic�ne) que les cibles mises en lumi�re
	hideInCombat   = false,  -- pas de wildspark en combat
	hideInInstance = false,  -- ni en donjon, en raid ou en champ de bataille
	hideLocked     = false,  -- ni sur un objet que le jeu refuse pour l'instant
	hideUntrained  = true,   -- ni sur une plante ou un filon quand le personnage n'a pas le m�tier qui les r�colte
	debug       = false,
	language    = "auto",   -- langue des textes : "auto" (celle du client) ou le code d'une langue du dossier Locales
	questObjects = {},    -- nom d'objet -> titre de sa qu�te, appris de son infobulle
	ignored     = {},     -- nom d'objet repli� -> son nom : objets que le joueur ne veut jamais voir briller
	containers  = {},     -- num�ro d'objet -> true : objets du d�cor que le joueur a d�j� fouill�s, rang�s depuis parmi les coffres
	minimap     = { hide = false, angle = 205 }, -- bouton de la minimap : masqu� ou non, position (degr�s)
	nodeHerbs   = true,   -- sur la minimap, l'ic�ne de chaque plante que le pistage du jeu y montre (NodeScan.lua)
	nodeOre     = true,   -- et celle de chaque filon
	nodeSize    = 12,     -- c�t� de ces ic�nes (unit�s de la minimap)
	nodeNames   = {},     -- langue du client -> nom repli� d'un filon ou d'une plante -> { kind, id }, appris en s'en approchant
}

-- R�glages propres � chaque personnage (WildsparkCharDB) : ce qu'il r�colte, et la d�coupe � sa taille
local CHAR_DEFAULTS = {
	categories  = { ore = true, herb = true, quest = true, chest = true, bobber = true, other = false },
	bodyScale   = 100,    -- taille de la zone d�coup�e autour du personnage (%)
	bodyShift   = 0,      -- d�calage vertical de cette zone (% de la hauteur du personnage)
	nodeSwitch  = false,  -- deux m�tiers de r�colte : Wildspark allume tour � tour le pistage des plantes et celui des minerais
	nodeSwitchYards = 15, -- distance parcourue entre deux de ces bascules (m�tres)
	autoPushSpells = true, -- queue new active spells for deliberate out-of-combat placement
	knownSpells = {}, -- per-character spellbook snapshot
}

-- R�glages de personnalisation : chacun vaut pour tous les objets, sauf pour une cat�gorie qui
-- a le sien dans db.categorySettings. La couleur, elle, n'existe que par cat�gorie (db.colors).
local LOOK = { effect = true, size = true, intensity = true, offsetY = true, followAlpha = true, showName = true, showIcon = true, textSize = true, textFont = true,
	silhouette = true }

-- Bornes des r�glages num�riques, communes aux commandes et aux curseurs du menu
local LIMITS = {
	range     = { 5, 15 },  -- mesur� sur Forever 1.60.1 : la cible d'interaction se perd � 15 m, m�me avec 60 demand�s
	arc       = { 0, 2 },
	offsetY   = { -200, 200 },
	size      = { 40, 300 },
	intensity = { 30, 150 },
	textSize  = { 60, 200 },
	bodyScale = { 40, 300 },
	bodyShift = { -100, 100 },
	nodeSize  = { 8, 24 },
	nodeSwitchYards = { 10, 50 },
}

-- "chest" : ce qui se fouille (coffres, caisses, tonneaux) ; "bobber" : le flotteur de la ligne de p�che ;
-- "other" : le reste (portes, bo�tes aux lettres.)
local CATEGORY_ORDER = { "ore", "herb", "quest", "chest", "bobber", "other" }

-- Styles du halo d'avant la version 0.5 -> effet qui les remplace
local LEGACY_STYLES = { aura = "aura", reticule = "reticle", discret = "subtle" }

local POLL_INTERVAL = 0.12   -- r��valuation de la cible et de son �tat (secondes)
local APPEAR_TIME   = 0.45   -- la wildspark arrive
local BLEND_TIME    = 0.30   -- fondu entre deux �tats
local FLASH_TIME    = 0.50   -- �clair du passage "� port�e"
local GHOST_TIME    = 0.40   -- dissipation quand la cible dispara�t
local STATE_DELAY   = 0.15   -- un �tat doit tenir ce temps avant d'�tre affich� (anti-scintillement)
local LOCK_DELAY    = 0.60   -- idem pour "indisponible", confirm� plus prudemment

-- P�che : le flotteur tombe souvent au-del� des 15 m o� s'arr�te le r�glage de port�e. Tant que
-- la ligne est � l'eau, Wildspark demande donc au jeu de chercher jusqu'� LINE_RANGE.
local LINE_RANGE    = 60      -- m�tres ; ni 25 ni 40 ne suffisaient toujours
local FISHING_ICON  = 136245  -- Interface\Icons\Trade_Fishing : l'ic�ne du sort de p�che, dans toutes les langues
-- Num�ro du flotteur dans les donn�es du jeu (son GUID le porte) : le m�me pour toutes les lignes
local BOBBER_IDS    = { [35591] = true }

-- Fichiers de curseur du jeu (Interface\Cursor\*.blp) -> cat�gorie. Les noms sont ceux que le
-- client de Forever conna�t (lus dans WowB.exe, build 70338), plus Fishing, qu'il n'a pas.
-- Un coffre n'a pas de curseur � lui : voir MatchContainer.
-- "service" : le curseur dit lui-m�me ce qu'est l'objet (une bo�te aux lettres, et ce que le jeu
-- montre d'ordinaire sur un PNJ). C'est un autre objet, que son nom ne range nulle part ailleurs :
-- voir Classify.
local CURSOR_CATEGORY = {
	Mine = "ore",
	GatherHerbs = "herb",
	Quest = "quest", QuestRepeatable = "quest", QuestTurnIn = "quest", QuestInteract = "quest",
	CampaignQuest = "quest", CampaignQuestTurnIn = "quest", LegendaryQuest = "quest", LegendaryQuestTurnIn = "quest",
	Important = "quest", ImportantTurnIn = "quest", Recurring = "quest", Recurringturnin = "quest",
	Wrapper = "quest", Wrapperturnin = "quest",
	PickLock = "chest", LootAll = "chest", Pickup = "chest",
	Fishing = "bobber", FishingCursor = "bobber",
	Interact = "other", GamepadInteract = "other", Inspect = "other",
	Mail = "service", Speak = "service", Buy = "service", Trainer = "service", Taxi = "service", Innkeeper = "service",
	Repair = "service", RepairNPC = "service", Stablemaster = "service",
}

-- Curseur que l'aper�u montre pour chaque cat�gorie, faute d'objet � qui le demander
local SAMPLE_CURSOR = { ore = "Mine", herb = "GatherHerbs", quest = "Quest", chest = "Pickup", bobber = "Fishing", other = "Interact" }

-- CVars que Wildspark modifie (valeurs d'origine sauvegard�es puis restaur�es par /wildspark off)
local MANAGED_CVARS = {
	"SoftTargetInteract", "SoftTargetNameplateInteract", "SoftTargetInteractRange", "SoftTargetInteractArc",
	"SoftTargetInteractOnlyInRange", "SoftTargetInteractRangeIsHard", "SoftTargetIconInteract", "SoftTargetIconGameObject",
	"nameplateGameObjectMaxDistance",
}
-- Parmi elles, l'ic�ne que le jeu pose sur la cible d'interaction
-- SoftTargetIconGameObject est forc� � 1 quand la gate s'ouvre : sans ic�ne, le jeu ne
-- cr�e pas de nameplate pour les objets interactibles en soft target (Classic)
local ICON_CVARS = { "SoftTargetIconInteract", "SoftTargetIconGameObject" }
-- CVars que Wildspark lit sans y toucher : /wildspark status les montre, parce que la nameplate en d�pend peut-�tre
local WATCHED_CVARS = { "nameplateMaxDistance" }

local db, cdb                -- r�glages du compte, r�glages du personnage
local Evaluate               -- d�fini plus bas : met la wildspark en accord avec la cible courante
local UseLanguage            -- d�fini plus bas : sert textes et commandes dans la langue r�gl�e
local gateOpen               -- l'affichage natif de la cible est-il ouvert ? nil = � r�appliquer
local inCombat = false       -- entre PLAYER_REGEN_DISABLED et PLAYER_REGEN_ENABLED
local cursorLookup = {}      -- fileID -> { cat�gorie, gris� }
local activeUnits = {}       -- jeton nameplateN -> true
local probe                  -- texture cach�e servant � lire l'ic�ne de curseur
local pendingCVars = false
local leaving = false        -- d�connexion en cours : les CVars sont rendues, plus rien ne doit y toucher
local directWorks = false    -- GetNamePlateForUnit("softinteract") a d�j� abouti pour un objet
local lineOut = false        -- la ligne de p�che du joueur est � l'eau, et son flotteur fait partie des objets mis en lumi�re
local lastReport             -- derni�re ligne de debug affich�e (�vite les r�p�titions)

local glow = { layers = {} }  -- cadre unique de la wildspark, �tat de son animation, couches de tous ses effets
local ghost                   -- cadre de dissipation
local label                   -- nom et ic�ne de l'objet, au-dessus de la wildspark

local sin, min, max = math.sin, math.min, math.max
local TWO_PI = 2 * math.pi

local function Print(msg)
	print(L.PREFIX .. msg)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local function SafeCall(func, ...)
	if not func then return nil end
	local ok, result = pcall(func, ...)
	if not ok or IsSecret(result) then return nil end
	return result
end

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function Clamp(value, low, high)
	return max(low, min(high, value))
end

local function Approach(value, target, step)
	if value < target then return min(value + step, target) end
	return max(value - step, target)
end

-- Table o� vit un r�glage : celle du personnage, ou celle du compte
local function Store(key)
	return CHAR_DEFAULTS[key] ~= nil and cdb or db
end

-- Couleur d'une cat�gorie : trois composantes
local function Color(category)
	local color = db.colors[category] or db.colors.other
	return color[1], color[2], color[3]
end

-- Valeur d'un r�glage de personnalisation pour une cat�gorie : la sienne, sinon celle de tous
-- les objets ; sans cat�gorie, celle de tous les objets
local function Look(category, key)
	local own = category and db.categorySettings[category]
	local value = own and own[key]
	if value == nil then return db[key] end
	return value
end

-- Minuscules sans accents : commandes, noms d'effets et noms d'objets se tapent avec ou sans.
-- string.lower ne conna�t que l'ASCII : les majuscules latines accentu�es et cyrilliques passent
-- par cette table.
local ACCENTS = {
	["�"] = "a", ["�"] = "a", ["�"] = "a", ["�"] = "a", ["�"] = "c", ["�"] = "e", ["�"] = "e", ["�"] = "e", ["�"] = "e",
	["�"] = "i", ["�"] = "i", ["�"] = "i", ["�"] = "o", ["�"] = "o", ["�"] = "o", ["�"] = "u", ["�"] = "u", ["�"] = "u",
	["�"] = "u", ["�"] = "n", ["�"] = "ss", ["A"] = "a", ["A"] = "a", ["�"] = "a", ["A"] = "a", ["�"] = "c", ["�"] = "e",
	["E"] = "e", ["E"] = "e", ["I"] = "i", ["I"] = "i", ["O"] = "o", ["�"] = "o", ["O"] = "o", ["U"] = "u", ["U"] = "u",
	["�"] = "u", ["U"] = "u", ["�"] = "n",
}
-- cyrillique : ?-? (208 144-159) donnent ?-? (208 176-191), ?-? (208 160-175) donnent ?-?
-- (209 128-143) ; ? et ? s'�crivent ?, comme le font souvent les textes du jeu
for byte = 144, 175 do
	ACCENTS["\208" .. string.char(byte)] = byte < 160 and "\208" .. string.char(byte + 32) or "\209" .. string.char(byte - 32)
end
ACCENTS["\208\129"], ACCENTS["\209\145"] = "\208\181", "\208\181"

local function Fold(text)
	return (text:gsub("[\195-\197\208\209][\128-\191]", ACCENTS):lower())
end

-- Noms affich�s, relus � chaque usage : la langue peut changer en cours de jeu
local function EffectLabel(key)
	return L["EFFECT_" .. key:upper()]
end

-- Nom d'une cat�gorie dans le menu
local function CategoryLabel(category)
	return L["CATEGORY_" .. category:upper()]
end

-- Nom d'une cat�gorie, ou de son absence, dans une phrase du diagnostic
local function CategoryName(category)
	return L["NAME_" .. (category or "none"):upper()]
end

local function StateName(state)
	return L["STATE_" .. state:upper()]
end

---------------------------------------------------------------------------
-- CVars
---------------------------------------------------------------------------

local function GetCVarValue(name)
	local ok, value = pcall(C_CVar and C_CVar.GetCVar or GetCVar, name)
	if ok then return value end
end

-- Ne touche qu'aux CVars que ce client conna�t (la liste varie d'une version � l'autre)
local function SetCVarValue(name, value)
	if GetCVarValue(name) == nil then return end
	pcall(C_CVar and C_CVar.SetCVar or SetCVar, name, tostring(value))
end

-- Affichage natif de la cible d'interaction : sa nameplate, o� s'accroche la wildspark, et son
-- ic�ne. En mode exclusif, Wildspark ne l'ouvre que pour une cible mise en lumi�re : PNJ,
-- cadavres, bo�tes aux lettres et autres restent utilisables avec la touche d'interaction,
-- mais le jeu ne les met plus en avant.
local function EnsureIconCVars()
	-- Le client beta �crase SoftTargetIconGameObject � 0 apr�s PLAYER_ENTERING_WORLD
	-- On le r�pare ici, avant que Evaluate() ne cherche la nameplate
	if gateOpen == true then
		local current = GetCVarValue("SoftTargetIconGameObject")
		if current ~= "1" then SetCVarValue("SoftTargetIconGameObject", 1) end
	end
end

local function SetGate(open)
	open = open or not db.exclusive
	-- Do not trust gateOpen as the only source of truth. Forever may restore or
	-- rewrite the CVar after login/settings synchronization while our cached state
	-- still says the requested value is active. Reassert it whenever it drifted.
	if InCombatLockdown() then
		EnsureIconCVars()
		return
	end
	local wanted = open and "1" or "0"
	if open == gateOpen and GetCVarValue("SoftTargetNameplateInteract") == wanted then
		EnsureIconCVars()
		return
	end
	gateOpen = open
	SetCVarValue("SoftTargetNameplateInteract", wanted)
	-- SoftTargetIconGameObject doit �tre 1 pour que le jeu cr�e des nameplates pour les game objects
	if open then SetCVarValue("SoftTargetIconGameObject", 1) end
	for _, name in ipairs(ICON_CVARS) do
		if name ~= "SoftTargetIconGameObject" then
			local original = db.savedCVars and db.savedCVars[name]
			if original ~= false then SetCVarValue(name, open and original or 0) end
		end
	end
end

-- Port�e � demander au jeu : celle du r�glage, ou celle qu'il faut pour atteindre le flotteur
local function WantedRange()
	return lineOut and LINE_RANGE or db.range
end

-- Le client porte-t-il les valeurs que Wildspark applique ? C'est qu'elles ne lui ont pas �t� rendues.
local function CVarsLookApplied()
	local onlyInRange = GetCVarValue("SoftTargetInteractOnlyInRange")
	local range = tonumber(GetCVarValue("SoftTargetInteractRange"))
	return GetCVarValue("SoftTargetInteract") == "3" and (onlyInRange == nil or onlyInRange == "0")
		and (range == db.range or range == LINE_RANGE)
end

local function ApplyCVars()
	if InCombatLockdown() then pendingCVars = "apply" return end
	if db.cvarsReturned then
		-- rendues au jeu � la derni�re d�connexion : ce que le client porte maintenant, ce sont les
		-- valeurs du joueur, qu'il a pu changer depuis. On les relit, sauf si ce sont les n�tres.
		db.cvarsReturned = nil
		if not CVarsLookApplied() then db.savedCVars = nil end
	end
	db.savedCVars = db.savedCVars or {}
	for _, name in ipairs(MANAGED_CVARS) do
		if db.savedCVars[name] == nil then
			db.savedCVars[name] = GetCVarValue(name) or false
		end
	end
	SetCVarValue("SoftTargetInteract", 3)          -- soft target d'interaction toujours actif
	SetCVarValue("SoftTargetInteractRange", WantedRange())
	SetCVarValue("SoftTargetInteractArc", db.arc)    -- angle de recherche autour du joueur
	SetCVarValue("SoftTargetInteractOnlyInRange", 0) -- d�tecter aussi hors de port�e d'interaction
	-- la port�e demand�e ne doit pas �carter ce avec quoi le joueur peut interagir d'o� il est,
	-- comme le flotteur de sa ligne de p�che
	SetCVarValue("SoftTargetInteractRangeIsHard", 0)
	-- la wildspark s'accroche � la nameplate de l'objet : le jeu doit la montrer aussi loin qu'il le
	-- d�signe, donc jusqu'au flotteur. Le joueur qui la montre plus loin encore garde sa valeur.
	SetCVarValue("nameplateGameObjectMaxDistance", max(tonumber(db.savedCVars.nameplateGameObjectMaxDistance) or 0, LINE_RANGE))
	-- la nameplate et l'ic�ne de la cible d�pendent de ce qui est vis�
	gateOpen = nil
	Evaluate()
end

-- La port�e seule, quand la ligne de p�che entre dans l'eau ou en sort. Renvoie false quand il
-- n'y a rien � �crire, parce que Wildspark ne tient pas les CVars du jeu : d�sactiv�, ou pas encore
-- pass� par ApplyCVars.
local function ApplyRange()
	if not db.enabled or not db.savedCVars or db.cvarsReturned then return false end
	if InCombatLockdown() then
		pendingCVars = pendingCVars or "apply"
	else
		SetCVarValue("SoftTargetInteractRange", WantedRange())
	end
	return true
end

local function RestoreCVars()
	if InCombatLockdown() then pendingCVars = "restore" return end
	if not db.savedCVars then return end
	for name, value in pairs(db.savedCVars) do
		if value ~= false then SetCVarValue(name, value) end
	end
	db.savedCVars = nil
	gateOpen = nil
end

-- A la d�connexion, le jeu retrouve ses valeurs d'origine : d�sactiver ou d�sinstaller Wildspark
-- depuis la liste des addons ne laisse rien derri�re lui. Elles restent en m�moire pour le
-- cas o� le client ne les enregistrerait pas (fermeture brutale).
local function ReturnCVars()
	if not db.enabled or not db.savedCVars or InCombatLockdown() then return end
	for name, value in pairs(db.savedCVars) do
		if value ~= false then SetCVarValue(name, value) end
	end
	db.cvarsReturned = true
	gateOpen = nil
end

-- Les versions 0.1.x pouvaient m�moriser comme valeurs d'origine celles que Wildspark venait
-- lui-m�me d'appliquer : /wildspark off ne rendait alors rien. Quand la sauvegarde porte cette
-- signature, on lui substitue les valeurs par d�faut du client.
local function RepairSavedCVars()
	local saved = db.savedCVars
	if not saved or not (C_CVar and C_CVar.GetCVarDefault) then return end
	if saved.SoftTargetInteract ~= "3" or saved.SoftTargetNameplateInteract ~= "1" or saved.SoftTargetInteractArc ~= "2"
		or (saved.SoftTargetInteractRange ~= "20" and saved.SoftTargetInteractRange ~= tostring(db.range)) then
		return
	end
	for _, name in ipairs({ "SoftTargetInteract", "SoftTargetNameplateInteract", "SoftTargetInteractArc", "SoftTargetInteractRange" }) do
		local default = SafeCall(C_CVar.GetCVarDefault, name)
		if default ~= nil then saved[name] = default end
	end
end

---------------------------------------------------------------------------
-- Classification
---------------------------------------------------------------------------

local function BuildCursorLookup()
	if not GetFileIDFromPath then return end
	for name, category in pairs(CURSOR_CATEGORY) do
		for _, prefix in ipairs({ "", "Unable" }) do
			local path = "Interface\\Cursor\\" .. prefix .. name
			local id = SafeCall(GetFileIDFromPath, path) or SafeCall(GetFileIDFromPath, path .. ".blp")
			if id then cursorLookup[id] = { category, prefix ~= "" } end
		end
	end
end

local QUEST_LINE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective

-- Un objet � ramasser pour une qu�te porte un curseur g�n�rique, et l'API de qu�te par unit�
-- ne les reconna�t pas tous. On le rattache donc � une qu�te en cours par, dans l'ordre : ce
-- que son infobulle a d�j� r�v�l�, son nom dans le texte d'un objectif ("Scie d�tremp�e :
-- 0/1"), ou un mot marquant en commun avec un objet � ramasser ("Tas de camelote" pour
-- "Camelote rutilante"). Noms et objectifs sont ceux du client, dans sa langue.
local questTexts = {}      -- objectifs inachev�s : { text = minuscules sans compteur, pickable = objet � ramasser ou � utiliser }
local questTitles = {}     -- titre normalis� de chaque qu�te en cours -> true
local questsDirty = true

local function NormalizeText(text)
	text = text:lower():gsub("\194\160", " ")  -- espace ins�cable (typographie fran�aise)
	text = text:gsub("\226\128\153", "'")      -- apostrophe typographique
	text = text:gsub("%d+%s*/%s*%d+", "")
	text = text:gsub("^[%s:%-]+", ""):gsub("[%s:%-]+$", "")
	return text
end

-- Adjectifs trop r�pandus pour rapprocher � eux seuls un objet d'un objectif : ceux de la
-- langue du client, qui est celle des noms et des objectifs, pas ceux de la langue affich�e.
-- Ils passent par la m�me mise en forme que les noms auxquels ils seront compar�s.
local COMMON_WORDS = {}
for word in NormalizeText(ns.CommonWords()):gmatch("%S+") do COMMON_WORDS[word] = true end

-- Cl� d'un nom d'objet dans la liste des objets ignor�s : il s'y retrouve tap� avec ou sans
-- accents. Les accents se replient avant le passage en minuscules, qui ne sait rien d'eux.
local function NameKey(name)
	name = name:gsub("\194\160", " "):gsub("\226\128\153", "'")
	return (Fold(name):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function RebuildQuestTexts()
	questsDirty = false
	for i = #questTexts, 1, -1 do questTexts[i] = nil end
	for title in pairs(questTitles) do questTitles[title] = nil end
	if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
	local modern = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestIDForLogIndex
	for index = 1, SafeCall(modern and C_QuestLog.GetNumQuestLogEntries or GetNumQuestLogEntries) or 0 do
		local questID, title
		if modern then
			questID = SafeCall(C_QuestLog.GetQuestIDForLogIndex, index)
			title = type(questID) == "number" and SafeCall(C_QuestLog.GetTitleForQuestID, questID)
		elseif GetQuestLogTitle then
			local ok, name, _, _, isHeader, _, _, _, id = pcall(GetQuestLogTitle, index)
			if ok and not isHeader then questID, title = id, name end
		end
		if type(title) == "string" then questTitles[NormalizeText(title)] = true end
		local objectives = type(questID) == "number" and SafeCall(C_QuestLog.GetQuestObjectives, questID)
		if type(objectives) == "table" then
			for _, objective in ipairs(objectives) do
				local text = objective.text
				if not objective.finished and type(text) == "string" and not IsSecret(text) then
					text = NormalizeText(text)
					if #text >= 4 then
						local kind = objective.type
						questTexts[#questTexts + 1] = { text = text, pickable = kind == nil or kind == "item" or kind == "object" }
					end
				end
			end
		end
	end
end

-- Renvoie un mot marquant de `source` qui commence aussi un mot de `target`
local function SharedWord(source, target)
	target = " " .. target:gsub("%p", " ")
	for word in source:gmatch("[^%s%p]+") do
		if #word >= 5 and not COMMON_WORDS[word] and target:find(" " .. word, 1, true) then return word end
	end
end

-- Renvoie ce qui rattache ce nom d'objet � une qu�te en cours (affich� par le debug), ou nil
local function MatchQuestObjective(name)
	if type(name) ~= "string" or #name < 4 then return nil end
	if questsDirty then RebuildQuestTexts() end
	name = NormalizeText(name)
	if questTitles[db.questObjects[name]] then return L.MATCH_TOOLTIP end
	for _, objective in ipairs(questTexts) do
		local text = objective.text
		-- "scie d�tremp�e" dans l'objectif, ou l'objectif ("fournitures") dans le nom de l'objet
		if text:find(name, 1, true) or (#text >= 5 and name:find(text, 1, true)) then return L.MATCH_NAME end
	end
	for _, objective in ipairs(questTexts) do
		-- jamais avec un objectif d'�limination : "Hutte murloc" n'est pas un "Murloc tu�"
		if objective.pickable then
			local word = SharedWord(name, objective.text) or SharedWord(objective.text, name)
			if word then return L.MATCH_WORD:format(word) end
		end
	end
end

-- L'infobulle d'un objet de qu�te nomme sa qu�te. Quand le jeu en montre une (survol � la
-- souris, ou infobulle de la cible d'interaction si tu l'as activ�e), on retient le nom de
-- l'objet : c'est le seul lien s�r quand ce nom n'a rien de commun avec l'objectif.
local function LearnFromTooltip()
	if not (C_TooltipInfo and C_TooltipInfo.GetWorldCursor) then return false end
	local data = SafeCall(C_TooltipInfo.GetWorldCursor)
	local lines = type(data) == "table" and data.lines
	if type(lines) ~= "table" or not lines[1] then return false end
	if Enum and Enum.TooltipDataType and data.type == Enum.TooltipDataType.Unit then return false end
	local name = lines[1].leftText
	if IsSecret(name) or type(name) ~= "string" then return false end
	if questsDirty then RebuildQuestTexts() end
	for index = 2, #lines do
		local text = lines[index].leftText
		if not IsSecret(text) and type(text) == "string" then
			local title = NormalizeText(text)
			if questTitles[title] then
				name = NormalizeText(name)
				if db.questObjects[name] == title then return false end
				db.questObjects[name] = title
				return true
			end
		end
	end
	return false
end

-- Le jeu lui-m�me rattache-t-il cet objet � une qu�te en cours ?
local function IsQuestUnit(unit)
	-- API ajout�es dans Forever ; absentes de Classic Era (restent alors le curseur et le nom)
	if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
		if SafeCall(C_QuestLog.UnitIsRelatedToActiveQuest, unit) == true then return true end
	end
	if QUEST_LINE_TYPE and C_TooltipInfo and C_TooltipInfo.GetUnit then
		local data = SafeCall(C_TooltipInfo.GetUnit, unit)
		if data and data.lines then
			for _, line in ipairs(data.lines) do
				if line.type == QUEST_LINE_TYPE then return true end
			end
		end
	end
	return false
end

-- Le joueur p�che-t-il ? La p�che est une canalisation, reconnue � l'ic�ne de son sort, sinon �
-- son nom, qui est celui du m�tier. Renvoie aussi le nom et l'ic�ne de la canalisation en
-- cours, pour le diagnostic.
local function ReadLine()
	if not UnitChannelInfo then return false end
	local ok, name, _, icon = pcall(UnitChannelInfo, "player")
	if not ok then return false end
	if IsSecret(name) then name = nil end
	if IsSecret(icon) then icon = nil end
	if name == nil and icon == nil then return false end
	local fishing = icon == FISHING_ICON
		or (type(icon) == "string" and icon:lower():find("trade_fishing", 1, true) ~= nil)
		or (name ~= nil and name == PROFESSIONS_FISHING)
	return fishing, name, icon
end

-- Le client renvoie selon les cas un fileID, un chemin (Interface\Cursor\Mine) ou un nom
-- d'atlas (Cursor_Crosshair_UnableMine_64) : on cherche donc des mots-cl�s dans la cha�ne.
-- Le premier qui s'y trouve l'emporte : � questinteract � est une qu�te avant d'�tre une interaction.
local CURSOR_KEYWORDS = {
	{ "gather",    "herb" },
	{ "mine",      "ore" },
	{ "quest",     "quest" },
	{ "important", "quest" },  -- les qu�tes que le jeu distingue ont leur curseur, sans le mot � quest �
	{ "recurring", "quest" },
	{ "wrapper",   "quest" },
	{ "lootall",   "chest" },
	{ "pickup",    "chest" },
	{ "picklock",  "chest" },
	{ "fishing",   "bobber" },
	{ "mail",      "service" },
	{ "speak",     "service" },
	{ "buy",       "service" },
	{ "trainer",   "service" },
	{ "taxi",      "service" },
	{ "innkeeper", "service" },
	{ "repair",    "service" },
	{ "stable",    "service" },
	{ "interact",  "other" },
	{ "inspect",   "other" },  -- la loupe : un �criteau, un livre
}

-- Renvoie la cat�gorie et l'indicateur "gris�" (variante Unable : interaction impossible
-- pour l'instant) lus dans un nom de curseur
local function ReadCursorName(name)
	if type(name) ~= "string" then return nil end
	name = name:lower()
	local blocked = name:find("unable", 1, true) ~= nil
	for _, entry in ipairs(CURSOR_KEYWORDS) do
		if name:find(entry[1], 1, true) then return entry[2], blocked end
	end
	return nil, blocked
end

-- Renvoie : l'objet a-t-il une ic�ne de curseur, sa cat�gorie, gris�e ou non, et le nom
-- brut du curseur (pour le debug)
local function ReadCursor(unit)
	if not SafeCall(SetUnitCursorTexture, probe, unit, nil, true) then return false end
	local texture = probe:GetTexture()
	local atlas = probe.GetAtla…12181 tokens truncated…lages synchronis�s avec le compte peuvent arriver apr�s PLAYER_LOGIN et
-- �craser nos valeurs : on les r�applique � ces moments-l�.
function handlers.VARIABLES_LOADED()
	if db.enabled then ApplyCVars() end
end

function handlers.PLAYER_ENTERING_WORLD()
	if db.enabled then ApplyCVars() end
end

function handlers.PLAYER_LOGOUT()
	Release()
	Unmute()
	ReturnCVars()
	leaving = true
end

-- Les CVars ne se touchent plus une fois en combat : juste avant, on rouvre l'affichage
-- natif pour que la wildspark continue d'appara�tre sur les objets crois�s pendant le combat,
-- ou on le referme si le joueur ne veut pas de wildspark en combat.
function handlers.PLAYER_REGEN_DISABLED()
	-- Do not open the native interaction nameplate gate for combat. It applies
	-- to every soft-interaction target, including NPCs and corpses; CVars become
	-- locked once combat begins.
	if db.enabled then SetGate(false) end
	inCombat = true
end

function handlers.PLAYER_REGEN_ENABLED()
	inCombat = false
	if pendingCVars == "apply" then ApplyCVars()
	elseif pendingCVars == "restore" then RestoreCVars() end
	pendingCVars = false
	if ns.AutoPushSpells then ns.AutoPushSpells.Notify() end
	Evaluate()
end

function handlers.NAME_PLATE_UNIT_ADDED(unit)
	activeUnits[unit] = true
	Evaluate()
end

function handlers.NAME_PLATE_UNIT_REMOVED(unit)
	activeUnits[unit] = nil
	-- la nameplate de la wildspark s'en va : on la dissipe tout de suite, l� o� elle �tait
	local plate = GetNamePlate(unit)
	if plate and plate == glow.anchor then Release() end
end

function handlers.PLAYER_SOFT_INTERACT_CHANGED(oldTarget, newTarget)
	-- une nameplate recycl�e d'une cible � l'autre ne suffit pas � voir le changement
	if not IsSecret(oldTarget) and not IsSecret(newTarget) and oldTarget and newTarget and oldTarget ~= newTarget then
		glow.retarget = glow.anchor ~= nil and not glow.preview
	end
	Evaluate()
end

function handlers.QUEST_LOG_UPDATE()
	questsDirty = true
end

function handlers.WORLD_CURSOR_TOOLTIP_UPDATE()
	if LearnFromTooltip() then Evaluate() end
end

function handlers.LOOT_READY()
	LearnContainers()
end
handlers.LOOT_OPENED = handlers.LOOT_READY

events:SetScript("OnEvent", function(_, event, ...)
	local handler = handlers[event]
	if handler and not leaving and (db or event == "ADDON_LOADED") then handler(...) end
end)
for event in pairs(handlers) do
	pcall(events.RegisterEvent, events, event)
end

---------------------------------------------------------------------------
-- R�glages
---------------------------------------------------------------------------

-- Replace la wildspark apr�s un changement de r�glage qui touche son accroche
local function Reattach()
	if glow.preview then
		glow.frame:ClearAllPoints()
		glow.frame:SetPoint("CENTER", glow.anchor, "CENTER", 0, Look(glow.category, "offsetY"))
	elseif glow.anchor then
		glow.retarget = true
		Evaluate()
	end
end

-- Remet le nom et l'ic�ne de l'objet en accord avec les r�glages
local function RefreshLabel()
	if glow.preview then
		ShowLabel(nil, SampleName(glow.category), glow.category)
	else
		Evaluate()
	end
end

-- Ce qu'un r�glage oblige � refaire quand il change ; ceux qui n'y figurent pas sont relus
-- � chaque image par l'animation
-- Remet les ic�nes de la minimap (NodeScan.lua) en accord avec les r�glages
local function UpdateNodes()
	if ns.UpdateNodes then ns.UpdateNodes() end
end

local APPLY = {
	offsetY = Reattach, followAlpha = Reattach, silhouette = ApplySilhouette, showName = RefreshLabel, showIcon = RefreshLabel, textSize = RefreshLabel,
	textFont = RefreshLabel,
	hideInCombat = Evaluate, hideInInstance = Evaluate, hideUntrained = Evaluate,
	nodeHerbs = UpdateNodes, nodeOre = UpdateNodes, nodeSize = UpdateNodes, nodeSwitch = UpdateNodes, nodeSwitchYards = UpdateNodes,
}

function APPLY.enabled()
	if db.enabled then
		ApplyCVars()
		Evaluate()
	else
		Release()
		Unmute()
		RestoreCVars()
	end
	UpdateNodes()
end

function APPLY.range()
	if db.enabled then ApplyCVars() end
end
APPLY.arc = APPLY.range

function APPLY.exclusive()
	gateOpen = nil
	Evaluate()
end

function APPLY.debug()
	lastReport = nil
end

function APPLY.language()
	UseLanguage()
	lastReport = nil
	if glow.preview then RefreshLabel() end
	if ns.Retext then ns.Retext() end -- Menu.lua : les textes de la fen�tre
end

-- Pr�vient Menu.lua qu'un r�glage a chang�, que ce soit par le menu ou par une commande
local function Notify()
	if ns.Refresh then ns.Refresh() end
end

-- Valeur d'un r�glage ; pour un r�glage de personnalisation, celle qui vaut pour cette
-- cat�gorie, ou pour tous les objets si aucune n'est donn�e
local function GetOption(key, category)
	if LOOK[key] then return Look(category, key) end
	return Store(key)[key]
end

-- Change un r�glage, born� s'il est num�rique, et en applique les cons�quences. Un r�glage de
-- personnalisation se change pour une cat�gorie, qui en a alors un qui lui est propre, ou pour
-- tous les objets : les cat�gories qui avaient le leur le perdent, pour que � tous � dise vrai.
local function SetOption(key, value, category)
	local limits = LIMITS[key]
	if limits then value = Clamp(math.floor(value + 0.5), limits[1], limits[2]) end
	if not LOOK[key] then
		Store(key)[key] = value
	elseif category then
		local own = db.categorySettings[category] or {}
		-- la valeur de tous les objets n'est pas une valeur propre
		if value == db[key] then own[key] = nil else own[key] = value end
		db.categorySettings[category] = next(own) ~= nil and own or nil
	else
		db[key] = value
		for name, own in pairs(db.categorySettings) do
			own[key] = nil
			if next(own) == nil then db.categorySettings[name] = nil end
		end
	end
	if APPLY[key] then APPLY[key]() end
	Notify()
end

-- Une cat�gorie a-t-elle des r�glages de personnalisation qui lui sont propres ?
local function HasOwnSettings(category)
	return db.categorySettings[category] ~= nil
end

-- Retire � une cat�gorie ses r�glages propres : elle reprend ceux de tous les objets
local function ClearOwnSettings(category)
	db.categorySettings[category] = nil
	ApplySilhouette()
	Reattach()
	if glow.preview then ShowLabel(nil, SampleName(glow.category), glow.category) end
	Notify()
end

local function IsCategoryShown(key)
	return cdb.categories[key]
end

local function SetCategory(key, shown)
	cdb.categories[key] = shown
	Evaluate()
	Notify()
end

-- Change la couleur d'une cat�gorie ; sans couleur, lui rend celle d'origine. La wildspark en cours
-- y vient en fondu.
local function SetColor(category, r, g, b)
	local color, default = db.colors[category], DEFAULTS.colors[category]
	color[1] = Clamp(r or default[1], 0, 1)
	color[2] = Clamp(g or default[2], 0, 1)
	color[3] = Clamp(b or default[3], 0, 1)
	if glow.anchor and glow.category == category then glow.targetR, glow.targetG, glow.targetB = Color(category) end
	Notify()
end

-- Affiche ou masque le contour de la zone d�coup�e autour du personnage (jamais sauvegard�)
local function ShowZone(shown)
	silhouette.show = shown
	ApplySilhouette()
	Notify()
end

-- Nom de l'objet du d�cor vis� en ce moment, mis en lumi�re ou non
local function TargetName()
	local unit = ResolveTarget()
	if unit and SafeCall(UnitIsGameObject, unit) == true then return SafeCall(UnitName, unit) end
end

-- �carte un objet par son nom, ou cesse de l'�carter. Renvoie true s'il est d�sormais �cart�,
-- false s'il ne l'est plus, nil si ce n'est pas un nom.
local function ToggleIgnored(name)
	local key = type(name) == "string" and NameKey(name) or ""
	if key == "" then return nil end
	db.ignored[key] = not db.ignored[key] and name or nil
	lastReport = nil
	Evaluate()
	Notify()
	return db.ignored[key] ~= nil
end

-- �carte l'objet vis�, ou cesse de l'�carter, en l'annon�ant
local function IgnoreTarget()
	local name = TargetName()
	if not name then
		Print(L.MSG_IGNORE_NO_TARGET)
	else
		Print((ToggleIgnored(name) and L.MSG_IGNORED or L.MSG_UNIGNORED):format(name))
	end
end

-- Noms des objets �cart�s, par ordre alphab�tique
local function IgnoredNames()
	local names = {}
	for _, name in pairs(db.ignored) do names[#names + 1] = name end
	table.sort(names)
	return names
end

-- L'activation, la langue, le bouton de la minimap, ce que Wildspark a appris des infobulles et des
-- objets approch�s et les objets �cart�s ne sont pas des r�glages de la wildspark : la remise � z�ro
-- n'y touche pas
local KEPT_ON_RESET = { enabled = true, language = true, minimap = true, questObjects = true, ignored = true, nodeNames = true,
	containers = true }

local function ResetTo(defaults, store)
	for key, value in pairs(defaults) do
		if not KEPT_ON_RESET[key] then
			if type(value) == "table" then
				store[key] = {}
				CopyDefaults(value, store[key])
			else
				store[key] = value
			end
		end
	end
end

-- Remet les r�glages du compte et ceux de ce personnage � leurs valeurs d'origine
local function ResetOptions()
	ResetTo(DEFAULTS, db)
	ResetTo(CHAR_DEFAULTS, cdb)
	if ns.AutoPushSpells then ns.AutoPushSpells.Notify() end
	silhouette.show = false
	ApplySilhouette()
	gateOpen, lastReport = nil, nil
	if db.enabled then ApplyCVars() end
	Reattach()
	RefreshLabel()
	UpdateNodes()
	Notify()
end

-- Active ou d�sactive Wildspark en l'annon�ant : sans le menu sous les yeux, rien d'autre ne le dit
local function Toggle(enabled)
	SetOption("enabled", enabled)
	Print(enabled and L.MSG_ENABLED or L.MSG_DISABLED)
end

-- Ce dont les fichiers suivants se servent
ns.SafeCall, ns.IsSecret, ns.NameKey, ns.Flag = SafeCall, IsSecret, NameKey, Flag
ns.LIMITS, ns.CATEGORY_ORDER, ns.Print = LIMITS, CATEGORY_ORDER, Print
ns.GetOption, ns.SetOption, ns.IsCategoryShown, ns.SetCategory = GetOption, SetOption, IsCategoryShown, SetCategory
ns.HasOwnSettings, ns.ClearOwnSettings, ns.GetColor, ns.SetColor = HasOwnSettings, ClearOwnSettings, Color, SetColor
ns.IgnoreTarget, ns.IgnoredNames = IgnoreTarget, IgnoredNames
ns.Toggle, ns.ResetOptions, ns.ShowZone = Toggle, ResetOptions, ShowZone
ns.StartPreview, ns.StopPreview = StartPreview, StopPreview

function ns.IsPreviewing()
	return glow.preview ~= nil
end

-- �tat que montre l'aper�u en cours, ou nil
function ns.PreviewState()
	return glow.preview and glow.state
end

function ns.IsZoneShown()
	return silhouette.show == true
end

-- Raison pour laquelle la d�coupe est indisponible sur ce client, ou nil
local function SilhouetteFailure()
	return silhouette.failed and L[silhouette.failed]
end
ns.SilhouetteFailure = SilhouetteFailure

---------------------------------------------------------------------------
-- Touche d'interaction
---------------------------------------------------------------------------

-- Ramasser, cueillir ou activer l'objet vis� est une action prot�g�e : seul un raccourci du
-- jeu peut la d�clencher, pas le code d'un addon. Wildspark n'a donc pas de raccourci � lui : il
-- donne acc�s � celui du jeu, "Interagir avec la cible", qui agit sur la cible d'interaction.
local INTERACT = "INTERACTTARGET"

local function BindingContext()
	return C_KeyBindings and C_KeyBindings.GetBindingContextForAction
		and SafeCall(C_KeyBindings.GetBindingContextForAction, INTERACT)
end

-- Renvoie la touche principale du raccourci d'interaction, ou nil
local function GetInteractKey()
	return (GetBindingKey(INTERACT, nil, BindingContext()))
end

-- Nom d'une touche tel que le jeu l'affiche
local function KeyText(key)
	return GetBindingText and GetBindingText(key) or key
end

-- Renvoie le nom du raccourci, autre que celui d'interaction, auquel cette touche sert d�j�
local function KeyOwner(key)
	local action = GetBindingAction(key, nil, BindingContext())
	if type(action) ~= "string" or action == "" or action == INTERACT then return nil end
	return _G["BINDING_NAME_" .. action] or action
end

-- Donne cette touche au raccourci d'interaction, � la place de sa touche principale ; nil la
-- lui retire. Le raccourci qui s'en servait la perd. Renvoie false et la raison quand rien
-- n'a pu changer.
local function SetInteractKey(key)
	if InCombatLockdown() then return false, L.MSG_KEY_COMBAT end
	local context = BindingContext()
	local first, second = GetBindingKey(INTERACT, nil, context)
	-- comme le fait le jeu : tout retirer, puis remettre les touches dans l'ordre
	if first then SetBinding(first, nil, context) end
	if second then SetBinding(second, nil, context) end
	local bound = key == nil or SetBinding(key, INTERACT, context)
	if not bound and first then SetBinding(first, INTERACT, context) end
	if second and second ~= key then SetBinding(second, INTERACT, context) end
	local save = SaveBindings or AttemptToSaveBindings
	if save and GetCurrentBindingSet then pcall(save, GetCurrentBindingSet()) end
	Notify()
	if not bound then return false, L.MSG_KEY_REFUSED:format(key) end
	return true
end

ns.GetInteractKey, ns.SetInteractKey, ns.KeyOwner, ns.KeyText = GetInteractKey, SetInteractKey, KeyOwner, KeyText

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------

-- Mot tap� -> nom anglais de la commande ou de l'effet : ceux de la langue affich�e, et le
-- nom affich� de chaque effet. Les noms anglais r�pondent toujours.
local ALIASES = {}

function UseLanguage()
	ns.UseLanguage(db.language)
	for word in pairs(ALIASES) do ALIASES[word] = nil end
	for word, command in pairs(L.COMMANDS) do ALIASES[Fold(word)] = command end
	for _, key in ipairs(ns.EFFECT_ORDER) do ALIASES[Fold(EffectLabel(key))] = key end
	for _, key in ipairs(ns.FontChoices()) do ALIASES[Fold(ns.FontName(key) or L.FONT_GAME)] = key end
end

-- Remplace {r�glage} par ses bornes et {r�glage=} par sa valeur par d�faut
local function Fill(text)
	return (text:gsub("{(%w+)(=?)}", function(key, default)
		if default == "=" then
			if DEFAULTS[key] ~= nil then return tostring(DEFAULTS[key]) end
			return tostring(CHAR_DEFAULTS[key])
		end
		return LIMITS[key][1] .. ".." .. LIMITS[key][2]
	end))
end

local function ShowHelp()
	Print(L.HELP_HEADER)
	for _, line in ipairs(L.HELP) do print("  " .. Fill(line)) end
	print("  /wildspark leash - open mob leash timer settings")
	print("  /wildspark leash test - preview the timer display")
	print("  /wildspark place - place a newly learned spell in an empty action slot")
	print("  /wildspark buffs - open the WildBuffs settings")
end

-- Chaque commande re�oit son argument, et le nombre qu'il repr�sente s'il en est un. Celle
-- qui renvoie false n'a pas su quoi en faire : l'aide s'affiche � sa place.
local COMMANDS = {}

function COMMANDS.menu()
	if ns.ToggleMenu then ns.ToggleMenu() end
end
COMMANDS[""] = COMMANDS.menu

function COMMANDS.leash(arg)
	if SlashCmdList and SlashCmdList.LEASHHELPER then SlashCmdList.LEASHHELPER(arg or "")
	else Print("leash timer is still loading.") end
end

function COMMANDS.buffs()
	if _G.WildBuffs and _G.WildBuffs.OpenOptions then _G.WildBuffs.OpenOptions()
	else Print("WildBuffs is not available for this class.") end
end

function COMMANDS.minimap()
	if not ns.ShowMinimapButton then return end
	ns.ShowMinimapButton(db.minimap.hide)
	Print(L.SETTING:format(L.MINIMAP, Flag(not db.minimap.hide)))
end

function COMMANDS.on() Toggle(true) end
function COMMANDS.off() Toggle(false) end

-- Ouvre ou ferme la fen�tre d'aper�u (Preview.lua)
function COMMANDS.preview()
	if ns.TogglePreview then ns.TogglePreview() end
end

function COMMANDS.place()
	if ns.AutoPushSpells then Print("Drag the spell from the Spellbook to an empty action slot; existing buttons must not be replaced.") end
end

-- Un mot tap� d�signe-t-il une cat�gorie ? Renvoie son nom anglais.
local function CategoryArg(word)
	local category = ALIASES[word] or word
	return DEFAULTS.colors[category] and category
end

-- Les r�glages de personnalisation se donnent � tous les objets ("/wildspark size 150") ou � une
-- cat�gorie nomm�e d'abord ("/wildspark size ore 150"). Renvoie cette cat�gorie, ou nil, et le
-- reste de l'argument.
local function Scoped(arg)
	local first, rest = arg:match("^(%S*)%s*(.-)$")
	local category = CategoryArg(first)
	if category then return category, rest end
	return nil, arg
end

-- Nom d'un r�glage dans une annonce, suivi de la cat�gorie pour laquelle il vient de changer
local function Named(text, category)
	return category and L.OF_CATEGORY:format(text, CategoryLabel(category)) or text
end

-- Sans effet reconnu, la commande liste les effets et rappelle celui en place
function COMMANDS.effect(arg)
	local category, rest = Scoped(arg)
	local key = ALIASES[rest] or rest
	if key ~= "fallback" and EFFECTS[key] then
		SetOption("effect", key, category)
		Print(L.SETTING:format(Named(L.EFFECT, category), EffectLabel(key)))
	else
		local names = {}
		for index, name in ipairs(ns.EFFECT_ORDER) do names[index] = EffectLabel(name) end
		Print(L.MSG_EFFECTS:format(table.concat(names, ", "), EffectLabel(Look(category, "effect"))))
	end
end

-- "/wildspark color ore ff8800" colore une cat�gorie, "/wildspark color ore default" lui rend sa couleur
-- d'origine ; sans couleur, la commande rappelle celle en place
function COMMANDS.color(arg)
	local category, rest = Scoped(arg)
	if not category then return false end
	local r, g, b = rest:match("^#?(%x%x)(%x%x)(%x%x)$")
	if r then
		SetColor(category, tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
	elseif (ALIASES[rest] or rest) == "default" then
		SetColor(category)
	elseif rest ~= "" then
		return false
	end
	r, g, b = Color(category)
	local hex = ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
	Print(L.MSG_COLOR:format(CategoryLabel(category), "|cff" .. hex .. hex .. "|r"))
end

-- "/wildspark shared ore" retire � une cat�gorie ses r�glages propres
function COMMANDS.shared(arg)
	local category = CategoryArg(arg)
	if not category then return false end
	ClearOwnSettings(category)
	Print(L.MSG_SHARED:format(CategoryLabel(category)))
end

-- Commande d'un r�glage num�rique, annonc� sous le nom et le format qu'il a dans le menu :
-- `name` et `pattern` nomment des textes ("%d" � d�faut de format)
local function NumberCommand(key, name, pattern)
	return function(arg)
		local category, rest = Scoped(arg)
		local number = tonumber(rest)
		if not number then return false end
		SetOption(key, number, category)
		Print(L.SETTING:format(Named(L[name], category), (pattern and L[pattern] or "%d"):format(GetOption(key, category))))
	end
end

COMMANDS.size = NumberCommand("size", "SIZE")
COMMANDS.intensity = NumberCommand("intensity", "INTENSITY", "FORMAT_PERCENT")
COMMANDS.offset = NumberCommand("offsetY", "OFFSET")
COMMANDS.text = NumberCommand("textSize", "TEXT_SIZE", "FORMAT_PERCENT")

-- "/wildspark font morpheus", "/wildspark font ore default" ; sans police reconnue, la commande liste
-- celles que le client propose et rappelle celle en place
function COMMANDS.font(arg)
	local category, rest = Scoped(arg)
	local key = ALIASES[rest] or rest
	if key == "default" then key = "game" end
	local choices = ns.FontChoices()
	for _, choice in ipairs(choices) do
		if choice == key then
			SetOption("textFont", key, category)
			Print(L.SETTING:format(Named(L.FONT, category), ns.FontName(key) or L.FONT_GAME))
			return
		end
	end
	local names = {}
	for index, choice in ipairs(choices) do names[index] = ns.FontName(choice) or L.FONT_GAME end
	Print(L.MSG_FONTS:format(table.concat(names, ", "), ns.FontName(Look(category, "textFont")) or L.FONT_GAME))
end

-- Commande d'un r�glage oui/non de personnalisation, annonc� sous le nom qu'il a dans le menu
local function LookToggle(key, name)
	return function(arg)
		local category, rest = Scoped(arg)
		if rest ~= "" then return false end
		SetOption(key, not Look(category, key), category)
		Print(L.SETTING:format(Named(L[name], category), Flag(Look(category, key))))
	end
end

COMMANDS.fade = LookToggle("followAlpha", "FADE")
COMMANDS.name = LookToggle("showName", "SHOW_NAME")
COMMANDS.icon = LookToggle("showIcon", "SHOW_ICON")

-- Commande d'un r�glage oui/non, annonc� par le texte de ce nom, o� s'ins�re "oui" ou "non"
local function ToggleCommand(key, message)
	return function()
		SetOption(key, not GetOption(key))
		Print(L[message]:format(Flag(GetOption(key))))
	end
end

COMMANDS.combat = ToggleCommand("hideInCombat", "MSG_HIDE_COMBAT")
COMMANDS.instance = ToggleCommand("hideInInstance", "MSG_HIDE_INSTANCE")
COMMANDS.unavailable = ToggleCommand("hideLocked", "MSG_HIDE_LOCKED")
COMMANDS.profession = ToggleCommand("hideUntrained", "MSG_HIDE_UNTRAINED")

-- Sans argument, �carte l'objet vis� (ou cesse de l'�carter) ; "list" donne les objets �cart�s,
-- "clear" les oublie tous ; tout autre argument est le nom d'un objet
function COMMANDS.ignore(arg)
	if arg == "" then
		IgnoreTarget()
	elseif arg == "list" then
		local names = IgnoredNames()
		Print(#names > 0 and L.MSG_IGNORE_LIST:format(table.concat(names, ", ")) or L.MSG_IGNORE_EMPTY)
	elseif arg == "clear" then
		for key in pairs(db.ignored) do db.ignored[key] = nil end
		lastReport = nil
		Evaluate()
		Notify()
		Print(L.MSG_IGNORE_EMPTY)
	else
		local known = db.ignored[NameKey(arg)]
		local ignored = ToggleIgnored(arg)
		if ignored == nil then return false end
		Print((ignored and L.MSG_IGNORED or L.MSG_UNIGNORED):format(known or arg))
	end
end

function COMMANDS.exclusive()
	SetOption("exclusive", not db.exclusive)
	Print(db.exclusive and L.MSG_EXCLUSIVE_ON or L.MSG_EXCLUSIVE_OFF)
end

function COMMANDS.silhouette(arg)
	local size, shift = arg:match("^(%d+)%s*(%-?%d*)$")
	local category = CategoryArg(arg)
	if arg == "" or category then
		SetOption("silhouette", not Look(category, "silhouette"), category)
		local on = Look(category, "silhouette")
		if category then
			Print(L.SETTING:format(Named(L.SILHOUETTE, category), Flag(on)))
		else
			Print(on and L.MSG_SILHOUETTE_ON or L.MSG_SILHOUETTE_OFF)
		end
		if on and silhouette.failed then Print(L.MSG_CUTOUT_UNAVAILABLE:format(SilhouetteFailure())) end
	elseif arg == "show" then
		ShowZone(not silhouette.show)
		Print(silhouette.failed and L.MSG_CUTOUT_UNAVAILABLE:format(SilhouetteFailure())
			or silhouette.show and L.MSG_ZONE_SHOWN or L.MSG_ZONE_HIDDEN)
	elseif size then
		SetOption("bodyScale", tonumber(size))
		if shift ~= "" and shift ~= "-" then SetOption("bodyShift", tonumber(shift)) end
		Print(L.MSG_SILHOUETTE_VALUES:format(cdb.bodyScale, cdb.bodyShift))
	else
		Print(Fill(L.MSG_SILHOUETTE_USAGE))
	end
end

function COMMANDS.range(_, number)
	if not number then return false end
	SetOption("range", number)
	local applied = tonumber(GetCVarValue("SoftTargetInteractRange"))
	if pendingCVars == "apply" then
		Print(L.MSG_RANGE_COMBAT:format(db.range))
	elseif db.enabled and applied and applied ~= WantedRange() then
		Print(L.MSG_RANGE_CLIENT:format(db.range, tostring(applied)))
	else
		Print(L.MSG_RANGE:format(db.range))
	end
end

function COMMANDS.arc(_, number)
	if not number then return false end
	SetOption("arc", number)
	Print(L.SETTING:format(L.DIRECTION, L["ARC_" .. db.arc]))
end

-- Sans argument, montre la touche d'interaction ; sinon l'assigne ("SHIFT-E"), ou la retire
function COMMANDS.key(arg)
	if arg ~= "" then
		local key
		if arg ~= "none" then key = arg:upper() end
		local owner = key and KeyOwner(key)
		local changed, reason = SetInteractKey(key)
		if not changed then Print(reason) return end
		if owner then Print(L.MSG_KEY_REPLACED:format(KeyText(key), owner)) end
	end
	local key = GetInteractKey()
	Print(L.SETTING:format(L.KEY, key and KeyText(key) or L.KEY_NONE))
end

for _, category in ipairs(CATEGORY_ORDER) do
	COMMANDS[category] = function()
		SetCategory(category, not IsCategoryShown(category))
		Print(L.SETTING:format(CategoryLabel(category), Flag(IsCategoryShown(category))))
	end
end

-- Ic�nes des plantes et des filons sur la minimap (NodeScan.lua). Sans argument, les montre ou
-- les retire toutes ; "ore" ou "herb", celles d'un m�tier ; "size 14" r�gle leur taille.
local NODE_KEYS = { herb = "nodeHerbs", ore = "nodeOre" }
local NODE_TEXTS = { herb = "NODE_HERBS", ore = "NODE_ORE" }

function COMMANDS.nodes(arg)
	if not ns.UpdateNodes then Print(L.MSG_RESTART) return end
	local first, rest = arg:match("^(%S*)%s*(.-)$")
	first = ALIASES[first] or first
	if first == "size" then
		local number = tonumber(rest)
		if not number then return false end
		SetOption("nodeSize", number)
		Print(L.SETTING:format(L.NODE_SIZE, tostring(db.nodeSize)))
		return
	end
	if rest ~= "" or (first ~= "" and not NODE_KEYS[first]) then return false end
	local shown
	if first == "" then shown = not (db.nodeHerbs or db.nodeOre) else shown = not db[NODE_KEYS[first]] end
	for _, kind in ipairs({ "herb", "ore" }) do
		if first == "" or first == kind then
			SetOption(NODE_KEYS[kind], shown)
			Print(L.SETTING:format(L[NODE_TEXTS[kind]], Flag(shown)))
		end
	end
	local failure = ns.NodesFailure()
	if shown and failure then Print(L.MSG_NODES_UNAVAILABLE:format(failure)) end
end

-- Deux m�tiers de r�colte : sans argument, lance ou arr�te l'alternance des deux pistages ; un
-- nombre r�gle la distance parcourue entre deux bascules
function COMMANDS.switch(arg, number)
	if not ns.UpdateNodes then Print(L.MSG_RESTART) return end
	if number then
		SetOption("nodeSwitchYards", number)
		Print(L.SETTING:format(L.NODE_SWITCH_YARDS, L.FORMAT_RANGE:format(cdb.nodeSwitchYards)))
	elseif arg == "" then
		SetOption("nodeSwitch", not cdb.nodeSwitch)
		Print(L.SETTING:format(L.NODE_SWITCH, Flag(cdb.nodeSwitch)))
	else
		return false
	end
end

-- Ce que le dernier balayage de la minimap a lu, et ce que Wildspark en a fait
function COMMANDS.scan()
	if ns.ScanReport then ns.ScanReport() else Print(L.MSG_RESTART) end
end

-- Nom de la langue r�gl�e, tel que le menu le montre
local function LanguageName()
	return db.language == "auto" and L.LANGUAGE_AUTO or ns.LOCALES[db.language].LANGUAGE_NAME
end

-- La langue se d�signe par "auto", par son code ("frFR"), ses deux premi�res lettres ou son nom
function COMMANDS.language(arg)
	local choice
	if arg == "auto" or arg == Fold(L.LANGUAGE_AUTO) then choice = "auto" end
	for code, texts in pairs(ns.LOCALES) do
		if arg == code:lower() or arg == code:sub(1, 2) or arg == Fold(texts.LANGUAGE_NAME) then choice = code end
	end
	if choice then SetOption("language", choice) end
	Print(L.SETTING:format(L.LANGUAGE, LanguageName()))
end

function COMMANDS.debug()
	SetOption("debug", not db.debug)
	Print(L.SETTING:format(L.DEBUG, Flag(db.debug)))
end

-- Ce � quoi le nom d'un objet est compar� pour le reconna�tre comme objet de qu�te
function COMMANDS.objectives()
	RebuildQuestTexts()
	Print(L.OBJECTIVES_HEADER:format(#questTexts))
	for _, objective in ipairs(questTexts) do
		print("  " .. objective.text .. (objective.pickable and "" or L.OBJECTIVES_NOT_ITEM))
	end
	for name, title in pairs(db.questObjects) do
		if questTitles[title] then print("  " .. L.OBJECTIVES_LEARNED:format(name, title)) end
	end
end

function COMMANDS.status()
	local version, build = GetBuildInfo()
	Print(L.STATUS_CLIENT:format(tostring(version), tostring(build), tostring(GetLocale()), LanguageName()))
	for _, names in ipairs({ MANAGED_CVARS, WATCHED_CVARS }) do
		for _, name in ipairs(names) do
			local value = GetCVarValue(name)
			local default
			if C_CVar and C_CVar.GetCVarDefault then default = SafeCall(C_CVar.GetCVarDefault, name) end
			print(("  %s = %s%s"):format(name, value == nil and L.STATUS_CVAR_UNKNOWN or tostring(value),
				default and L.STATUS_CVAR_DEFAULT:format(tostring(default)) or ""))
		end
	end
	print("  " .. L.STATUS_EXPECTED:format(WantedRange(), db.arc))
	print("  " .. L.STATUS_GATE:format(Flag(db.exclusive), gateOpen == nil and "?" or gateOpen and L.GATE_OPEN or L.GATE_CLOSED))
	print("  " .. L.STATUS_SILHOUETTE:format(silhouette.failed and L.STATUS_UNAVAILABLE:format(SilhouetteFailure())
		or Flag(db.silhouette)))
	print("  " .. L.STATUS_DIRECT:format(directWorks and L.YES or L.STATUS_NOT_YET))
	print("  " .. L.STATUS_RANGE_API:format(Flag(UnitIsInInteractRange ~= nil)))
	local fishing, channel, icon = ReadLine()
	print("  " .. L.STATUS_LINE:format(Flag(fishing), channel and ("%s, %s"):format(channel, tostring(icon)) or L.NAME_NONE))
	if ns.NodesFailure then
		local failure = ns.NodesFailure()
		print("  " .. L.STATUS_NODES:format(failure and L.STATUS_UNAVAILABLE:format(failure)
			or L.STATUS_NODES_SHOWN:format(Flag(db.nodeHerbs), Flag(db.nodeOre), Flag(cdb.nodeSwitch))))
	end
	print("  " .. L.STATUS_TRAINED:format(Flag(db.hideUntrained), Flag(Trained("herb")), Flag(Trained("ore"))))
	print("  " .. L.STATUS_HIDE:format(Flag(db.hideInCombat), Flag(db.hideInInstance), Flag(db.hideLocked), Flag(Paused())))
	local shown = {}
	for _, category in ipairs(CATEGORY_ORDER) do
		if cdb.categories[category] then shown[#shown + 1] = CategoryName(category) end
	end
	print("  " .. L.STATUS_OBJECTS:format(#shown > 0 and table.concat(shown, ", ") or L.NAME_NONE, #IgnoredNames()))
	local own = {}
	for _, category in ipairs(CATEGORY_ORDER) do
		if HasOwnSettings(category) then own[#own + 1] = CategoryName(category) end
	end
	print("  " .. L.STATUS_OWN:format(#own > 0 and table.concat(own, ", ") or L.NAME_NONE))
	local key = GetInteractKey()
	print("  " .. L.STATUS_KEY:format(key and KeyText(key) or L.KEY_NONE))
	local effect = EFFECTS[db.effect]
	print("  " .. L.STATUS_EFFECT:format(EffectLabel(db.effect),
		effect.missing and L.TEXTURES_MISSING or effect.fx and L.TEXTURES_LOADED or L.TEXTURES_PENDING))
end

COMMANDS.help = ShowHelp

SLASH_WILDSPARK1 = "/wildspark"
SlashCmdList.WILDSPARK = function(input)
	local cmd, arg = Fold(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local command = COMMANDS[ALIASES[cmd] or cmd]
	if not command or command(ALIASES[arg] or arg, tonumber(arg)) == false then ShowHelp() end
end
