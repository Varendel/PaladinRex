-- Paladin Rex : bénédictions, auras, fureur vertueuse et sceau du paladin (WoW 3.3.5a).
-- Mode PvE : une ligne par classe du groupe ; clic gauche = bénédiction (grande si possible) sur le prochain membre
-- à refaire, clic droit = bénédiction simple, molette = changer la bénédiction de la classe (hors combat).
-- Gros bouton et touche « Paladin Rex » (Raccourcis) : aura, fureur vertueuse en mode tank, puis bénédictions manquantes.
-- Mode JcJ (fichier PvP.lua) : barre de contrôles et défensifs, alertes, étourdissements, capacités ennemies.
-- Menace (fichier Menace.lua) : tableau de la menace du groupe et alertes d'aggro.
-- Commandes : /pala (afficher ou masquer), /pala pvp, /pala pve, /pala auto, /pala alertes, /pala menace, /pala tank,
-- /pala grandes, /pala verrou, /pala reset, /pala minicarte. Icône sur la minicarte pour ouvrir et changer de mode.

local ADDON, ns = ...

BINDING_HEADER_PALADINREX = "Paladin Rex"
_G["BINDING_NAME_CLICK PaladinRexBouton:LeftButton"] = "Bénir ou poser l'aura (prochain manquant)"

if select(2, UnitClass("player")) ~= "PALADIN" then
  SLASH_PALADINREX1 = "/pala"
  SlashCmdList.PALADINREX = function()
    print("|cfff58cbaPaladin Rex|r : ce personnage n'est pas paladin, l'addon reste en veille.")
  end
  return
end

local BENE = {
  { cle = "puissance", court = "Puissance", normale = 19740, grande = 25782 },
  { cle = "sagesse", court = "Sagesse", normale = 19742, grande = 25894 },
  { cle = "rois", court = "Rois", normale = 20217, grande = 25898 },
  { cle = "sanctuaire", court = "Sanctuaire", normale = 20911, grande = 25899 },
}
local BENE_PAR_CLE = {}
for _, b in ipairs(BENE) do BENE_PAR_CLE[b.cle] = b end

local AURAS = { 465, 7294, 19746, 32223, 19876, 19888, 19891 }
local SCEAUX = { 21084, 20154, 20164, 20165, 20166, 20375, 31801, 53736 }
local FUREUR = 25780
local SYMBOLE = 21177
local CLASSES = { "DEATHKNIGHT", "WARRIOR", "ROGUE", "HUNTER", "PALADIN", "SHAMAN", "DRUID", "PRIEST", "MAGE", "WARLOCK" }
local DEFAUT = { DEATHKNIGHT = "puissance", WARRIOR = "puissance", ROGUE = "puissance", HUNTER = "puissance" }
local SEUIL = 60 -- secondes : en dessous, la bénédiction est à refaire
local ICONE_REPOS = "Interface\\Icons\\INV_Misc_QuestionMark"

local connus, auras, nomsAuras, sceaux, fureur = {}, {}, {}, {}, {}
local derniere = {}
local pret, apresCombat = false, false
local mettreAJour

local function db()
  PaladinRexDB = PaladinRexDB or {}
  local d = PaladinRexDB
  d.assign = d.assign or {}
  for _, c in ipairs(CLASSES) do
    if d.assign[c] == nil then d.assign[c] = DEFAUT[c] or "sagesse" end
  end
  if d.grandes == nil then d.grandes = "auto" end
  if d.tank == nil then d.tank = false end
  if d.afficher == nil then d.afficher = true end
  if d.verrou == nil then d.verrou = false end
  if d.aura == nil then d.aura = 465 end
  if d.mode == nil then d.mode = "auto" end
  return d
end
ns.db = db

-- Mode JcJ : forcé par /pala pvp, ou automatique en champ de bataille et en arène.
function ns.modePvP()
  local m = db().mode
  if m == "pvp" then return true end
  if m == "pve" then return false end
  local _, typ = IsInInstance()
  return typ == "pvp" or typ == "arena"
