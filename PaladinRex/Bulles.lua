-- Paladin Rex, bulles (WoW 3.3.5a) : boutons ronds et transparents à côté du personnage pour Bouclier divin,
-- Protection divine et Main de protection. Sous le seuil de vie (15 % par défaut), ils prennent leur couleur
-- et la bulle à lancer clignote (bouclier, sinon main de protection, sinon protection divine).
-- Clic : sur toi ; clic droit sur Main de protection : sur ta cible. Alt + glisser : déplacer.
-- Commandes : /pala bulles (afficher ou masquer), /pala seuil 20 (pourcentage de vie).

local ADDON, ns = ...

local BULLES = {
  { id = 642, libelle = "Bouclier divin" },
  { id = 498, libelle = "Protection divine" },
  { id = 1022, libelle = "Main de protection", cible = true },
}
for i, b in ipairs(BULLES) do
  _G["BINDING_NAME_CLICK PaladinRexBulle" .. i .. ":LeftButton"] = "Bulle : " .. b.libelle .. " (sur moi)"
end

if select(2, UnitClass("player")) ~= "PALADIN" then return end

local PRIORITE = { 1, 3, 2 } -- bouclier divin, puis main de protection, puis protection divine
local LONGANIMITE = 25771
local TAILLE, ECART = 40, 10
local TEX = "Interface\\AddOns\\PaladinRex\\Textures\\"
local pret, apresCombat, enAlerte = false, false, false
local nomLonganimite

local function db()
  PaladinRexDB = PaladinRexDB or {}
  PaladinRexDB.bulles = PaladinRexDB.bulles or {}
  local d = PaladinRexDB.bulles
  if d.afficher == nil then d.afficher = true end
  if d.seuil == nil then d.seuil = 15 end
  return d
end

local function resteLonganimite()
  if not nomLonganimite then return nil end
  for i = 1, 40 do
    local nom, _, _, _, _, _, expire = UnitAura("player", i, "HARMFUL")
    if not nom then return nil end
    if nom == nomLonganimite then return expire and expire > 0 and (expire - GetTime()) or 60 end
  end
end

-- Temps de recharge restant (0 si prêt, temps global ignoré).
local function recharge(nom)
  local debut, duree = GetSpellCooldown(nom)
  if not debut or (duree or 0) <= 1.5 then return 0 end
  return math.max(0, debut + duree - GetTime())
end

