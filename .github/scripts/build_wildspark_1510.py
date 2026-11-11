#!/usr/bin/env python3
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

repo = Path.cwd().resolve()
baseline = repo / "baseline" / "WildSpark-1.5.9.zip"
output_dir = repo / "dist"
output_dir.mkdir(exist_ok=True)
output_zip = output_dir / "WildSpark-1.5.12.zip"
if not baseline.is_file():
    raise SystemExit(f"Missing baseline package: {baseline}")

frame_section = """-- Keep Blizzard's native auction-house frame at scale 1 while hidden. Scaling it down
-- breaks the position and size calculations of its child controls when shown again.
do
    local blizzard_visible = false

    function M.fix_blizzard_frame_position()
        if not AuctionHouseFrame then return end
        AuctionHouseFrame:SetScale(1)
        AuctionHouseFrame:SetClampedToScreen(true)
    end

    function M.resize_blizzard_tabs()
        if not AuctionHouseFrame then return end
        local auctions_frame = AuctionHouseFrame.AuctionsFrame
        local empty_tabs = {}
        for _, tabs in ipairs{AuctionHouseFrame.Tabs, type(auctions_frame) == 'table' and auctions_frame.Tabs} do
            for _, tab in ipairs(type(tabs) == 'table' and tabs or empty_tabs) do
                local on_show = tab.GetScript and tab:GetScript('OnShow')
                if on_show and tab:IsShown() then pcall(on_show, tab) end
            end
        end
    end

    function M.blizzard_frame_shown()
        return blizzard_visible
    end

    function M.settle_side_panel()
        -- Keep Blizzard's normal adjacent-panel layout around its full-size auction house frame.
    end

    function M.hook_panel_layout() end

    function M.set_blizzard_frame_shown(shown)
        if not AuctionHouseFrame then return end
        blizzard_visible = shown
        AuctionHouseFrame:SetScale(1)
        if shown then
            M.fix_blizzard_frame_position()
            M.resize_blizzard_tabs()
            AuctionHouseFrame:SetClampedToScreen(true)
            AuctionHouseFrame:SetAlpha(1)
            AuctionHouseFrame:EnableMouse(true)
            AuctionHouseFrame:Raise()
        else
            AuctionHouseFrame:SetAlpha(0)
            AuctionHouseFrame:EnableMouse(false)
        end
        if type(M.update_blizzard_button) == 'function' then M.update_blizzard_button() end
    end

    local hooked
    function M.hook_blizzard_frame()
        if hooked or not AuctionHouseFrame then return end
        hooked = true
        AuctionHouseFrame:HookScript('OnShow', function(self)
            M.set_blizzard_frame_shown(false)
            self:UnregisterEvent('AUCTION_HOUSE_POST_WARNING')
            self:UnregisterEvent('AUCTION_HOUSE_POST_ERROR')
        end)
        AuctionHouseFrame:HookScript('OnHide', function()
            blizzard_visible = false
            if type(M.update_blizzard_button) == 'function' then M.update_blizzard_button() end
        end)
    end

    function event.AUCTION_HOUSE_LOADED()
        M.hook_blizzard_frame()
        M.hook_panel_layout()
    end
end

"""
license_name = re.compile(r"(^|/)(LICENSE|COPYING|NOTICE)(\.|$)", re.I)

