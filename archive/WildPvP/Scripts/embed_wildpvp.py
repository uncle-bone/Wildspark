from pathlib import Path
import re, shutil, sys
bundle=Path(sys.argv[1]).resolve()
addon=Path(sys.argv[2]).resolve()
toc_bundle=bundle/'WildPvP.toc'
toc_root=addon/'WildSpark.toc'
dest=addon/'Modules'/'WildPvP'
if not toc_bundle.is_file() or not toc_root.is_file(): raise SystemExit('Expected WildPvP source manifest and WildSpark addon folder.')
if dest.exists(): shutil.rmtree(dest)
shutil.copytree(bundle,dest,ignore=shutil.ignore_patterns('WildPvP.toc'))
# Each source used its original private namespace as if it were a standalone
# addon. Keep the feature namespaces isolated, while binding addon-load events,
# metadata lookup and asset paths to the actual WildSpark addon folder.
for path in dest.rglob('*.lua'):
    text=path.read_text(encoding='utf-8-sig')
    text=text.replace('"WildPvP", _G.WildPvP_Capping','"WildSpark", _G.WildPvP_Capping')
    text=text.replace('"WildPvP", _G.WildPvP_Intel','"WildSpark", _G.WildPvP_Intel')
    text=text.replace('"WildPvP", _G.WildPvP_EnemyFrames','"WildSpark", _G.WildPvP_EnemyFrames')
    text=text.replace('local AddonName = "WildPvP"','local AddonName = "WildSpark"')
    text=text.replace('if addon == "WildPvP" then','if addon == "WildSpark" then')
    text=text.replace('Interface\\\\AddOns\\\\WildPvP\\\\Features\\\\','Interface\\\\AddOns\\\\WildSpark\\\\Modules\\\\WildPvP\\\\Features\\\\')
    path.write_text(text,encoding='utf-8',newline='')
for path in dest.rglob('*.xml'):
    text=path.read_text(encoding='utf-8-sig')
    text=text.replace('file="Features\\','file="Modules\\WildPvP\\Features\\')
    text=text.replace("file='Features\\", "file='Modules\\WildPvP\\Features\\")
    path.write_text(text,encoding='utf-8',newline='')
source_lines=toc_bundle.read_text(encoding='utf-8-sig').splitlines()
saved=[]; savedchar=[]; entries=[]
for line in source_lines:
    if line.startswith('## SavedVariables:'): saved += [x.strip() for x in line.split(':',1)[1].split(',') if x.strip()]
    elif line.startswith('## SavedVariablesPerCharacter:'): savedchar += [x.strip() for x in line.split(':',1)[1].split(',') if x.strip()]
    elif line and not line.startswith('#'):
        entries.append('Modules\\WildPvP\\'+line)
text= toc_root.read_text(encoding='utf-8-sig')
lines=text.splitlines()
# The source tree may contain a stale partial PvP merge. Rebuild that block
# from the single generated manifest so files and libraries cannot load twice.
lines=[line for line in lines if not (line.startswith('Modules\\WildPvP\\') and line != 'Modules\\WildPvPModule.lua')]
for i,line in enumerate(lines):
    if line.startswith('## SavedVariables:'):
        values=[x.strip() for x in line.split(':',1)[1].split(',') if x.strip()]
        lines[i]='## SavedVariables: '+', '.join(dict.fromkeys(values+saved))
    elif line.startswith('## SavedVariablesPerCharacter:'):
        values=[x.strip() for x in line.split(':',1)[1].split(',') if x.strip()]
        lines[i]='## SavedVariablesPerCharacter: '+', '.join(dict.fromkeys(values+savedchar))
    elif line.startswith('## OptionalDeps:'):
        values=[x.strip() for x in line.split(':',1)[1].split(',') if x.strip() and x.strip()!='WildPvP']
        if 'Blizzard_UnitFrame' not in values: values.append('Blizzard_UnitFrame')
        lines[i]='## OptionalDeps: '+', '.join(dict.fromkeys(values))
boot='Modules\\WildPvP\\Bootstrap.lua'
lines=[x for x in lines if x!=boot]
anchor='Modules\\WildPvPModule.lua'
if anchor not in lines: raise SystemExit('WildPvP module tab launcher is missing from the base manifest.')
index=lines.index(anchor)+1
lines[index:index]=[boot]+entries
text='\n'.join(lines)+'\n'
toc_root.write_text(text,encoding='utf-8',newline='')
# Assert every newly inserted TOC path exists below the one WildSpark addon root.
for entry in entries:
    rel=entry.split(' [',1)[0].replace('\\','/')
    if not (addon/rel).is_file(): raise SystemExit('Embedded TOC entry is missing: '+rel)
if (addon/'WildPvP.toc').exists() or (dest/'WildPvP.toc').exists(): raise SystemExit('WildPvP must not have a second addon manifest.')
print(f'Embedded {len(entries)} PvP source files into WildSpark; no separate WildPvP addon folder or TOC.')