end

local function dire(t) print("|cfff58cbaPaladin Rex|r : " .. t) end

local function infoSort(id)
  local nom, _, icone = GetSpellInfo(id)
  return nom, icone
end

-- UnitAura en 3.3.5 : nom, rang, icône, charges, type, durée, expiration, lanceur.
local function aura(unit, i, filtre)
  local nom, _, _, _, _, _, expire, source = UnitAura(unit, i, filtre)
  return nom, expire, source
end

local function aPortee(nom, unit)
  if UnitIsUnit(unit, "player") then return true end
  local r = IsSpellInRange(nom, unit)
  if r == nil then return UnitIsVisible(unit) and true or false end
  return r == 1
end

local function lireGrimoire()
  wipe(connus)
  for i = 1, 1000 do
    local nom = GetSpellName(i, BOOKTYPE_SPELL or "spell")
    if not nom then break end
    connus[nom] = true
  end
end

local function enRaid()
  return (GetNumRaidMembers() or 0) > 0
end

local function preparerSorts()
  lireGrimoire()
  for _, b in ipairs(BENE) do
    b.nom, b.icone = infoSort(b.normale)
    b.grandeNom, b.grandeIcone = infoSort(b.grande)
    b.connue = b.nom ~= nil and connus[b.nom] == true
    b.grandeConnue = b.grandeNom ~= nil and connus[b.grandeNom] == true
  end
  wipe(auras)
  wipe(nomsAuras)
  for _, id in ipairs(AURAS) do
    local nom, icone = infoSort(id)
    if nom and connus[nom] then
      auras[#auras + 1] = { id = id, nom = nom, icone = icone }
      nomsAuras[nom] = true
    end
  end
  wipe(sceaux)
  for _, id in ipairs(SCEAUX) do
    local nom = infoSort(id)
    if nom then sceaux[nom] = true end
  end
  fureur.nom, fureur.icone = infoSort(FUREUR)
  fureur.connue = fureur.nom ~= nil and connus[fureur.nom] == true
  fureur.set = fureur.nom and { [fureur.nom] = true } or {}
end

-- Premier buff posé par le joueur sur lui-même dont le nom est dans la liste.
local function buffPerso(noms)
  for i = 1, 40 do
    local nom, _, source = aura("player", i, "HELPFUL")
    if not nom then return nil end
    if noms[nom] and source == "player" then return nom end
  end
end

-- Tank : mode tank forcé (/pala tank) ou Fureur vertueuse active.
function ns.estTank()
  return db().tank or (fureur.connue and buffPerso(fureur.set) ~= nil) or false
end

local function resteBenediction(unit, b, maintenant)
  for i = 1, 40 do
    local nom, expire = aura(unit, i, "HELPFUL")
    if not nom then return nil end
    if nom == b.nom or nom == b.grandeNom then
      if expire and expire > 0 then return expire - maintenant end
      return math.huge
    end
  end
end

local function formatTemps(s)
  if s == math.huge then return "active" end
  if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60)) end
  return string.format("%d s", math.max(0, math.floor(s)))
end