def rewrite_text(name: str, data: bytes) -> bytes:
    if license_name.search(name):
        return data
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return data

    text = re.sub("auxForever", "WildAuctions", text, flags=re.I)

    if name == "WildSpark/WildSpark.toc":
        text = re.sub(r"(?m)^## Version:.*$", "## Version: 1.5.12", text)
        if not re.search(r"(?m)^## Author:", text):
            text = text.replace("## Title: WildSpark", "## Title: WildSpark\n## Author: Uncle Bone", 1)

    if name.endswith("/WildAuctions.toc"):
        text = re.sub(r"(?m)^## Author:.*$", "## Author: Uncle Bone", text)
        text = re.sub(r"(?m)^## Title:.*$", "## Title: WildAuctions", text)
        text = re.sub(r"(?m)^## Version:.*$", "## Version: 1.5.12", text)
        text = re.sub(r"(?m)^## Notes:.*$", "## Notes: Made by Uncle Bone", text)
    if name == "WildSpark/Modules/WildAuctions/aux-addon.lua":
        text = text.replace(
            "print('WildAuctions loaded. Full credit: shirsig and Tyler Hampton. Use /aux for help.')",
            "print('WildAuctions loaded. Made by Uncle Bone. Use /aux for help.')")
        start = text.find("-- Forever: Blizzard's AuctionHouseFrame")
        if start < 0:
            start = text.find("-- Keep Blizzard's native auction-house frame")
        end = text.find("function AUCTION_HOUSE_SHOW()", start)
        if start < 0 or end < 0:
            raise SystemExit("Could not find the Blizzard Auction House frame-management block.")
        text = text[:start] + frame_section + text[end:]
        # The native-frame helpers live on module M, not as loose globals.
        # The Blizzard bootstrap has already loaded Blizzard_AuctionHouseUI for this event.
        show_start = text.find("function AUCTION_HOUSE_SHOW()")
        show_end = text.find("\\nend", show_start)
        if show_start < 0 or show_end < 0:
            raise SystemExit("Could not locate AUCTION_HOUSE_SHOW handler.")
        show = text[show_start:show_end]
        show = show.replace("compat_load_auction_house_ui()", "-- Blizzard_AuctionHouseUI is loaded by Blizzard's bootstrap.")
        show = show.replace("hook_blizzard_frame()", "M.hook_blizzard_frame()")
        show = show.replace("hook_panel_layout()", "M.hook_panel_layout()")
        show = show.replace("set_blizzard_frame_shown(false)", "M.set_blizzard_frame_shown(false)")
        text = text[:show_start] + show + text[show_end:]
    if name == "WildSpark/Modules/WildAuctions/frame.lua":
        text = text.replace(
            "logo:SetText(color.text.enabled'aux' .. color.accent.background'Forever')",
            "logo:SetText(color.text.enabled'Wild' .. color.accent.background'Auctions')")
        text = text.replace(
            "label:SetText('aux by shirsig, re-imagined by a fan')",
            "label:SetText('Made by Uncle Bone')")
        text = text.replace(
            "GameTooltip:AddLine('It opens on top of aux. Click aux to bring aux back to the front.', 1, 1, 1, true)",
            "GameTooltip:AddLine('It opens on top of WildAuctions. Click WildAuctions to bring it back to the front.', 1, 1, 1, true)")
    if name == "WildSpark/Modules/WildAuctions/tabs/search/recipe.lua":
        text = text.replace("button:SetText('Search in aux')", "button:SetText('Search in WildAuctions')")
    if name == "WildSpark/Modules/WildAuctions/core/slash.lua":
        text = text.replace("GetAddOnMemoryUsage('WildAuctions')", "GetAddOnMemoryUsage('WildSpark')")
        text = text.replace("WildAuctions uses %.1f MB", "WildAuctions uses %.1f MB")
    if name == "WildSpark/Locales/enUS.lua":
        text = re.sub(
            r'(?m)^L\.WILDAUCTIONS_NOTE = .*?$',
            'L.WILDAUCTIONS_NOTE = "Auction house tools by Uncle Bone. Select the Auction House button to open WildAuctions."',
            text)
    if name == "WildSpark/README.txt":
        text = re.sub(r"(?m)^WildSpark \d+\.\d+\.\d+.*$", "WildSpark 1.5.12", text, count=1)
        if "Credits" in text:
            text = text[:text.rfind("Credits")] + (
                "Credits\nMade by Uncle Bone.\n"
                "Bundled components retain their original copyright and license notices in their included license files.\n")
        text = text.replace(
            "The Blizzard auction-house window is opened at normal scale to avoid broken child-control layout.",
            "WildAuctions keeps Blizzard's native auction-house frame at normal scale to prevent displaced controls.")
        text += "\n1.5.12: Fixes the Blizzard Auction House window layout, brands the auction module WildAuctions, and credits Uncle Bone in the module UI.\n"

    return text.encode("utf-8")

