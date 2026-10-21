-- Paladin Rex, mode JcJ : contrôles et défensifs du paladin (WoW 3.3.5a).
-- Barre de sorts avec recharges : clic gauche = cible, clic droit = sur moi (liberté, protection, épuration,
-- imposition des mains, horion). Longanimité affichée sur bouclier divin, protection, imposition et courroux vengeur.
-- Alertes au centre : bouclier divin, liberté, épuration, courroux pour achever, marteau sur incantation.
-- Rendements décroissants des étourdissements sur la cible (estimation) et grosses capacités ennemies.
-- Actif en champ de bataille et en arène (mode auto) ou avec /pala pvp.

local ADDON, ns = ...

local LIBELLES = {
  { "Marteau", "Marteau de la justice" },
  { "Repentir", "Repentir" },
  { "Courroux", "Marteau de courroux" },
  { "Horion", "Horion sacré" },
  { "Liberte", "Main de liberté" },
  { "Protection", "Main de protection" },
  { "Epuration", "Épuration" },
  { "Sacrifice", "Main de sacrifice" },
  { "Bouclier", "Bouclier divin" },
  { "Imposition", "Imposition des mains" },
  { "Vengeur", "Courroux vengeur" },
  { "Maitrise", "Maîtrise des auras" },
  { "Faveur", "Faveur divine" },
}
for _, l in ipairs(LIBELLES) do
  _G["BINDING_NAME_CLICK PaladinRexPvP_" .. l[1] .. ":LeftButton"] = "JcJ : " .. l[2] .. " (cible)"
  _G["BINDING_NAME_CLICK PaladinRexPvP_" .. l[1] .. ":RightButton"] = "JcJ : " .. l[2] .. " (sur moi)"
end

if select(2, UnitClass("player")) ~= "PALADIN" then return end

local SORTS = {
  { cle = "Marteau", ids = { 853 }, ennemi = true },
  { cle = "Repentir", ids = { 20066 }, ennemi = true },
  { cle = "Courroux", ids = { 24275 }, ennemi = true },
  { cle = "Horion", ids = { 20473 }, moi = true },
  { cle = "Liberte", ids = { 1044 }, moi = true },
  { cle = "Protection", ids = { 1022 }, moi = true, longanimite = true },
  { cle = "Epuration", ids = { 4987, 1152 }, moi = true },
  { cle = "Sacrifice", ids = { 6940 } },
  { cle = "Bouclier", ids = { 642, 498 }, longanimite = true },
  { cle = "Imposition", ids = { 633 }, moi = true, longanimite = true },
  { cle = "Vengeur", ids = { 31884 }, longanimite = true },
  { cle = "Maitrise", ids = { 31821 } },
  { cle = "Faveur", ids = { 20216 } },
}
local SORT = {}
for _, s in ipairs(SORTS) do SORT[s.cle] = s end

local LONGANIMITE = 25771
local EPURATION = 4987
-- Racines et ralentissements que la main de liberté enlève.
local ENTRAVES = { 122, 339, 1715, 116, 120, 3409, 2974, 5116, 13810, 12323, 8056, 3600, 15407, 23694,
  6136, 12484, 11113, 18223, 19229, 19185, 19675, 45334, 12494, 1604, 45524, 31589, 26679, 55741, 55080,
  33395, 58179 }
-- Étourdissements contrôlés qui partagent les rendements décroissants du marteau de la justice.
local ETOURDISSEMENTS = { 853, 1833, 408, 7922, 20253, 5211, 9005, 22570, 12809, 20549, 24394, 30283,
  46968, 47481, 44572 }
-- Capacités ennemies à signaler.
local ENNEMIS = { 11958, 642, 1022, 5277, 1856, 7744, 59752, 20594, 20589, 58984, 871, 1719, 12292, 29166,
  10060, 12042, 11129, 12472, 17116, 13750, 2983, 19574, 34471, 14177, 1044, 6346, 22812, 61336, 19263,
  31224, 33206, 47585, 48707, 48792, 49039, 46924, 23920, 31884, 2825, 32182 }
local DR_RESET = 18

local connus = {}
local entraves, etourdissements, ennemis = {}, {}, {}
local nomLonganimite, nomEpuration
local dr, vus = {}, {}
local pret, apresCombat = false, false

-- Réglages JcJ rangés dans PaladinRexDB.pvp ; verrou et affichage communs au mode PvE.
local function db()
  PaladinRexDB = PaladinRexDB or {}
  PaladinRexDB.pvp = PaladinRexDB.pvp or {}
  local d = PaladinRexDB.pvp
  if d.alertes == nil then d.alertes = true end
  return d
end

local function modeActif()
  return ns.modePvP and ns.modePvP() or false
end

