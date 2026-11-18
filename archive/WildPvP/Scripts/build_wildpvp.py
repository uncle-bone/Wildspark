from pathlib import Path
import re, shutil, sys
repo=Path(sys.argv[1]).resolve()
sources=repo/'WildPvP'/'Packages'
out=Path(sys.argv[2]).resolve()
if out.exists(): shutil.rmtree(out)
out.mkdir(parents=True)
layout=[('Spy','Features/Awareness','Spy.toc'),('Capping','Features/Timers','Capping.toc'),('Capping_Options','Features/TimerConfig','Capping_Options.toc'),('HighgroundBattlegrounds','Features/Intel','HighgroundBattlegrounds.toc'),('BattleGroundEnemiesFixed','Features/EnemyFrames','BattleGroundEnemiesFixed.toc')]
for src,prefix,tocname in layout:
    shutil.copytree(sources/src,out/prefix,ignore=shutil.ignore_patterns('*.toc','AGENTS.md','CLAUDE.md','GEMINI.md','README.md','CHANGELOG.md'))

# Retarget component-private tables so the formerly independent codebases remain
# isolated while loading from one WoW addon namespace.
def rewrite_tree(prefix, kind):
    root=out/prefix
    for f in root.rglob('*.lua'):
        s=f.read_text(encoding='utf-8-sig')
        if kind=='timers':
            s=re.sub(r'(?m)^(\s*local\s+(?:addonName|_)\s*,\s*(?:mod|core)\s*=\s*)\.\.\.',r'\1"WildPvP", _G.WildPvP_Capping',s)
            if f.name.startswith('Core'):
                s=s.replace('if addon == addonName then','if addon == "WildPvP" then')
                s=s.replace('C_AddOns.EnableAddOn("Capping_Options") -- Make sure it wasn\'t left disabled for whatever reason\n\t\tC_AddOns.LoadAddOn("Capping_Options")','-- Timer options are bundled and loaded with WildPvP.')
                s=s.replace('LibStub("AceConfigDialog-3.0"):Open(addonName)','LibStub("AceConfigDialog-3.0"):Open("Capping")')
            if f.name=='Options.lua' and f.parent.name=='TimerConfig':
                s=s.replace('name = "Capping",','name = "WildPvP",')
        elif kind=='intel':
            # Highground source files use several spellings for the TOC
            # arguments (addon, ADDON, or _). All must receive our private
            # namespace or individual files silently bind to WildSpark's
            # unrelated shared table.
            s=re.sub(r'(?m)^(\s*local\s+[A-Za-z_][A-Za-z0-9_]*\s*,\s*ns\s*=\s*)\.\.\.',r'\1"WildSpark", _G.WildPvP_Intel',s)
            if f.name == 'Bootstrap.lua':
                s=s.replace('local addon, ns = ...', 'local addon, ns = ...\n_G.WildPvP_Intel = ns')
            if f.name=='Bootstrap.lua':
                s=s.replace('ns.CLIENT, ns.GAME = "retail", "forever"','ns.CLIENT, ns.GAME = "retail", "forever"')
                s=s.replace('ns.CLIENT, ns.GAME = "retail", "retail"','ns.CLIENT, ns.GAME = "retail", "forever"')
                s=s.replace('ns.LABEL = type(title) == "string" and title ~= "" and title or addon','ns.LABEL = "WildPvP"')
                s=s.replace('ns.MEDIA = "Interface\\\\AddOns\\\\" .. addon .. "\\\\libs\\\\media\\\\"','ns.MEDIA = "Interface\\\\AddOns\\\\WildPvP\\\\Features\\\\Intel\\\\libs\\\\media\\\\"')
                s=s.replace('ns.SOUNDS = "Interface\\\\AddOns\\\\" .. addon .. "\\\\src\\\\sounds\\\\"','ns.SOUNDS = "Interface\\\\AddOns\\\\WildPvP\\\\Features\\\\Intel\\\\src\\\\sounds\\\\"')
                s=s.replace('ns.FRAME_PREFIX, ns.SAVED_VARIABLE = addon, addon .. "DB"','ns.FRAME_PREFIX, ns.SAVED_VARIABLE = "WildPvPIntel", "HighgroundBattlegroundsDB"')
                s=s.replace('ns.STANDBY = loaded and loaded("Highground") and true or false','ns.STANDBY = false')
                s=s.replace('ns.LABEL = type(title) == "string" and title ~= "" and title or addon','ns.LABEL = "WildPvP"')
            if f.name=='Battlegrounds.lua' and f.parent.name=='catalog':
                s=s.replace('firstRun = { allBGs = true,','firstRun = { allBGs = true, timers = false,')
        elif kind=='frames':
            s=re.sub(r'(?m)^(\s*local\s+AddonName\s*,\s*Data\s*=\s*)\.\.\.',r'\1"WildPvP", _G.WildPvP_EnemyFrames',s)
            s=re.sub(r'(?m)^(\s*local\s+Data\s*=\s*select\(2,\s*)\.\.\.(\)\s*)$',r'\1"WildPvP", _G.WildPvP_EnemyFrames\2',s)
            s=re.sub(r'(?m)^(\s*local\s+_,\s*Data\s*=\s*)\.\.\.',r'\1"WildPvP", _G.WildPvP_EnemyFrames',s)
            s=re.sub(r'(?m)^(\s*local\s+AddonName\s*=\s*)\.\.\.',r'\1"WildPvP"',s)
            if f.name=='Options.lua':
                s=s.replace('name = "BattleGroundEnemiesFixed " ..','name = "WildPvP " ..')
        if kind=='awareness':
            s=s.replace(r"Interface\Addons\Spy\Textures\bar-flat.tga", r"Interface\AddOns\WildSpark\Modules\WildPvP\Features\Awareness\Textures\bar-flat.tga")
            s=s.replace('Interface\\Addons\\Spy\\Fonts\\','Interface\\AddOns\\WildSpark\\Modules\\WildPvP\\Features\\Awareness\\Fonts\\')
            s=s.replace('Interface\\AddOns\\Spy\\Fonts\\','Interface\\AddOns\\WildSpark\\Modules\\WildPvP\\Features\\Awareness\\Fonts\\')
            s=s.replace(r"Interface\AddOns\Spy\Textures\bar-flat.tga", r"Interface\AddOns\WildSpark\Modules\WildPvP\Features\Awareness\Textures\bar-flat.tga")
            s=s.replace("Interface\\AddOns\\Spy\\Fonts\\", "Interface\\AddOns\\WildSpark\\Modules\\WildPvP\\Features\\Awareness\\Fonts\\")
            s=s.replace("Interface\\Addons\\Spy\\Fonts\\", "Interface\\AddOns\\WildSpark\\Modules\\WildPvP\\Features\\Awareness\\Fonts\\")
            if f.name=='Spy-enUS.lua':
                s=s.replace('L["Spy"] = "Spy"','L["Spy"] = "WildPvP"')
                s=s.replace('L["Spy Option"] = "Spy"','L["Spy Option"] = "WildPvP"')
            if f.name=='Spy-Forever.lua':
                s=s.replace('Spy %s - Options','WildPvP %s - Options')
            if f.name=='Spy.lua':
                s=s.replace('function Spy:ZoneChanged()\n\tSpy.InInstance = false', 'function Spy:ZoneChanged()\n\tlocal inside, kind = IsInInstance()\n\tif not inside or (kind ~= "pvp" and kind ~= "arena") then Spy.EnabledInZone = false; Spy.InInstance = false; if Spy.MainWindow and not InCombatLockdown() then Spy.MainWindow:Hide() end; return end\n\tSpy.InInstance = false')
                s=s.replace('NewAddon("Spy",','NewAddon("WildPvP",')
                s=s.replace('ScheduleRepeatingTimer("ManageExpirations",','ScheduleRepeatingTimer(Spy.ManageExpirations,')
                s=s.replace('Spy.Signature = "[Spy]"','Spy.Signature = "[WildPvP]"')
                s=s.replace('L_STATS = "Spy "..','L_STATS = "WildPvP "..')
        f.write_text(s,encoding='utf-8',newline='')