with zipfile.ZipFile(baseline, "r") as src, zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as dst:
    seen = set()
    for info in src.infolist():
        old_name = info.filename
        name = old_name
        if name == "WildSpark/Modules/WildAuctions/auxForever.toc":
            name = "WildSpark/Modules/WildAuctions/WildAuctions.toc"
        if name in seen:
            raise SystemExit(f"Duplicate archive path: {name}")
        seen.add(name)
        data = rewrite_text(old_name, src.read(info.filename))
        dst.writestr(name, data, compress_type=zipfile.ZIP_DEFLATED)

with zipfile.ZipFile(output_zip, "r") as z:
    required = [
        "WildSpark/WildSpark.toc",
        "WildSpark/Modules/WildAuctions/aux-addon.lua",
        "WildSpark/Modules/WildAuctions/frame.lua",
        "WildSpark/Modules/WildLayer/Modules/Detection.lua",
    ]
    missing = [name for name in required if name not in z.namelist()]
    if missing:
        raise SystemExit("Missing expected packaged files: " + ", ".join(missing))
    toc = z.read("WildSpark/WildSpark.toc").decode("utf-8")
    if "## Version: 1.5.12" not in toc:
        raise SystemExit("Packaged TOC version is not 1.5.12")
    ah = z.read("WildSpark/Modules/WildAuctions/aux-addon.lua").decode("utf-8")
    if ".01" in ah or "HIDDEN_SCALE" in ah:
        raise SystemExit("The old tiny-scale AH workaround remains in the package")

# Sync the exact installable source tree into this repository for future builds.
extract = Path(tempfile.mkdtemp(prefix="wildspark-1510-"))
try:
    with zipfile.ZipFile(output_zip, "r") as z:
        z.extractall(extract)
    addon_source = extract / "WildSpark"
    repo_addon = repo / "Wildspark"
    if addon_source.resolve().parent != extract.resolve():
        raise SystemExit("Refusing to sync an unexpected source path.")
    if repo_addon.exists() and repo_addon.resolve().parent == repo:
        shutil.rmtree(repo_addon)
    shutil.copytree(addon_source, repo_addon)

    readme = repo / "README.md"
    text = readme.read_text(encoding="utf-8")
    text = text.replace("/releases/download/v1.5.9/WildSpark-1.5.9.zip",
                        "/releases/download/v1.5.12/WildSpark-1.5.12.zip")
    text = text.replace("Current stable release: 1.5.9", "Current stable release: 1.5.12")
    text = text.replace("The 1.5.9 ZIP", "The 1.5.12 ZIP")
    text = text.replace("Version 1.5.6 adds", "Version 1.5.6 adds")
    text = text.replace("## Features\n", "## Features\n\n- Fix the Blizzard Auction House window layout when switching from WildAuctions to Blizzard UI; credits show Uncle Bone.\n", 1)
    readme.write_text(text, encoding="utf-8")

    subprocess.run(["git", "config", "user.name", "github-actions[bot]"], check=True)
    subprocess.run(["git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com"], check=True)
    subprocess.run(["git", "add", "Wildspark", "README.md"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "Sync WildSpark 1.5.12 source with AH layout fix"], cwd=repo, check=True)
    subprocess.run(["git", "push", "origin", "main"], cwd=repo, check=True)
    notes = """Fixes the broken Blizzard Auction House layout when switching from WildAuctions to Blizzard UI. The native AH frame stays at scale 1 while hidden, so its child controls do not get displaced. The WildAuctions UI and module credit now show WildAuctions and Made by Uncle Bone. WildLayer detection remains included; the observed GUID value is an ID, not an official numbered layer."""
    subprocess.run([
        "gh", "release", "create", "v1.5.12", str(output_zip),
        "--repo", subprocess.check_output(["git", "remote", "get-url", "origin"], cwd=repo, text=True).strip().replace("https://github.com/", "").replace(".git", ""),
        "--title", "WildSpark 1.5.12 — Auction House layout fix",
        "--notes", notes,
        "--target", "main",
        "--latest",
    ], cwd=repo, check=True)
finally:
    shutil.rmtree(extract, ignore_errors=True)
