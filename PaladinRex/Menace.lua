-- Paladin Rex, menace (WoW 3.3.5a) : tableau de la menace du groupe sur ta cible et alertes d'aggro.
-- Tank (/pala tank ou Fureur vertueuse active) : « AGGRO PERDUE » avec la victime et la provocation disponible.
-- Sinon : alerte à 85 % de menace, et quand tu prends l'aggro en groupe (Main de salut conseillée).
-- Touches (Raccourcis, Paladin Rex) : Main de rétribution sur la cible, Défense vertueuse sur l'allié frappé par ta cible.
-- Commande : /pala menace (afficher ou masquer le tableau).

local ADDON, ns = ...

_G["BINDING_NAME_CLICK PaladinRexProvocation:LeftButton"] = "Aggro : Main de rétribution (cible)"
_G["BINDING_NAME_CLICK PaladinRexDefense:LeftButton"] = "Aggro : Défense vertueuse (allié frappé par ta cible)"

if select(2, UnitClass("player")) ~= "PALADIN" then return end

local PROVOCATION, DEFENSE, SALUT = 62124, 31789, 1038
local MAX = 6
local pret, apresCombat, dejaAlerte = false, false, false

local function db()
  PaladinRexDB = PaladinRexDB or {}
  PaladinRexDB.menace = PaladinRexDB.menace or {}
  local d = PaladinRexDB.menace
  if d.afficher == nil then d.afficher = true end
  return d
end

local function infoSort(id)
  local nom, _, icone = GetSpellInfo(id)
  return nom, icone
end

-- Sort appris et prêt (hors temps global).
local function disponible(nom)
  if not nom or not GetSpellInfo(nom) then return false end
  local debut, duree = GetSpellCooldown(nom)
  if not debut then return false end
  return (duree or 0) <= 1.5 or debut + duree - GetTime() <= 0.2
end

local function enGroupe()
  return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