local function infoSort(id)
  local nom, _, icone = GetSpellInfo(id)
  return nom, icone
end

-- UnitAura en 3.3.5 : nom, rang, icône, charges, type, durée, expiration.
local function aura(unit, i, filtre)
  local nom, _, _, _, typ, _, expire = UnitAura(unit, i, filtre)
  return nom, expire, typ
end

local function recharge(nom)
  local debut, duree = GetSpellCooldown(nom)
  return debut or 0, duree or 0
end

local function horsPortee(nom, unit)
  return IsSpellInRange(nom, unit) == 0
end

-- Prêt : pas de recharge (hors temps global) et utilisable (mana, forme).
local function disponible(nom)
  local debut, duree = recharge(nom)
  if duree <= 1.5 or debut + duree - GetTime() <= 0.2 then
    return IsUsableSpell(nom) and true or false
  end
  return false
end

local function lireGrimoire()
  wipe(connus)
  for i = 1, 1000 do
    local nom = GetSpellName(i, BOOKTYPE_SPELL or "spell")
    if not nom then break end
    connus[nom] = true
  end
end

local function ensembleNoms(ids, t)
  wipe(t)
  for _, id in ipairs(ids) do
    local nom = infoSort(id)
    if nom then t[nom] = true end
  end
end

local function preparerNoms()
  ensembleNoms(ENTRAVES, entraves)
  ensembleNoms(ETOURDISSEMENTS, etourdissements)
  ensembleNoms(ENNEMIS, ennemis)
  nomLonganimite = infoSort(LONGANIMITE)
  nomEpuration = infoSort(EPURATION)
end

-- Barre
local barre = CreateFrame("Frame", "PaladinRexPvPBarre", UIParent)
barre:SetSize(200, 72)
barre:SetFrameStrata("MEDIUM")
barre:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
barre:SetBackdropColor(0, 0, 0, 0.7)
barre:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.9)
barre:SetClampedToScreen(true)
barre:SetMovable(true)
barre:EnableMouse(true)
barre:RegisterForDrag("LeftButton")
barre:SetScript("OnDragStart", function(self)
  if not (PaladinRexDB and PaladinRexDB.verrou) and not InCombatLockdown() then self:StartMoving() end
end)
barre:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  db().pos = { p, rp, x, y }
end)
barre:Hide()

local titre = barre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titre:SetPoint("TOPLEFT", 8, -5)
titre:SetText("Paladin Rex JcJ")
local drTexte = barre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
drTexte:SetPoint("BOTTOMLEFT", 8, 6)