for src,prefix,_ in layout:
    rewrite_tree(prefix, {'Spy':'awareness','Capping':'timers','Capping_Options':'timers','HighgroundBattlegrounds':'intel','BattleGroundEnemiesFixed':'frames'}[src])

# Capping creates a draggable anchor at startup in its standalone package.
# Keep it hidden on a PvE realm and show it only while in a BG or arena.
capping_file=out/'Features'/'Timers'/'Core.lua'
capping_text=capping_file.read_text(encoding='utf-8-sig')
anchor_show='\tframe:Show()'
if anchor_show not in capping_text: raise SystemExit('Could not find Capping anchor visibility setup.')
capping_text=capping_text.replace(anchor_show,'\tframe:Hide()',1)
capping_text += '''
local WildPvPCappingZoneWatcher = CreateFrame("Frame")
WildPvPCappingZoneWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
WildPvPCappingZoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
WildPvPCappingZoneWatcher:SetScript("OnEvent", function()
\tlocal inside, kind = IsInInstance()
\tframe:SetShown(inside and (kind == "pvp" or kind == "arena"))
end)
'''
capping_file.write_text(capping_text,encoding='utf-8',newline='')

# Nearby-player detection is useful only in BGs and arenas. Keep a tiny zone
# watcher alive, but defer Spy's scanning, communications, and timers outside
# PvP instances; restart them when the player enters a PvP instance.
spy_file=out/'Features'/'Awareness'/'Spy.lua'
spy_text=spy_file.read_text(encoding='utf-8-sig')
needle='function Spy:OnEnable(first)\n'
gate='''local function WildPvPInPvpInstance()
\tif type(IsInInstance) ~= "function" then return false end
\tlocal inside, kind = IsInInstance()
\treturn inside and (kind == "pvp" or kind == "arena")
end

local WildPvPZoneWatcher = CreateFrame("Frame")
WildPvPZoneWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
WildPvPZoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
WildPvPZoneWatcher:SetScript("OnEvent", function()
\tif not Spy or not Spy.db or not Spy.db.profile then return end
\tif WildPvPInPvpInstance() then
\t\tif Spy.db.profile.Enabled and not Spy.IsEnabled then Spy:OnEnable(true) end
\telseif Spy.IsEnabled then
\t\tSpy:OnDisable()
\tend
end)

'''+needle+'\tif not WildPvPInPvpInstance() then return end\n'
if needle not in spy_text: raise SystemExit('Could not find Spy activation point for PvP-only gate.')
spy_text=spy_text.replace(needle,gate,1)
spy_file.write_text(spy_text,encoding='utf-8',newline='')