local function unites()
  local l = { "player", "pet" }
  local nr = GetNumRaidMembers()
  if nr > 0 then
    for i = 1, nr do
      l[#l + 1] = "raid" .. i
      l[#l + 1] = "raidpet" .. i
    end
  else
    for i = 1, GetNumPartyMembers() do
      l[#l + 1] = "party" .. i
      l[#l + 1] = "partypet" .. i
    end
  end
  return l
end

-- Tableau de menace
local cadre = CreateFrame("Frame", "PaladinRexMenace", UIParent)
cadre:SetSize(210, 26 + MAX * 16)
cadre:SetFrameStrata("MEDIUM")
cadre:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
cadre:SetBackdropColor(0, 0, 0, 0.7)
cadre:SetBackdropBorderColor(0.96, 0.55, 0.73, 0.9)
cadre:SetClampedToScreen(true)
cadre:SetMovable(true)
cadre:EnableMouse(true)
cadre:RegisterForDrag("LeftButton")
cadre:SetScript("OnDragStart", function(self)
  if not (PaladinRexDB and PaladinRexDB.verrou) then self:StartMoving() end
end)
cadre:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  db().pos = { p, rp, x, y }
end)
cadre:Hide()

local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titre:SetPoint("TOPLEFT", 8, -6)
titre:SetPoint("RIGHT", -8, 0)
titre:SetJustifyH("LEFT")

local barres = {}
for k = 1, MAX do
  local b = CreateFrame("StatusBar", nil, cadre)
  b:SetSize(194, 14)
  b:SetPoint("TOPLEFT", 8, -20 - (k - 1) * 16)
  b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  b:SetMinMaxValues(0, 100)
  b.fond = b:CreateTexture(nil, "BACKGROUND")
  b.fond:SetAllPoints()
  b.fond:SetTexture(0, 0, 0, 0.4)
  b.nom = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.nom:SetPoint("LEFT", 3, 0)
  b.pct = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.pct:SetPoint("RIGHT", -3, 0)
  b:Hide()
  barres[k] = b
end

-- Alerte au centre
local alerte = CreateFrame("Frame", "PaladinRexAggroAlerte", UIParent)
alerte:SetSize(500, 40)
alerte:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
alerte:SetFrameStrata("HIGH")
alerte.texte = alerte:CreateFontString(nil, "OVERLAY")
alerte.texte:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
alerte.texte:SetPoint("CENTER", 18, 0)
alerte.icone = alerte:CreateTexture(nil, "ARTWORK")
alerte.icone:SetSize(32, 32)
alerte.icone:SetPoint("RIGHT", alerte.texte, "LEFT", -8, 0)
alerte:Hide()

-- Boutons sans cadre pour les touches : provocation sur la cible, défense vertueuse sur la victime de la cible.
local function boutonCache(nom, id, unite)
  local b = CreateFrame("Button", nom, UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp")
  b:Hide()
  b.id, b.unite = id, unite
  return b
end
local boutonsCaches = {
  boutonCache("PaladinRexProvocation", PROVOCATION, "target"),
  boutonCache("PaladinRexDefense", DEFENSE, "targettarget"),
}

local function configurerBoutons()
  if InCombatLockdown() then apresCombat = true return end
  for _, b in ipairs(boutonsCaches) do
    local nom = infoSort(b.id)
    if nom then
      b:SetAttribute("type", "spell")
      b:SetAttribute("spell", nom)
      b:SetAttribute("unit", b.unite)
    end
  end
end

local function placer()
  local d = db()
  cadre:ClearAllPoints()
  if d.pos then
    cadre:SetPoint(d.pos[1], UIParent, d.pos[2], d.pos[3], d.pos[4])
  else
    cadre:SetPoint("CENTER", UIParent, "CENTER", 380, 120)
  end
end

local function couleurClasse(classe)
  local c = classe and RAID_CLASS_COLORS[classe]
  if c then return c.r, c.g, c.b end
  return 0.6, 0.6, 0.6
end

local function majTableau()
  local d = db()
  local actif = d.afficher and UnitExists("target") and UnitCanAttack("player", "target")
    and not UnitIsDeadOrGhost("target") and (enGroupe() or UnitExists("pet"))
  if not actif then
    cadre:Hide()
    return
  end
  local liste, vus = {}, {}
  for _, u in ipairs(unites()) do
    local guid = UnitExists(u) and UnitGUID(u)
    if guid and not vus[guid] then
      vus[guid] = true
      local tanking, _, pct = UnitDetailedThreatSituation(u, "target")
      if tanking or (pct and pct > 0) then
        liste[#liste + 1] = {
          nom = UnitName(u), pct = tanking and 100 or pct, tanking = tanking, moi = UnitIsUnit(u, "player"),
          classe = UnitIsPlayer(u) and select(2, UnitClass(u)) or nil,
        }
      end
    end
  end
  if #liste == 0 then
    cadre:Hide()
    return
  end
  table.sort(liste, function(a, b) return a.pct > b.pct end)
  titre:SetText("Menace : " .. (UnitName("target") or "?"))
  for k, b in ipairs(barres) do
    local e = liste[k]
    if e then
      b:SetValue(math.min(100, e.pct))
      b:SetStatusBarColor(couleurClasse(e.classe))
      b.nom:SetText((e.tanking and "> " or "") .. (e.nom or "?"))
      b.nom:SetTextColor(1, 1, e.moi and 0.3 or 1)
      b.pct:SetText(string.format("%d %%", e.pct))
      b:Show()
    else
      b:Hide()
    end
  end
  cadre:SetHeight(26 + math.min(#liste, MAX) * 16)
  cadre:Show()
end

-- Renvoie texte, icône, couleur et urgence de l'alerte du moment.
local function choisirAlerte()
  if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsPlayer("target")
    or UnitIsDeadOrGhost("target") or not UnitAffectingCombat("target") then
    return nil
  end
  local tanking, _, pct = UnitDetailedThreatSituation("player", "target")
  if ns.estTank and ns.estTank() then
    if tanking or not UnitExists("targettarget") or UnitIsUnit("targettarget", "player") then return nil end
    local victime = UnitName("targettarget") or "?"
    local nomP, iconeP = infoSort(PROVOCATION)
    local nomD, iconeD = infoSort(DEFENSE)
    if disponible(nomP) then return "AGGRO PERDUE : " .. victime .. " (" .. nomP .. ")", iconeP, 1, 0.2, 0.2, true end
    if disponible(nomD) then return "AGGRO PERDUE : " .. victime .. " (" .. nomD .. ")", iconeD, 1, 0.2, 0.2, true end
    return "AGGRO PERDUE : " .. victime, iconeP, 1, 0.2, 0.2, true
  end
  if not enGroupe() then return nil end
  local nomS, iconeS = infoSort(SALUT)
  if tanking then
    return "TU AS L'AGGRO !" .. (disponible(nomS) and (" (" .. nomS .. " sur toi)") or ""), iconeS, 1, 0.3, 0.3, true
  end
  if pct and pct >= 85 then
    return string.format("MENACE %d %% : ralentis", pct), iconeS, 1, 0.6, 0.1, false
  end
end

local function majAlerte()
  local texte, icone, r, g, b, urgent = choisirAlerte()
  if texte then
    alerte.texte:SetText(texte)
    alerte.texte:SetTextColor(r, g, b)
    alerte.icone:SetTexture(icone)
    alerte:Show()
  else
    alerte:Hide()
  end
  if urgent and not dejaAlerte then PlaySound("RaidWarning") end
  dejaAlerte = urgent and true or false
end

local function tic()
  if not pret then return end
  if ns.modePvP and ns.modePvP() then
    cadre:Hide()
    alerte:Hide()
    return
  end
  majTableau()
  majAlerte()
end

-- Accès depuis PaladinRex.lua
function ns.basculerMenace()
  local d = db()
  d.afficher = not d.afficher
  tic()
  return d.afficher
end
function ns.placerMenace()
  db().pos = nil
  placer()
end

-- Événements
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("PLAYER_LOGIN")
evenements:RegisterEvent("PLAYER_REGEN_ENABLED")
evenements:RegisterEvent("PLAYER_TARGET_CHANGED")
evenements:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_LOGIN" then
    db()
    placer()
    configurerBoutons()
    pret = true
  elseif ev == "PLAYER_REGEN_ENABLED" and apresCombat then
    apresCombat = false
    configurerBoutons()
  end
  tic()
end)

local cumul = 0
evenements:SetScript("OnUpdate", function(_, dt)
  cumul = cumul + dt
  if cumul < 0.25 then return end
  cumul = 0
  tic()
end)
