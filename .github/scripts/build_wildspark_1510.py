#!/usr/bin/env python3
import re
import io
import cairosvg
from PIL import Image
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

repo = Path.cwd().resolve()
baseline = repo / "baseline" / "WildSpark-1.5.9.zip"
output_dir = repo / "dist"
output_dir.mkdir(exist_ok=True)
output_zip = output_dir / "WildSpark-1.5.15.zip"
if not baseline.is_file():
    raise SystemExit(f"Missing baseline package: {baseline}")

frame_section = """-- Keep Blizzard's native auction-house frame at scale 1 while hidden. Scaling it down
-- breaks the position and size calculations of its child controls when shown again.
do
    local blizzard_visible = false

    function fix_blizzard_frame_position()
        if not AuctionHouseFrame then return end
        AuctionHouseFrame:SetScale(1)
        AuctionHouseFrame:SetClampedToScreen(true)
    end

    function resize_blizzard_tabs()
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

    function blizzard_frame_shown()
        return blizzard_visible
    end

    function settle_side_panel()
        -- Keep Blizzard's normal adjacent-panel layout around its full-size auction house frame.
    end

    function hook_panel_layout() end

    function set_blizzard_frame_shown(shown)
        if not AuctionHouseFrame then return end
        blizzard_visible = shown
        AuctionHouseFrame:SetScale(1)
        if shown then
            fix_blizzard_frame_position()
            resize_blizzard_tabs()
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
    function hook_blizzard_frame()
        if hooked or not AuctionHouseFrame then return end
        hooked = true
        AuctionHouseFrame:HookScript('OnShow', function(self)
            set_blizzard_frame_shown(false)
            self:UnregisterEvent('AUCTION_HOUSE_POST_WARNING')
            self:UnregisterEvent('AUCTION_HOUSE_POST_ERROR')
        end)
        AuctionHouseFrame:HookScript('OnHide', function()
            blizzard_visible = false
            if type(M.update_blizzard_button) == 'function' then M.update_blizzard_button() end
        end)
    end

    function event.AUCTION_HOUSE_LOADED()
        hook_blizzard_frame()
        hook_panel_layout()
    end
end

"""
CAMPING_SVG = "<svg width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n<path d=\"M26.99 30H5.00999C3.34999 30 2 28.651 2 26.9923V18.9985C2 17.8993 2.89 17 4 17H28C29.1 17 30 17.8893 30 18.9985V26.9923C29.99 28.651 28.65 30 26.99 30Z\" fill=\"#608842\"/>\n<rect x=\"22.0054\" y=\"14.8491\" width=\"2.99908\" height=\"4.14536\" rx=\"0.2\" fill=\"#8C5543\"/>\n<path d=\"M26.4645 4.83594C26.3689 3.2623 25.0624 2.01562 23.4647 2.01562C21.8223 2.01562 20.4875 3.33312 20.4597 4.96892C20.4429 5.0891 20.4119 5.20055 20.3005 5.25443C18.9304 5.53422 17.8997 6.74624 17.8997 8.19902C17.8997 8.57729 17.9695 8.93924 18.0971 9.27266C18.0987 9.2824 18.1019 9.29327 18.107 9.30536C18.1676 9.44853 18.1274 9.62049 18.0283 9.74181C17.3981 10.2927 17 11.1026 17 12.0054C17 13.6486 18.3186 14.9837 19.9554 15.0104L19.9897 15.0108C19.995 15.0108 20.0002 15.0108 20.0054 15.0108C20.0106 15.0108 20.0159 15.0108 20.0211 15.0108H27.0365C27.0417 15.0108 27.0469 15.0108 27.0522 15.0108C27.0574 15.0108 27.0626 15.0108 27.0678 15.0108H27.0756C28.7247 14.9982 30.0576 13.6574 30.0576 12.0054C30.0576 11.0809 29.6401 10.2538 28.9834 9.70253C28.8138 9.52602 28.8548 9.28874 28.9043 9.11646C28.9125 9.09075 28.9204 9.0649 28.928 9.0389L28.9325 9.02452C28.9417 9.0062 28.9463 8.98808 28.947 8.97048C29.0122 8.72429 29.0469 8.46571 29.0469 8.19902C29.0469 6.77984 28.0632 5.59041 26.7405 5.27533C26.5658 5.21805 26.4759 4.9731 26.4645 4.83594Z\" fill=\"#96C34A\"/>\n<circle cx=\"7.80713\" cy=\"7.3241\" r=\"1.3197\" fill=\"#D3D3D3\"/>\n<path d=\"M8.28101 6.44211C7.9521 6.9656 7.74404 6.99256 7.36146 6.84494C7.15337 6.79347 6.96542 6.69055 6.48885 6.69055C5.37743 6.69055 4.41479 7.63026 4.41479 8.89887C4.41479 10.1675 5.27394 11.0401 6.96542 11.0401H10.9995C12.6574 11.0401 13.8388 9.65834 13.8388 7.89875C13.8388 6.13916 12.2211 5.02588 10.7914 5.02588C9.36169 5.02588 8.60992 5.91861 8.28101 6.44211Z\" fill=\"#E6E6E6\"/>\n<path d=\"M4.55108 24.4473C4.01586 25.8014 4.80256 26.0207 5.40228 26.0207H25.798C26.5275 26.0207 26.846 25.4273 26.4961 24.5352C26.3078 24.055 23.3307 16.6316 21.95 12.9836H9.57064C9.07641 12.9836 8.95873 13.3249 8.75869 13.8074C8.55864 14.2898 5.08629 23.0931 4.55108 24.4473Z\" fill=\"#F9C23C\"/>\n<path d=\"M13.0369 23.9872C12.5798 22.8806 10.7214 18.2537 9.84937 16.0786V26.022H15.0215C13.8989 26.022 13.6082 25.3705 13.0369 23.9872Z\" fill=\"#433B6B\"/>\n<path d=\"M9.86014 16.0808C9.6153 15.4772 9.11108 14.2292 9.05289 14.0663C9.04756 14.0514 9.04194 14.0359 9.03617 14.02C8.96317 13.8191 8.86403 13.5462 8.97263 13.3399V13.3357C8.90586 13.4506 8.84879 13.589 8.78499 13.7437C8.77636 13.7646 8.76761 13.7859 8.75869 13.8074C8.60086 14.188 6.40627 19.7477 5.2241 22.7426C4.90784 23.5438 4.66404 24.1615 4.55108 24.4473C4.01586 25.8014 4.80256 26.0207 5.40228 26.0207H9.54094V17.1328L9.86014 16.0808Z\" fill=\"#ED9200\"/>\n<path d=\"M9.87403 26.0195V16.0728C8.67831 19.3834 6.45513 25.3648 6.3645 25.6055C6.27388 25.8461 6.14445 25.9818 6.09106 26.0195H9.87403Z\" fill=\"#FF6723\"/>\n<path d=\"M16.3729 16.0056C15.5469 16.0056 15.2818 16.4834 15.539 17.1875C15.6293 17.4989 15.88 18.2858 16.1292 18.9574C16.4406 19.7969 16.892 20.0119 17.6367 20.0119H19.3428C20.1688 20.0119 20.2861 19.4313 20.1101 18.9574C19.9341 18.4835 19.6226 17.6304 19.3789 16.994C19.1352 16.3576 18.6612 16.0056 17.9165 16.0056H16.3729Z\" fill=\"#FF822D\"/>\n</svg>"
CAMPING_LICENSE = """Fluent Emoji Camping flat icon
Copyright (c) Microsoft Corporation
Source: https://github.com/microsoft/fluentui-emoji/tree/main/assets/Camping/Flat

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

def make_camping_tga():
    png = cairosvg.svg2png(bytestring=CAMPING_SVG.encode("utf-8"), output_width=64, output_height=64)
    image = Image.open(io.BytesIO(png)).convert("RGBA")
    output = io.BytesIO()
    image.save(output, format="TGA")
    return output.getvalue()

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
        text = re.sub(r"(?m)^## Version:.*$", "## Version: 1.5.15", text)
        if not re.search(r"(?m)^## Author:", text):
            text = text.replace("## Title: WildSpark", "## Title: WildSpark\n## Author: Uncle Bone", 1)

    if name.endswith("/WildAuctions.toc"):
        text = re.sub(r"(?m)^## Author:.*$", "## Author: Uncle Bone", text)
        text = re.sub(r"(?m)^## Title:.*$", "## Title: WildAuctions", text)
        text = re.sub(r"(?m)^## Version:.*$", "## Version: 1.5.15", text)
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
        show_end = text.find("\nend", show_start)
        if show_start < 0 or show_end < 0:
            raise SystemExit("Could not locate AUCTION_HOUSE_SHOW handler.")
        show = text[show_start:show_end]
        show = show.replace("compat_load_auction_house_ui()", "-- Blizzard_AuctionHouseUI is loaded by Blizzard's bootstrap.")
        show = show.replace("hook_blizzard_frame()", "hook_blizzard_frame()")
        show = show.replace("hook_panel_layout()", "hook_panel_layout()")
        show = show.replace("set_blizzard_frame_shown(false)", "set_blizzard_frame_shown(false)")
        text = text[:show_start] + show + text[show_end:]
    if name == "WildSpark/Menu.lua":
        text = text.replace('local TAB_RAIL_WIDTH = 80', 'local TAB_RAIL_WIDTH = 88')
        nl = chr(10)
        tab = chr(9)
        old_tabs = "local previous" + nl + tab + "for _, tab in ipairs(list) do"
        new_tabs = "local previous" + nl + tab + "local tab_top, tab_bottom = 56, 12" + nl + tab + "local tab_slot = (HEIGHT - tab_top - tab_bottom) / #list" + nl + tab + "local tab_index = 0" + nl + tab + "for _, tab in ipairs(list) do" + nl + tab * 2 + "tab_index = tab_index + 1"
        text = text.replace(old_tabs, new_tabs)
        tab_line = 'local button = Skin.SideTab(frame, previous, tab[2], function() Open(name) end)'
        tab_fit = tab_line + nl + tab * 2 + "local tab_height = button.GetHeight and button:GetHeight() or 32" + nl + tab * 2 + "button:SetScale(math.min(1, tab_slot / math.max(1, tab_height)))" + nl + tab * 2 + "button:ClearAllPoints()" + nl + tab * 2 + 'button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -tab_top - (tab_index - 1) * tab_slot)'
        text = text.replace(tab_line, tab_fit)
        menu_line = "local frame = menu or CreateMenu()"
        fit_lines = [
            tab + "local screen_width, screen_height = UIParent:GetWidth(), UIParent:GetHeight()",
            tab + "if screen_width and screen_height and screen_width > 0 and screen_height > 0 then",
            tab * 2 + "local fit_scale = math.max(0.65, math.min(1, (screen_width - 24) / WIDTH, (screen_height - 24) / HEIGHT))",
            tab * 2 + "frame:SetScale(fit_scale)",
            tab * 2 + "if fit_scale < 1 then",
            tab * 3 + "frame:ClearAllPoints()",
            tab * 3 + 'frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)',
            tab * 2 + "end",
            tab + "end",
            tab + "frame:SetClampedToScreen(true)",
        ]
        fit_block = menu_line + nl + nl.join(fit_lines)
        text = text.replace(menu_line, fit_block)
        text = text.replace('MEDIA .. "CampingKit' + chr(92) + chr(92) + 'tent_closed_48"', 'MEDIA .. "WildFireIcon"')
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
        text = re.sub(r"(?m)^WildSpark \d+\.\d+\.\d+.*$", "WildSpark 1.5.15", text, count=1)
        if "Credits" in text:
            text = text[:text.rfind("Credits")] + (
                "Credits\nMade by Uncle Bone.\n"
                "Bundled components retain their original copyright and license notices in their included license files.\n")
        text = text.replace(
            "The Blizzard auction-house window is opened at normal scale to avoid broken child-control layout.",
            "WildAuctions keeps Blizzard's native auction-house frame at normal scale to prevent displaced controls.")
        text += "\n1.5.15: Fixes the Blizzard Auction House window layout, brands the auction module WildAuctions, and credits Uncle Bone in the module UI.\n"

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
    dst.writestr("WildSpark/Media/WildFireIcon.tga", make_camping_tga(), compress_type=zipfile.ZIP_DEFLATED)
    dst.writestr("WildSpark/Media/WildFireIcon-LICENSE.txt", CAMPING_LICENSE, compress_type=zipfile.ZIP_DEFLATED)

with zipfile.ZipFile(output_zip, "r") as z:
    required = [
        "WildSpark/WildSpark.toc",
        "WildSpark/Modules/WildAuctions/aux-addon.lua",
        "WildSpark/Modules/WildAuctions/frame.lua",
        "WildSpark/Modules/WildLayer/Modules/Detection.lua",
        "WildSpark/Media/WildFireIcon.tga",
    ]
    missing = [name for name in required if name not in z.namelist()]
    if missing:
        raise SystemExit("Missing expected packaged files: " + ", ".join(missing))
    toc = z.read("WildSpark/WildSpark.toc").decode("utf-8")
    if "## Version: 1.5.15" not in toc:
        raise SystemExit("Packaged TOC version is not 1.5.15")
    ah = z.read("WildSpark/Modules/WildAuctions/aux-addon.lua").decode("utf-8")
    if "M.hook_blizzard_frame()" in ah or "M.hook_panel_layout()" in ah:
        raise SystemExit("Blizzard frame helpers must resolve in the WildAuctions module scope")
    menu = z.read("WildSpark/Menu.lua").decode("utf-8")
    if "WildFireIcon" not in menu or "tab_slot" not in menu or "fit_scale" not in menu:
        raise SystemExit("WildSpark tab layout or WildFire icon patch is missing")
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
    text = re.sub(r"/releases/download/v1\\.5\\.\\d+/WildSpark-1\\.5\\.\\d+\\.zip",
                   "/releases/download/v1.5.15/WildSpark-1.5.15.zip", text)
    text = re.sub(r"Current stable release: 1\\.5\\.\\d+", "Current stable release: 1.5.15", text)
    text = re.sub(r"WildSpark 1\\.5\\.\\d+ — Latest Stable", "WildSpark 1.5.15 — Latest Stable", text)
    text = text.replace("Version 1.5.6 adds", "Version 1.5.6 adds")
    text = text.replace("## Features\n", "## Features\n\n- Fix the Blizzard Auction House window layout when switching from WildAuctions to Blizzard UI; credits show Uncle Bone.\n", 1)
    readme.write_text(text, encoding="utf-8")

    subprocess.run(["git", "config", "user.name", "github-actions[bot]"], check=True)
    subprocess.run(["git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com"], check=True)
    subprocess.run(["git", "add", "Wildspark", "README.md"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "Sync WildSpark 1.5.15 source with AH and panel fixes"], cwd=repo, check=True)
    subprocess.run(["git", "push", "origin", "main"], cwd=repo, check=True)
    notes = """Fixes WildAuctions nil helper calls in the Blizzard Auction House hook, keeps the native auction-house frame at scale 1, fits the WildSpark settings window to smaller screens, spaces the module tab rail so all tabs stay inside the panel, and gives WildFire a distinct Fluent Emoji Camping icon. The icon's Microsoft MIT license notice is included."""
    subprocess.run([
        "gh", "release", "create", "v1.5.15", str(output_zip),
        "--repo", subprocess.check_output(["git", "remote", "get-url", "origin"], cwd=repo, text=True).strip().replace("https://github.com/", "").replace(".git", ""),
        "--title", "WildSpark 1.5.15 — Auction House and panel fixes",
        "--notes", notes,
        "--target", "main",
        "--latest",
    ], cwd=repo, check=True)
finally:
    shutil.rmtree(extract, ignore_errors=True)