local function membres()
  local liste = {}
  if enRaid() then
    for i = 1, GetNumRaidMembers() do liste[#liste + 1] = "raid" .. i end
  else
    liste[1] = "player"
    for i = 1, GetNumPartyMembers() do liste[#liste + 1] = "party" .. i end
  end
  return liste
end

-- Par classe : membres, combien ont la bénédiction voulue, qui est à refaire (à portée) et qui est trop loin.
local function analyser()
  local d = db()
  local maintenant = GetTime()
  local res = {}
  for _, u in ipairs(membres()) do
    local _, classe = UnitClass(u)
    if classe and UnitExists(u) then
      local c = res[classe]
      if not c then
        c = { membres = 0, ok = 0, aRefaire = {}, horsPortee = 0, details = {} }
        res[classe] = c
      end
      c.membres = c.membres + 1
      c.premier = c.premier or u
      local m = { nom = UnitName(u) or "?" }
      c.details[#c.details + 1] = m
      local b = BENE_PAR_CLE[d.assign[classe]]
      if b and b.connue then
        local reste = resteBenediction(u, b, maintenant)
        m.reste = reste
        if reste and (not c.mini or reste < c.mini) then c.mini = reste end
        if reste and reste > SEUIL then
          c.ok = c.ok + 1
        elseif not UnitIsConnected(u) then
          m.etat = "déconnecté"
        elseif UnitIsDeadOrGhost(u) then
          m.etat = "mort"
        elseif aPortee(b.nom, u) then
          c.aRefaire[#c.aRefaire + 1] = u
        else
          c.horsPortee = c.horsPortee + 1
          m.etat = "hors de portée"
        end
      end
    end
  end
  return res
end

local function sortPourClasse(b, c)
  if b.grandeConnue and GetItemCount(SYMBOLE) > 0 then
    local mode = db().grandes
    if mode == "toujours" or (mode == "auto" and (enRaid() or c.membres >= 2)) then
      return b.grandeNom, b.grandeIcone
    end
  end
  return b.nom, b.icone
end

local function auraVoulue()
  local voulue = db().aura
  for _, a in ipairs(auras) do
    if a.id == voulue then return a end
  end
  return auras[1]
end

-- Ce que fait le gros bouton : aura, fureur vertueuse (mode tank), puis la première bénédiction à refaire.
local function prochaineAction(analyse)
  if UnitIsDeadOrGhost("player") then return nil end
  local d = db()
  if #auras > 0 and not buffPerso(nomsAuras) then
    local a = auraVoulue()
    return a.nom, nil, a.icone, a.nom
  end
  if d.tank and fureur.connue and not buffPerso(fureur.set) then
    return fureur.nom, nil, fureur.icone, fureur.nom .. " (mode tank)"
  end
  for _, classe in ipairs(CLASSES) do
    local c = analyse[classe]
    local b = c and BENE_PAR_CLE[d.assign[classe]]
    if b and b.connue and #c.aRefaire > 0 then
      local sort, icone = sortPourClasse(b, c)
      local u = c.aRefaire[1]
      return sort, u, icone, sort .. " sur " .. (UnitName(u) or "?")
    end
  end
end

-- Panneau
local panneau = CreateFrame("Frame", "PaladinRexPanneau", UIParent)
panneau:SetSize(290, 110)
panneau:SetFrameStrata("MEDIUM")
panneau:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panneau:SetBackdropColor(0, 0, 0, 0.75)
panneau:SetBackdropBorderColor(0.96, 0.55, 0.73, 0.9)
panneau:SetClampedToScreen(true)
panneau:SetMovable(true)
panneau:EnableMouse(true)
panneau:RegisterForDrag("LeftButton")
panneau:SetScript("OnDragStart", function(self)
  if not db().verrou and not InCombatLockdown() then self:StartMoving() end
end)
panneau:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  db().pos = { p, rp, x, y }
end)

local titre = panneau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOPLEFT", 10, -8)
titre:SetText("Paladin Rex")
local symboles = panneau:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
symboles:SetPoint("TOPRIGHT", -30, -10)

-- Bouton de réduction : le panneau se replie sur sa barre de titre (la touche « Paladin Rex » reste active).
local reduire = CreateFrame("Button", "PaladinRexReduire", panneau)
reduire:SetSize(16, 16)
reduire:SetPoint("TOPRIGHT", -8, -8)
reduire:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
reduire:SetScript("OnClick", function()
  if InCombatLockdown() then dire("réduction impossible en combat") return end
  local d = db()
  d.reduit = not d.reduit
  mettreAJour()
end)
reduire:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(db().reduit and "Déplier le panneau" or "Réduire le panneau")
  GameTooltip:Show()
end)
reduire:SetScript("OnLeave", GameTooltip_Hide)

local bouton = CreateFrame("Button", "PaladinRexBouton", panneau, "SecureActionButtonTemplate")
bouton:SetSize(36, 36)
bouton:SetPoint("TOPLEFT", 10, -28)
bouton:RegisterForClicks("AnyUp")
bouton.icone = bouton:CreateTexture(nil, "ARTWORK")
bouton.icone:SetAllPoints()
bouton.icone:SetTexture(ICONE_REPOS)
bouton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

local prochain = panneau:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
prochain:SetPoint("TOPLEFT", bouton, "TOPRIGHT", 8, -2)
prochain:SetWidth(226)
prochain:SetJustifyH("LEFT")
local sceauTexte = panneau:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sceauTexte:SetPoint("BOTTOMLEFT", bouton, "BOTTOMRIGHT", 8, 1)

bouton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Paladin Rex", 0.96, 0.55, 0.73)
  GameTooltip:AddLine(prochain:GetText() or "", 1, 1, 1, true)
  GameTooltip:AddLine("Clic ou touche (Raccourcis, Paladin Rex) : aura, fureur vertueuse en mode tank, puis bénédictions manquantes. Hors combat.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end)
bouton:SetScript("OnLeave", GameTooltip_Hide)

-- Auras (et fureur vertueuse) : clic pour poser, la dernière choisie devient celle du gros bouton.
local boutonsAura = {}
for k = 1, 8 do
  local b = CreateFrame("Button", "PaladinRexAura" .. k, panneau, "SecureActionButtonTemplate")
  b:SetSize(24, 24)
  b:SetPoint("TOPLEFT", 10 + (k - 1) * 27, -70)
  b:RegisterForClicks("AnyUp")
  b.icone = b:CreateTexture(nil, "ARTWORK")
  b.icone:SetAllPoints()
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("PostClick", function(self) if self.auraId then db().aura = self.auraId end end)
  b:SetScript("OnEnter", function(self)
    if not self.nomSort then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.nomSort)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:Hide()
  boutonsAura[k] = b
end

local function changerBenediction(classe, delta)
  if InCombatLockdown() then return end
  local d = db()
  local choix = { "aucune" }
  for _, b in ipairs(BENE) do
    if b.connue then choix[#choix + 1] = b.cle end
  end
  local pos = 1
  for i, c in ipairs(choix) do
    if c == d.assign[classe] then pos = i end
  end
  pos = pos - delta
  if pos < 1 then pos = #choix elseif pos > #choix then pos = 1 end
  d.assign[classe] = choix[pos]
  mettreAJour()
end

-- Clic sur une des icônes à droite de la ligne ; recliquer la bénédiction choisie la retire.
local function choisirBenediction(classe, cle)
  if InCombatLockdown() then dire("choix impossible en combat") return end
  local b = BENE_PAR_CLE[cle]
  if not b.connue then dire((b.nom or b.court) .. " : pas encore apprise") return end
  local d = db()
  d.assign[classe] = (d.assign[classe] == cle) and "aucune" or cle
  mettreAJour()
end

local function infobulleLigne(self)
  local c = derniere[self.classe]
  local b = BENE_PAR_CLE[db().assign[self.classe]]
  local nomClasse = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[self.classe] or self.classe
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(nomClasse .. " : " .. (b and b.court or "aucune bénédiction"), 1, 0.82, 0)
  if c then
    for _, m in ipairs(c.details) do
      local t, r, g = "manquante", 1, 0.3
      if m.reste then
        t = formatTemps(m.reste)
        if m.reste > SEUIL then r, g = 0.3, 1 end
      end
      if m.etat then t = m.etat end
      GameTooltip:AddDoubleLine(m.nom, t, 1, 1, 1, r, g, 0.3)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Clic gauche : bénédiction (grande si possible)", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Clic droit : bénédiction simple", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Icônes à droite ou molette : choisir la bénédiction de la classe", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

local function infobulleChoix(self)
  local b = BENE_PAR_CLE[self.cle]
  local nomClasse = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[self.classe] or self.classe
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(b.nom or b.court, 1, 1, 1)
  if b.connue then
    GameTooltip:AddLine("Clic : la choisir pour " .. nomClasse, 0.7, 0.7, 0.7)
  else
    GameTooltip:AddLine("Pas encore apprise", 1, 0.3, 0.3)
  end
  GameTooltip:Show()
end

local lignes = {}
for _, classe in ipairs(CLASSES) do
  local l = CreateFrame("Button", "PaladinRexLigne" .. classe, panneau, "SecureActionButtonTemplate")
  l:SetSize(172, 22)
  l:RegisterForClicks("AnyUp")
  l:EnableMouseWheel(true)
  l.classe = classe
  l.iconeClasse = l:CreateTexture(nil, "ARTWORK")
  l.iconeClasse:SetSize(18, 18)
  l.iconeClasse:SetPoint("LEFT", 2, 0)
  l.iconeClasse:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
  local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classe]
  if tc then l.iconeClasse:SetTexCoord(unpack(tc)) end
  l.iconeBene = l:CreateTexture(nil, "ARTWORK")
  l.iconeBene:SetSize(18, 18)
  l.iconeBene:SetPoint("LEFT", l.iconeClasse, "RIGHT", 4, 0)
  l.texte = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  l.texte:SetPoint("LEFT", l.iconeBene, "RIGHT", 6, 0)
  l.texte:SetPoint("RIGHT", -4, 0)
  l.texte:SetJustifyH("LEFT")
  l:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  l:SetScript("OnMouseWheel", function(self, delta) changerBenediction(self.classe, delta) end)
  l:SetScript("OnEnter", infobulleLigne)
  l:SetScript("OnLeave", GameTooltip_Hide)
  l:Hide()
  l.choix = {}
  for k, b in ipairs(BENE) do
    local c = CreateFrame("Button", nil, panneau)
    c:SetSize(18, 18)
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetAllPoints()
    c:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    c.cle, c.classe = b.cle, classe
    c:SetScript("OnClick", function(self) choisirBenediction(self.classe, self.cle) end)
    c:SetScript("OnEnter", infobulleChoix)
    c:SetScript("OnLeave", GameTooltip_Hide)
    c:Hide()
    l.choix[k] = c
  end
  lignes[classe] = l
end

local aideChoix = panneau:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
aideChoix:SetText("Icônes à droite : choisir la bénédiction de chaque classe")

local function configurerAuras()
  if InCombatLockdown() then apresCombat = true return end
  local k = 0
  for _, a in ipairs(auras) do
    k = k + 1
    local b = boutonsAura[k]
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", a.nom)
    b.icone:SetTexture(a.icone)
    b.nomSort, b.auraId, b.estFureur = a.nom, a.id, nil
    b:Show()
  end
  if fureur.connue then
    k = k + 1
    local b = boutonsAura[k]
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", fureur.nom)
    b.icone:SetTexture(fureur.icone)
    b.nomSort, b.auraId, b.estFureur = fureur.nom, nil, true
    b:Show()
  end
  for j = k + 1, #boutonsAura do
    local b = boutonsAura[j]
    b:SetAttribute("type", nil)
    b.nomSort, b.auraId, b.estFureur = nil, nil, nil
    b:Hide()
  end
end

local function placer()
  local d = db()
  panneau:ClearAllPoints()
  if d.pos then
    panneau:SetPoint(d.pos[1], UIParent, d.pos[2], d.pos[3], d.pos[4])
  else
    panneau:SetPoint("CENTER", UIParent, "CENTER", -400, 150)
  end
end

local function appliquerVisibilite()
  if ns.appliquerVisibilitePvP then ns.appliquerVisibilitePvP() end
  if InCombatLockdown() then apresCombat = true return end
  if db().afficher and not ns.modePvP() then panneau:Show() else panneau:Hide() end
end

mettreAJour = function()
  if not pret then return end
  local d = db()
  local combat = InCombatLockdown()
  local analyse = analyser()
  derniere = analyse

  local avecGrandes = false
  for _, b in ipairs(BENE) do
    if b.grandeConnue then avecGrandes = true end
  end
  if avecGrandes then
    local n = GetItemCount(SYMBOLE)
    symboles:SetText((n < 10 and "|cffff5050" or "") .. "Symboles : " .. n)
  else
    symboles:SetText("")
  end

  local auraActive = buffPerso(nomsAuras)
  local fureurActive = fureur.connue and buffPerso(fureur.set)
  for _, b in ipairs(boutonsAura) do
    if b.nomSort then
      local actif = (b.estFureur and fureurActive) or (not b.estFureur and b.nomSort == auraActive)
      b.icone:SetAlpha(actif and 1 or 0.35)
    end
  end

  local sceau = buffPerso(sceaux)
  if sceau then
    sceauTexte:SetText("|cffaaaaaaSceau :|r " .. sceau)
  elseif combat and UnitCanAttack("player", "target") then
    sceauTexte:SetText("|cffff5050Aucun sceau !|r")
  else
    sceauTexte:SetText("")
  end

  local icone = d.reduit and "Interface\\Buttons\\UI-PlusButton-" or "Interface\\Buttons\\UI-MinusButton-"
  reduire:SetNormalTexture(icone .. "Up")
  reduire:SetPushedTexture(icone .. "Down")

  if not combat and d.reduit then
    bouton:Hide()
    prochain:Hide()
    sceauTexte:Hide()
    for _, b in ipairs(boutonsAura) do b:Hide() end
    for _, classe in ipairs(CLASSES) do
      lignes[classe]:Hide()
      for _, c in ipairs(lignes[classe].choix) do c:Hide() end
    end
    aideChoix:Hide()
    panneau:SetHeight(30)
  elseif not combat then
    bouton:Show()
    prochain:Show()
    sceauTexte:Show()
    for _, b in ipairs(boutonsAura) do
      if b.nomSort then b:Show() end
    end
    aideChoix:Show()
    local y = (#auras > 0 or fureur.connue) and -100 or -72
    for _, classe in ipairs(CLASSES) do
      local l = lignes[classe]
      if analyse[classe] then
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", 10, y)
        l:Show()
        for k, c in ipairs(l.choix) do
          c:ClearAllPoints()
          c:SetPoint("TOPLEFT", panneau, "TOPLEFT", 186 + (k - 1) * 21, y - 2)
          c:Show()
        end
        y = y - 23
      else
        l:Hide()
        for _, c in ipairs(l.choix) do c:Hide() end
      end
    end
    aideChoix:ClearAllPoints()
    aideChoix:SetPoint("TOPLEFT", 10, y - 2)
    panneau:SetHeight(-y + 22)
  end

  for _, classe in ipairs(CLASSES) do
    local l, c = lignes[classe], analyse[classe]
    if c and l:IsShown() then
      local b = BENE_PAR_CLE[d.assign[classe]]
      local texte
      for k, ch in ipairs(l.choix) do
        local bk = BENE[k]
        ch.icone:SetTexture(bk.icone)
        ch.icone:SetDesaturated(not bk.connue)
        ch.icone:SetAlpha(d.assign[classe] == bk.cle and 1 or 0.3)
      end
      if b and b.connue then
        local sort, icone = sortPourClasse(b, c)
        l.iconeBene:SetTexture(icone)
        local couleur = "50ff50"
        if #c.aRefaire > 0 then couleur = "ff5050" elseif c.horsPortee > 0 then couleur = "ffd100" end
        texte = string.format("|cff%s%s  %d/%d|r", couleur, b.court, c.ok, c.membres)
        if c.mini then texte = texte .. "  " .. formatTemps(c.mini) end
        if c.horsPortee > 0 then texte = texte .. "  |cffaaaaaa" .. c.horsPortee .. " loin|r" end
        if not combat then
          local cible = c.aRefaire[1] or c.premier
          l:SetAttribute("type1", "spell")
          l:SetAttribute("spell1", sort)
          l:SetAttribute("unit1", cible)
          l:SetAttribute("type2", "spell")
          l:SetAttribute("spell2", b.nom)
          l:SetAttribute("unit2", cible)
        end
      else
        if b then
          l.iconeBene:SetTexture(b.icone)
          texte = "|cffaaaaaa" .. b.court .. " pas encore apprise|r"
        else
          l.iconeBene:SetTexture(nil)
          texte = "|cffaaaaaaaucune (molette pour choisir)|r"
        end
        if not combat then
          l:SetAttribute("type1", nil)
          l:SetAttribute("type2", nil)
        end
      end
      l.texte:SetText(texte)
    end
  end

  if combat then
    prochain:SetText("En combat : bouton figé jusqu'à la fin du combat")
  else
    local sort, unite, icone, libelle = prochaineAction(analyse)
    if sort then
      bouton:SetAttribute("type", "spell")
      bouton:SetAttribute("spell", sort)
      bouton:SetAttribute("unit", unite)
      bouton.icone:SetTexture(icone)
      bouton.icone:SetDesaturated(false)
      prochain:SetText(libelle)
    else
      bouton:SetAttribute("type", nil)
      bouton.icone:SetTexture(BENE[1].icone or ICONE_REPOS)
      bouton.icone:SetDesaturated(true)
      prochain:SetText("|cff50ff50Tout est à jour|r")
    end
  end
end

-- Événements
local evenements = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED",
  "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
  evenements:RegisterEvent(e)
end
evenements:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_LOGIN" then
    db()
    placer()
    preparerSorts()
    configurerAuras()
    appliquerVisibilite()
    pret = true
    mettreAJour()
  elseif ev == "SPELLS_CHANGED" then
    if pret then
      preparerSorts()
      configurerAuras()
      mettreAJour()
    end
  elseif ev == "PLAYER_REGEN_ENABLED" then
    if apresCombat then
      apresCombat = false
      configurerAuras()
      appliquerVisibilite()
    end
    mettreAJour()
  elseif ev == "PLAYER_ENTERING_WORLD" or ev == "ZONE_CHANGED_NEW_AREA" then
    if pret then appliquerVisibilite() end
  else
    mettreAJour()
  end
end)

local cumul = 0
evenements:SetScript("OnUpdate", function(_, dt)
  cumul = cumul + dt
  if cumul < (enRaid() and 1 or 0.5) then return end
  cumul = 0
  mettreAJour()
end)

-- Commandes
SLASH_PALADINREX1 = "/pala"
SlashCmdList.PALADINREX = function(msg)
  msg = strlower(strtrim(msg or ""))
  local d = db()
  if msg == "pvp" or msg == "pve" or msg == "auto" then
    d.mode = msg
    local textes = {
      auto = "auto (JcJ en champ de bataille et en arène, PvE ailleurs)",
      pvp = "JcJ (barre de contrôles et alertes)",
      pve = "PvE (bénédictions et auras)",
    }
    dire("mode " .. textes[msg])
    if InCombatLockdown() then dire("l'affichage changera à la fin du combat") end
    appliquerVisibilite()
  elseif msg == "alertes" then
    if ns.basculerAlertes then dire("alertes JcJ " .. (ns.basculerAlertes() and "activées" or "coupées")) end
  elseif msg == "minicarte" then
    if ns.basculerMini then ns.basculerMini() end
  elseif msg == "bulles" then
    if ns.basculerBulles then dire("bulles " .. (ns.basculerBulles() and "affichées" or "masquées")) end
  elseif msg:match("^seuil") then
    if ns.seuilBulles then dire("les bulles s'allument à " .. ns.seuilBulles(tonumber(msg:match("%d+"))) .. " % de vie") end
  elseif msg == "menace" then
    if ns.basculerMenace then dire("tableau de menace " .. (ns.basculerMenace() and "affiché (en groupe, sur une cible ennemie)" or "masqué")) end
  elseif msg == "tank" then
    d.tank = not d.tank
    dire("mode tank " .. (d.tank and "activé : la fureur vertueuse est surveillée" or "désactivé"))
  elseif msg == "grandes" then
    local suivant = { auto = "toujours", toujours = "jamais", jamais = "auto" }
    d.grandes = suivant[d.grandes] or "auto"
    local textes = {
      auto = "auto (en raid, ou dès 2 membres de la même classe)",
      toujours = "toujours (même seul)",
      jamais = "jamais (bénédictions simples seulement)",
    }
    dire("grandes bénédictions : " .. textes[d.grandes])
  elseif msg == "verrou" then
    d.verrou = not d.verrou
    dire("panneau " .. (d.verrou and "verrouillé" or "déverrouillé (glisser pour déplacer)"))
  elseif msg == "reset" then
    if InCombatLockdown() then dire("impossible en combat") return end
    d.pos = nil
    placer()
    if ns.placerPvP then ns.placerPvP() end
    if ns.placerMenace then ns.placerMenace() end
    if ns.placerBulles then ns.placerBulles() end
    dire("panneau, barre JcJ, tableau de menace et bulles remis à leur place")
  elseif msg == "aide" then
    dire("/pala : afficher ou masquer, /pala pvp, /pala pve, /pala auto, /pala alertes, /pala menace, /pala bulles, /pala seuil 15, /pala tank, /pala grandes, /pala verrou, /pala reset, /pala minicarte")
  else
    d.afficher = not d.afficher
    appliquerVisibilite()
    dire("panneau " .. (d.afficher and "affiché" or "masqué") .. " (la touche reste active)")
  end
  mettreAJour()
end

-- Icône de la minicarte : clic gauche = afficher ou masquer, clic droit = PvE ou JcJ, glisser = déplacer.
local mini = CreateFrame("Button", "PaladinRexMinicarte", Minimap)
mini:SetSize(31, 31)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(8)
mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mini:RegisterForDrag("LeftButton")
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local miniFond = mini:CreateTexture(nil, "BACKGROUND")
miniFond:SetSize(20, 20)
miniFond:SetPoint("TOPLEFT", 7, -5)
miniFond:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
local miniIcone = mini:CreateTexture(nil, "ARTWORK")
miniIcone:SetSize(18, 18)
miniIcone:SetPoint("TOPLEFT", 7, -6)
miniIcone:SetTexture(select(2, infoSort(642)) or ICONE_REPOS)
miniIcone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local miniBord = mini:CreateTexture(nil, "OVERLAY")
miniBord:SetSize(53, 53)
miniBord:SetPoint("TOPLEFT")
miniBord:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function placerMini()
  local d = db()
  local a = math.rad(d.miniAngle or 200)
  local r = Minimap:GetWidth() / 2 + 10
  mini:ClearAllPoints()
  mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  if d.miniCache then mini:Hide() else mini:Show() end
end

mini:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local echelle = Minimap:GetEffectiveScale()
    db().miniAngle = math.deg(math.atan2(cy / echelle - my, cx / echelle - mx))
    placerMini()
  end)
end)
mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mini:SetScript("OnClick", function(_, boutonSouris)
  if boutonSouris == "RightButton" then
    SlashCmdList.PALADINREX(ns.modePvP() and "pve" or "pvp")
  else
    SlashCmdList.PALADINREX("")
  end
end)
mini:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("Paladin Rex", 0.96, 0.55, 0.73)
  GameTooltip:AddLine("Mode : " .. (ns.modePvP() and "JcJ" or "PvE") .. (db().mode == "auto" and " (auto)" or ""), 1, 1, 1)
  GameTooltip:AddLine("Clic gauche : afficher ou masquer", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Clic droit : passer en PvE ou en JcJ (/pala auto pour revenir en auto)", 0.7, 0.7, 0.7, true)
  GameTooltip:AddLine("Glisser : déplacer l'icône", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
mini:SetScript("OnLeave", GameTooltip_Hide)

function ns.basculerMini()
  local d = db()
  d.miniCache = not d.miniCache
  placerMini()
  dire("icône de la minicarte " .. (d.miniCache and "masquée (/pala minicarte pour la remettre)" or "affichée"))
end

evenements:HookScript("OnEvent", function(_, ev)
  if ev == "PLAYER_LOGIN" then placerMini() end
end)