# Expand source TOCs into one root TOC, preserving per-client file conditions and
# rewriting XML-relative includes to paths inside the unified addon folder.
entries=[]; saved=[]; savedchar=[]; optional=[]; seen=set(); missing=[]
for src,prefix,tocname in layout:
    root=out/prefix
    toc=(sources/src/tocname).read_text(encoding='utf-8-sig').splitlines()
    for raw in toc:
        line=raw.strip()
        if not line or line.startswith('#'): 
            m=re.match(r'##\s*(SavedVariables|SavedVariablesPerCharacter|OptionalDeps):\s*(.*)',line,re.I)
            if m:
                target={'savedvariables':saved,'savedvariablespercharacter':savedchar,'optionaldeps':optional}[m.group(1).lower()]
                target.extend(x.strip() for x in m.group(2).split(',') if x.strip())
            continue
        m=re.match(r'([^\[]+?)(\s+\[.*\])?$',line)
        if not m: continue
        rel=m.group(1).strip().replace('\\','/')
        cond=m.group(2) or ''
        srcfile=sources/src/rel
        dstfile=out/prefix/rel
        if not srcfile.is_file():
            missing.append(f'{src}/{rel}'); continue
        if srcfile.suffix.lower()=='.xml':
            xml=srcfile.read_text(encoding='utf-8-sig')
            def fix_attr(m):
                path=m.group(2).replace('\\','/')
                candidate=sources/src/path
                if candidate.is_file():
                    new=(Path(prefix)/path).as_posix().replace('/','\\')
                    return m.group(1)+new+m.group(3)
                return m.group(0)
            xml=re.sub(r'((?:file)=["\'])([^"\']+)(["\'])',fix_attr,xml)
            dstfile.write_text(xml,encoding='utf-8',newline='')
        item=(Path(prefix)/rel).as_posix().replace('/','\\')+cond
        if item not in seen:
            seen.add(item); entries.append(item)