local boutons = {}
for _, s in ipairs(SORTS) do
  local b = CreateFrame("Button", "PaladinRexPvP_" .. s.cle, barre, "SecureActionButtonTemplate")
  b:SetSize(36, 36)
  b:RegisterForClicks("AnyUp")
  b.icone = b:CreateTexture(nil, "ARTWORK")
  b.icone:SetAllPoints()
  b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints()
  b.texte = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.texte:SetPoint("CENTER", 0, 0)
  b.sort = s
  b:SetScript("OnEnter", function(self)
    local sp = self.sort
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(sp.nom or sp.cle, 1, 1, 1)
    if sp.moi then
      GameTooltip:AddLine("Clic gauche : sur la cible, clic droit : sur moi", 0.7, 0.7, 0.7)
    else
      GameTooltip:AddLine("Clic : lancer", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine("Touches : Raccourcis, Paladin Rex", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:Hide()
  boutons[#boutons + 1] = b
end

-- Alerte au centre et journal des capacités ennemies
local alerte = CreateFrame("Frame", "PaladinRexPvPAlerte", UIParent)
alerte:SetSize(500, 50)
alerte:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
alerte:SetFrameStrata("HIGH")
alerte.texte = alerte:CreateFontString(nil, "OVERLAY")
alerte.texte:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
alerte.texte:SetPoint("CENTER", 22, 0)
alerte.icone = alerte:CreateTexture(nil, "ARTWORK")
alerte.icone:SetSize(40, 40)
alerte.icone:SetPoint("RIGHT", alerte.texte, "LEFT", -8, 0)
alerte:Hide()

local journal = CreateFrame("ScrollingMessageFrame", "PaladinRexPvPJournal", UIParent)
journal:SetSize(440, 80)
journal:SetPoint("TOP", alerte, "BOTTOM", 0, -4)
journal:SetFontObject(GameFontNormal)
journal:SetJustifyH("CENTER")
journal:SetFading(true)
journal:SetFadeDuration(1.5)
journal:SetTimeVisible(6)
journal:SetMaxLines(5)

local function configurer()
  if InCombatLockdown() then apresCombat = true return end
  lireGrimoire()
  local x = 0
  for _, b in ipairs(boutons) do
    local s = b.sort
    s.nom, s.icone = nil, nil
    for _, id in ipairs(s.ids) do
      local nom, icone = infoSort(id)
      if nom and connus[nom] then
        s.nom, s.icone = nom, icone
        break
      end
    end
    if s.nom then
      b:SetAttribute("type1", "spell")
      b:SetAttribute("spell1", s.nom)
      b:SetAttribute("type2", "spell")
      b:SetAttribute("spell2", s.nom)
      b:SetAttribute("unit2", s.moi and "player" or nil)
      b.icone:SetTexture(s.icone)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 6 + x * 39, -18)
      b:Show()
      x = x + 1
    else
      b:SetAttribute("type1", nil)
      b:SetAttribute("type2", nil)
      b:Hide()
    end
  end
  barre:SetWidth(math.max(140, 12 + x * 39))
end

local function placer()
  local d = db()
  barre:ClearAllPoints()
  if d.pos then
    barre:SetPoint(d.pos[1], UIParent, d.pos[2], d.pos[3], d.pos[4])
  else
    barre:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
  end
end

local function appliquerVisibilite()
  local actif = modeActif()
  if not actif then alerte:Hide() end
  if InCombatLockdown() then apresCombat = true return end
  local afficher = not (PaladinRexDB and PaladinRexDB.afficher == false)
  if actif and afficher then barre:Show() else barre:Hide() end
end

local function majRecharges()
  for _, b in ipairs(boutons) do
    local s = b.sort
    if s.nom then
      local debut, duree = recharge(s.nom)
      if duree > 1.5 then b.cd:SetCooldown(debut, duree) else b.cd:SetCooldown(0, 0) end
    end
  end
end

local function resteLonganimite()
  if not nomLonganimite then return nil end
  for i = 1, 40 do
    local nom, expire = aura("player", i, "HARMFUL")
    if not nom then return nil end
    if nom == nomLonganimite then
      if expire and expire > 0 then return expire - GetTime() end
      return 60
    end
  end
end

local function entrave()
  for i = 1, 40 do
    local nom = aura("player", i, "HARMFUL")
    if not nom then return nil end
    if entraves[nom] then return nom end
  end
end

local function dissipable(magie)
  for i = 1, 40 do
    local nom, _, typ = aura("player", i, "HARMFUL")
    if not nom then return nil end
    if typ == "Poison" or typ == "Disease" or (magie and typ == "Magic") then return nom end
  end
end

local function majBoutons()
  local longa = resteLonganimite()
  local cible = UnitExists("target")
  for _, b in ipairs(boutons) do
    local s = b.sort
    if s.nom then
      local ok, sansMana = IsUsableSpell(s.nom)
      if s.longanimite and longa then
        b.icone:SetVertexColor(1, 0.3, 0.3)
        b.texte:SetText(math.ceil(longa))
      else
        b.texte:SetText("")
        if cible and horsPortee(s.nom, "target") then
          b.icone:SetVertexColor(1, 0.25, 0.25)
        elseif sansMana then
          b.icone:SetVertexColor(0.3, 0.3, 1)
        elseif not ok then
          b.icone:SetVertexColor(0.4, 0.4, 0.4)
        else
          b.icone:SetVertexColor(1, 1, 1)
        end
      end
    end
  end
end

-- Une seule alerte à la fois, la plus urgente d'abord.
local function choisirAlerte()
  if not db().alertes then return nil end
  local bouclier, liberte, epuration = SORT.Bouclier, SORT.Liberte, SORT.Epuration
  local pv = UnitHealth("player") / math.max(1, UnitHealthMax("player"))
  if bouclier.nom and pv < 0.3 and not resteLonganimite() and disponible(bouclier.nom) then
    return string.upper(bouclier.nom), bouclier.icone, 1, 0.85, 0.2
  end
  if liberte.nom and disponible(liberte.nom) then
    local nom = entrave()
    if nom then return string.upper(liberte.nom) .. " (" .. nom .. ")", liberte.icone, 1, 0.6, 0.1 end
  end
  if epuration.nom and disponible(epuration.nom) then
    local nom = dissipable(epuration.nom == nomEpuration)
    if nom then return string.upper(epuration.nom) .. " (" .. nom .. ")", epuration.icone, 0.3, 0.8, 1 end
  end
  if UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
    local courroux, marteau = SORT.Courroux, SORT.Marteau
    local pvCible = UnitHealth("target") / math.max(1, UnitHealthMax("target"))
    if courroux.nom and pvCible < 0.2 and disponible(courroux.nom) and not horsPortee(courroux.nom, "target") then
      return string.upper(courroux.nom) .. " : ACHÈVE", courroux.icone, 1, 0.3, 0.3
    end
    local incantation = UnitCastingInfo("target") or UnitChannelInfo("target")
    if marteau.nom and incantation and disponible(marteau.nom) and not horsPortee(marteau.nom, "target") then
      return string.upper(marteau.nom) .. " : " .. incantation, marteau.icone, 1, 0.82, 0
    end
  end
end

-- Rendements décroissants : 100 %, puis 50 %, 25 %, immunisé ; remise à zéro environ 18 s après la fin du dernier.
local function majDR(guid, sous)
  local t = GetTime()
  local e = dr[guid]
  if sous == "SPELL_AURA_REMOVED" then
    if e then e.fin = t + DR_RESET end
    return
  end
  if not e or t > e.fin then
    e = { niveau = 0 }
    dr[guid] = e
  end
  e.niveau = e.niveau + 1
  e.fin = t + DR_RESET + 6
end

local function texteDR()
  local guid = UnitGUID("target")
  local e = guid and dr[guid]
  if not e or GetTime() > e.fin then return "" end
  local niveaux = { "50 %", "25 %", "|cffff5050immunisé|r" }
  return string.format("Étourdissement sur la cible : %s (%d s)", niveaux[math.min(e.niveau, 3)], math.ceil(e.fin - GetTime()))
end

local function couleurClasse(classe)
  local c = classe and RAID_CLASS_COLORS[classe]
  if not c then return "ffffffff" end
  return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

local function annoncer(guid, nom, sort)
  local t = GetTime()
  local cle = guid .. sort
  if vus[cle] and t - vus[cle] < 3 then return end
  vus[cle] = t
  local _, classe = GetPlayerInfoByGUID(guid)
  local nomCourt = (nom or "?"):gsub("%-.*", "")
  local estCible = guid == UnitGUID("target")
  journal:AddMessage(string.format("%s|c%s%s|r : %s", estCible and "CIBLE  " or "", couleurClasse(classe), nomCourt, sort),
    1, estCible and 0.3 or 0.82, estCible and 0.3 or 0)
end

-- Journal de combat 3.3.5 : horodatage, événement, source (GUID, nom, drapeaux), cible (idem), sort (id, nom).
local function journalCombat(_, sous, srcGUID, srcNom, srcFlags, dstGUID, _, dstFlags, _, nomSort)
  if not nomSort then return end
  if (sous == "SPELL_AURA_APPLIED" or sous == "SPELL_AURA_REFRESH" or sous == "SPELL_AURA_REMOVED")
    and etourdissements[nomSort] and bit.band(dstFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
    majDR(dstGUID, sous)
  end
  if (sous == "SPELL_CAST_SUCCESS" or sous == "SPELL_AURA_APPLIED") and ennemis[nomSort]
    and bit.band(srcFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    and bit.band(srcFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
    annoncer(srcGUID, srcNom, nomSort)
  end
end

-- Accès depuis PaladinRex.lua (commandes et changement de mode)
ns.appliquerVisibilitePvP = appliquerVisibilite
function ns.placerPvP()
  db().pos = nil
  placer()
end
function ns.basculerAlertes()
  local d = db()
  d.alertes = not d.alertes
  return d.alertes
end

-- Événements
local evenements = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED",
  "COMBAT_LOG_EVENT_UNFILTERED" }) do
  evenements:RegisterEvent(e)
end
evenements:SetScript("OnEvent", function(_, ev, ...)
  if ev == "PLAYER_LOGIN" then
    db()
    placer()
    preparerNoms()
    configurer()
    appliquerVisibilite()
    pret = true
    majRecharges()
  elseif not pret then
    return
  elseif ev == "COMBAT_LOG_EVENT_UNFILTERED" then
    if modeActif() then journalCombat(...) end
  elseif ev == "SPELL_UPDATE_COOLDOWN" then
    majRecharges()
  elseif ev == "SPELLS_CHANGED" then
    configurer()
    majRecharges()
  elseif ev == "PLAYER_REGEN_ENABLED" then
    if apresCombat then
      apresCombat = false
      configurer()
      majRecharges()
    end
    appliquerVisibilite()
    wipe(vus)
  end
end)

local cumul = 0
evenements:SetScript("OnUpdate", function(_, dt)
  cumul = cumul + dt
  if cumul < 0.15 then return end
  cumul = 0
  if not pret or not modeActif() then
    alerte:Hide()
    return
  end
  majBoutons()
  local texte, icone, r, g, b = choisirAlerte()
  if texte then
    alerte.texte:SetText(texte)
    alerte.texte:SetTextColor(r, g, b)
    alerte.icone:SetTexture(icone)
    alerte:Show()
  else
    alerte:Hide()
  end
  drTexte:SetText(texteDR())
end)