-- Cadre à côté du personnage, boutons en colonne.
local cadre = CreateFrame("Frame", "PaladinRexBulles", UIParent)
cadre:SetSize(TAILLE, #BULLES * (TAILLE + ECART) - ECART)
cadre:SetMovable(true)
cadre:SetClampedToScreen(true)
cadre:SetFrameStrata("MEDIUM")

local function placer()
  local p = db().pos
  cadre:ClearAllPoints()
  if p then
    cadre:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    cadre:SetPoint("LEFT", UIParent, "CENTER", 90, -30)
  end
end

local boutons = {}
for i, info in ipairs(BULLES) do
  local b = CreateFrame("Button", "PaladinRexBulle" .. i, cadre, "SecureActionButtonTemplate")
  b:SetSize(TAILLE, TAILLE)
  b:SetPoint("TOP", cadre, "TOP", 0, -(i - 1) * (TAILLE + ECART))
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b.fond = b:CreateTexture(nil, "BACKGROUND")
  b.fond:SetTexture(TEX .. "fond")
  b.fond:SetPoint("CENTER")
  b.fond:SetSize(TAILLE * 1.1, TAILLE * 1.1)
  b.fond:SetVertexColor(0, 0, 0)
  b.icone = b:CreateTexture(nil, "ARTWORK")
  b.icone:SetPoint("CENTER")
  b.icone:SetSize(TAILLE * 0.86, TAILLE * 0.86)
  b.anneau = b:CreateTexture(nil, "OVERLAY")
  b.anneau:SetTexture(TEX .. "anneau")
  b.anneau:SetPoint("CENTER")
  b.anneau:SetSize(TAILLE * 1.1, TAILLE * 1.1)
  b.lueur = b:CreateTexture(nil, "OVERLAY")
  b.lueur:SetTexture(TEX .. "lueur")
  b.lueur:SetBlendMode("ADD")
  b.lueur:SetPoint("CENTER")
  b.lueur:SetSize(TAILLE * 1.9, TAILLE * 1.9)
  b.lueur:SetVertexColor(1, 0.85, 0.3)
  b.lueur:Hide()
  b.texte = b:CreateFontString(nil, "OVERLAY")
  b.texte:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
  b.texte:SetPoint("CENTER")
  b:SetHighlightTexture(TEX .. "lueur", "ADD")
  b.info = info
  b:SetScript("OnDragStart", function()
    if IsAltKeyDown() and not InCombatLockdown() then cadre:StartMoving() end
  end)
  b:SetScript("OnDragStop", function()
    cadre:StopMovingOrSizing()
    local p, _, rp, x, y = cadre:GetPoint()
    db().pos = { p, rp, x, y }
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("spell:" .. self.info.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self.info.cible and "Clic : sur toi ; clic droit : sur ta cible" or "Clic : lancer", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Alt + glisser : déplacer les bulles", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  boutons[i] = b
end

local function configurer()
  if InCombatLockdown() then apresCombat = true return end
  local d = db()
  nomLonganimite = GetSpellInfo(LONGANIMITE)
  local y = 0
  for _, b in ipairs(boutons) do
    local nom, _, icone = GetSpellInfo(b.info.id)
    b.nom = nom and GetSpellInfo(nom) and nom or nil
    if b.nom then
      SetPortraitToTexture(b.icone, icone)
      b:SetAttribute("type1", "spell")
      b:SetAttribute("spell1", b.nom)
      b:SetAttribute("unit1", "player")
      b:SetAttribute("type2", "spell")
      b:SetAttribute("spell2", b.nom)
      b:SetAttribute("unit2", b.info.cible and "target" or "player")
      b:ClearAllPoints()
      b:SetPoint("TOP", cadre, "TOP", 0, y)
      y = y - (TAILLE + ECART)
      b:Show()
    else
      b:SetAttribute("type1", nil)
      b:SetAttribute("type2", nil)
      b:Hide()
    end
  end
  if d.afficher then cadre:Show() else cadre:Hide() end
end

-- Bulle conseillée : la première prête dans l'ordre de priorité, rien sous Longanimité.
local function conseillee(longa)
  if longa then return nil end
  for _, i in ipairs(PRIORITE) do
    local b = boutons[i]
    if b.nom and recharge(b.nom) == 0 and IsUsableSpell(b.nom) then return b end
  end
end

local temps = 0
local function majBulles(dt)
  temps = temps + dt
  local pv = UnitHealth("player") / math.max(1, UnitHealthMax("player"))
  local alerte = not UnitIsDeadOrGhost("player") and pv * 100 <= db().seuil
  if alerte and not enAlerte then PlaySound("RaidWarning") end
  enAlerte = alerte
  local longa = resteLonganimite()
  local choix = alerte and conseillee(longa)
  local pulse = 0.55 + 0.45 * math.sin(temps * 9)
  for _, b in ipairs(boutons) do
    if b.nom then
      local reste = recharge(b.nom)
      local bloque = longa or reste > 0
      if bloque then
        b.texte:SetText(math.ceil(longa or reste))
        b.texte:SetTextColor(longa and 1 or 0.9, longa and 0.3 or 0.9, longa and 0.3 or 0.9)
      else
        b.texte:SetText("")
      end
      if alerte then
        b.icone:SetDesaturated(bloque and true or false)
        b.icone:SetAlpha(bloque and 0.5 or 1)
        b.fond:SetAlpha(0.6)
        if longa then b.anneau:SetVertexColor(1, 0.25, 0.25) else b.anneau:SetVertexColor(1, 0.82, 0.2) end
        b.anneau:SetAlpha(1)
      else
        b.icone:SetDesaturated(true)
        b.icone:SetAlpha(0.35)
        b.fond:SetAlpha(0.2)
        b.anneau:SetVertexColor(0.8, 0.8, 0.8)
        b.anneau:SetAlpha(0.35)
      end
      if b == choix then
        b.lueur:Show()
        b.lueur:SetAlpha(pulse)
        b.icone:SetAlpha(0.6 + 0.4 * pulse)
      else
        b.lueur:Hide()
      end
    end
  end
end

-- Accès depuis PaladinRex.lua
function ns.basculerBulles()
  local d = db()
  d.afficher = not d.afficher
  if InCombatLockdown() then apresCombat = true else configurer() end
  return d.afficher
end
function ns.seuilBulles(n)
  local d = db()
  if n and n >= 1 and n <= 90 then d.seuil = n end
  return d.seuil
end
function ns.placerBulles()
  db().pos = nil
  placer()
end

-- Événements
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("PLAYER_LOGIN")
evenements:RegisterEvent("SPELLS_CHANGED")
evenements:RegisterEvent("PLAYER_REGEN_ENABLED")
evenements:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_LOGIN" then
    db()
    placer()
    configurer()
    pret = true
  elseif ev == "SPELLS_CHANGED" then
    if pret then configurer() end
  elseif ev == "PLAYER_REGEN_ENABLED" and apresCombat then
    apresCombat = false
    configurer()
  end
end)
evenements:SetScript("OnUpdate", function(_, dt)
  if pret and cadre:IsShown() then majBulles(dt) end
end)