if missing: raise SystemExit('Missing referenced files: '+', '.join(missing[:30]))
# Preserve the Highground TOC's dependency order exactly (Theme modules and utility tables are initialized in sequence).
intel_entries=[e for e in entries if e.startswith('Features\\Intel\\')]
entries=[e for e in entries if not e.startswith('Features\\Intel\\')]+intel_entries
bootstrap='''-- Shared private namespaces for integrated PvP feature code.\n_G.WildPvP_Capping = _G.WildPvP_Capping or {}\n_G.WildPvP_Intel = _G.WildPvP_Intel or {}\n_G.WildPvP_EnemyFrames = _G.WildPvP_EnemyFrames or {}\n'''
(out/'Bootstrap.lua').write_text(bootstrap,encoding='utf-8',newline='')
wildspark_toc=(repo/'Wildspark'/'WildSpark.toc').read_text(encoding='utf-8-sig')
version_match=re.search(r'(?m)^## Version:\s*(.+)$',wildspark_toc)
version=version_match.group(1).strip() if version_match else '1.0.0'
meta=['## Interface: 16001, 120105','## Title: WildPvP','## Author: Uncle Bone',f'## Version: {version}','## Notes: Unified WildPvP battleground and enemy awareness module','## SavedVariables: '+', '.join(dict.fromkeys(saved))]
if savedchar: meta.append('## SavedVariablesPerCharacter: '+', '.join(dict.fromkeys(savedchar)))
meta.append('## OptionalDeps: Blizzard_UnitFrame')
toc='\n'.join(meta+['']+entries)+'\n'
(out/'WildPvP.toc').write_text(toc,encoding='utf-8',newline='')
# Preserve notices/credits while keeping them out of player-facing addon labels.
licdir=out/'LICENSES'; licdir.mkdir()
for src,name in [('Capping','Timers-All-Rights-Reserved-Notice.txt'),('HighgroundBattlegrounds','Intel-MIT.txt'),('BattleGroundEnemiesFixed','EnemyFrames-GPL-2.0.txt')]:
    lic=sources/src/'LICENSE'
    if lic.exists(): shutil.copy2(lic,licdir/name)
(licdir/'Timers-All-Rights-Reserved-Notice.txt').write_text('Capping source notice from the supplied Capping.toc:\nX-License: All Rights Reserved: You are free to fork and modify on GitHub, please ask us about anything else.\nThe package owner separately confirms permission to combine the supplied source into WildPvP.\n',encoding='utf-8',newline='')
spyread=sources/'Spy'/'README.md'
if spyread.exists(): shutil.copy2(spyread,licdir/'Awareness-Credits.txt')
(licdir/'ATTRIBUTION.txt').write_text('WildPvP bundles authorized components from the supplied archives.\nNearby enemy alerts: Spy, originally created by Immolation; Forever port and maintenance by Slipjack.\nBattleground timers: Capping by Funkeh; original license notice retained in Timers-All-Rights-Reserved-Notice.txt.\nBattleground intel: Highground Battlegrounds by kemicofa; MIT license retained in Intel-MIT.txt.\nEnemy frames: BattleGroundEnemiesFixed by RBGDEV, with original BattleGroundEnemies credit to Bullsei; GPL-2.0 text retained in EnemyFrames-GPL-2.0.txt.\nThe package owner confirms permission to combine these supplied addons into WildPvP.\n',encoding='utf-8',newline='')
print(f'Created one addon folder with {len(entries)} TOC entries; saved variables: {len(saved)} + {len(savedchar)} per-character.')
for line in entries:
    path=line.split(' [',1)[0].replace('\\','/')
    if not (out/path).is_file(): raise SystemExit('Generated TOC path missing: '+path)
