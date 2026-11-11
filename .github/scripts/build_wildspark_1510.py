#!/usr/bin/env python3
import re
import io
import cairosvg
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

repo = Path.cwd().resolve()
baseline = repo / "baseline" / "WildSpark-1.5.9.zip"
output_dir = repo / "dist"
output_dir.mkdir(exist_ok=True)
output_zip = output_dir / "WildSpark-1.5.18.zip"
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
CAMPING_SVGS = {
    "camping": "<svg width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n<path d=\"M26.99 30H5.00999C3.34999 30 2 28.651 2 26.9923V18.9985C2 17.8993 2.89 17 4 17H28C29.1 17 30 17.8893 30 18.9985V26.9923C29.99 28.651 28.65 30 26.99 30Z\" fill=\"#608842\"/>\n<rect x=\"22.0054\" y=\"14.8491\" width=\"2.99908\" height=\"4.14536\" rx=\"0.2\" fill=\"#8C5543\"/>\n<path d=\"M26.4645 4.83594C26.3689 3.2623 25.0624 2.01562 23.4647 2.01562C21.8223 2.01562 20.4875 3.33312 20.4597 4.96892C20.4429 5.0891 20.4119 5.20055 20.3005 5.25443C18.9304 5.53422 17.8997 6.74624 17.8997 8.19902C17.8997 8.57729 17.9695 8.93924 18.0971 9.27266C18.0987 9.2824 18.1019 9.29327 18.107 9.30536C18.1676 9.44853 18.1274 9.62049 18.0283 9.74181C17.3981 10.2927 17 11.1026 17 12.0054C17 13.6486 18.3186 14.9837 19.9554 15.0104L19.9897 15.0108C19.995 15.0108 20.0002 15.0108 20.0054 15.0108C20.0106 15.0108 20.0159 15.0108 20.0211 15.0108H27.0365C27.0417 15.0108 27.0469 15.0108 27.0522 15.0108C27.0574 15.0108 27.0626 15.0108 27.0678 15.0108H27.0756C28.7247 14.9982 30.0576 13.6574 30.0576 12.0054C30.0576 11.0809 29.6401 10.2538 28.9834 9.70253C28.8138 9.52602 28.8548 9.28874 28.9043 9.11646C28.9125 9.09075 28.9204 9.0649 28.928 9.0389L28.9325 9.02452C28.9417 9.0062 28.9463 8.98808 28.947 8.97048C29.0122 8.72429 29.0469 8.46571 29.0469 8.19902C29.0469 6.77984 28.0632 5.59041 26.7405 5.27533C26.5658 5.21805 26.4759 4.9731 26.4645 4.83594Z\" fill=\"#96C34A\"/>\n<circle cx=\"7.80713\" cy=\"7.3241\" r=\"1.3197\" fill=\"#D3D3D3\"/>\n<path d=\"M8.28101 6.44211C7.9521 6.9656 7.74404 6.99256 7.36146 6.84494C7.15337 6.79347 6.96542 6.69055 6.48885 6.69055C5.37743 6.69055 4.41479 7.63026 4.41479 8.89887C4.41479 10.1675 5.27394 11.0401 6.96542 11.0401H10.9995C12.6574 11.0401 13.8388 9.65834 13.8388 7.89875C13.8388 6.13916 12.2211 5.02588 10.7914 5.02588C9.36169 5.02588 8.60992 5.91861 8.28101 6.44211Z\" fill=\"#E6E6E6\"/>\n<path d=\"M4.55108 24.4473C4.01586 25.8014 4.80256 26.0207 5.40228 26.0207H25.798C26.5275 26.0207 26.846 25.4273 26.4961 24.5352C26.3078 24.055 23.3307 16.6316 21.95 12.9836H9.57064C9.07641 12.9836 8.95873 13.3249 8.75869 13.8074C8.55864 14.2898 5.08629 23.0931 4.55108 24.4473Z\" fill=\"#F9C23C\"/>\n<path d=\"M13.0369 23.9872C12.5798 22.8806 10.7214 18.2537 9.84937 16.0786V26.022H15.0215C13.8989 26.022 13.6082 25.3705 13.0369 23.9872Z\" fill=\"#433B6B\"/>\n<path d=\"M9.86014 16.0808C9.6153 15.4772 9.11108 14.2292 9.05289 14.0663C9.04756 14.0514 9.04194 14.0359 9.03617 14.02C8.96317 13.8191 8.86403 13.5462 8.97263 13.3399V13.3357C8.90586 13.4506 8.84879 13.589 8.78499 13.7437C8.77636 13.7646 8.76761 13.7859 8.75869 13.8074C8.60086 14.188 6.40627 19.7477 5.2241 22.7426C4.90784 23.5438 4.66404 24.1615 4.55108 24.4473C4.01586 25.8014 4.80256 26.0207 5.40228 26.0207H9.54094V17.1328L9.86014 16.0808Z\" fill=\"#ED9200\"/>\n<path d=\"M9.87403 26.0195V16.0728C8.67831 19.3834 6.45513 25.3648 6.3645 25.6055C6.27388 25.8461 6.14445 25.9818 6.09106 26.0195H9.87403Z\" fill=\"#FF6723\"/>\n<path d=\"M16.3729 16.0056C15.5469 16.0056 15.2818 16.4834 15.539 17.1875C15.6293 17.4989 15.88 18.2858 16.1292 18.9574C16.4406 19.7969 16.892 20.0119 17.6367 20.0119H19.3428C20.1688 20.0119 20.2861 19.4313 20.1101 18.9574C19.9341 18.4835 19.6226 17.6304 19.3789 16.994C19.1352 16.3576 18.6612 16.0056 17.9165 16.0056H16.3729Z\" fill=\"#FF822D\"/>\n</svg>\n",
    "backpack": "<svg width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n<path d=\"M16.0899 3.59C14.2011 3.59 12.6699 5.12118 12.6699 7.01C12.6699 8.89881 14.2011 10.43 16.0899 10.43C17.9787 10.43 19.5099 8.89881 19.5099 7.01C19.5099 5.12118 17.9787 3.59 16.0899 3.59ZM11.1699 7.01C11.1699 4.29276 13.3727 2.09 16.0899 2.09C18.8072 2.09 21.0099 4.29276 21.0099 7.01C21.0099 9.72724 18.8072 11.93 16.0899 11.93C13.3727 11.93 11.1699 9.72724 11.1699 7.01Z\" fill=\"#CA0B4A\"/>\n<path d=\"M23.35 30H8.74C6.67 30 5 28.32 5 26.26V16.11C5 10.01 9.95 5.06 16.05 5.06C22.15 5.06 27.1 10.01 27.1 16.11V26.26C27.09 28.32 25.42 30 23.35 30Z\" fill=\"#F8312F\"/>\n<path d=\"M8 25.57C8 20.79 11.5792 16.92 16 16.92C20.4208 16.92 24 20.79 24 25.57V24.7C24 19.92 20.4208 16.05 16 16.05C11.5792 16.05 8 19.92 8 24.7V25.57Z\" fill=\"#CA0B4A\"/>\n<path d=\"M8.36589 11.5783C8.25899 11.8323 7.96651 11.952 7.71209 11.8456C7.45733 11.7391 7.3372 11.4462 7.44376 11.1914L7.44426 11.1902L7.44495 11.1886L7.44691 11.184L7.45317 11.1695C7.45839 11.1576 7.46571 11.1412 7.4752 11.1206C7.49419 11.0794 7.52188 11.0212 7.5588 10.9486C7.6326 10.8034 7.74349 10.5999 7.89574 10.3576C8.19988 9.87356 8.6714 9.23083 9.34518 8.58817C10.6993 7.29658 12.8617 6.01562 16.0775 6.01562C19.2945 6.01562 21.4135 7.29769 22.7239 8.59461C23.3753 9.23928 23.8237 9.88397 24.1103 10.3694C24.2537 10.6125 24.3572 10.8166 24.4258 10.9624C24.4601 11.0353 24.4857 11.0937 24.5032 11.1352C24.5119 11.1559 24.5187 11.1724 24.5235 11.1844L24.5293 11.199L24.5311 11.2037L24.5317 11.2054L24.5322 11.2066C24.6303 11.4648 24.5007 11.7535 24.2426 11.8517C23.9848 11.9497 23.6964 11.8205 23.5979 11.563L23.5975 11.5621L23.5952 11.5563L23.5876 11.5376L23.5819 11.5242C23.5693 11.4943 23.5492 11.4481 23.5208 11.3879C23.4642 11.2674 23.3751 11.0912 23.2491 10.8778C22.9968 10.4504 22.5989 9.87786 22.0204 9.30536C20.8712 8.16792 18.9965 7.01562 16.0775 7.01562C13.1574 7.01562 11.2335 8.16903 10.0354 9.31179C9.43304 9.88631 9.01193 10.4608 8.74247 10.8896C8.60792 11.1038 8.51178 11.2806 8.45024 11.4017C8.41949 11.4622 8.39743 11.5087 8.38359 11.5387C8.37667 11.5538 8.37181 11.5647 8.36895 11.5712L8.3663 11.5773L8.36589 11.5783Z\" fill=\"#FCD53F\"/>\n<path d=\"M17.85 12.09H14.25C13.838 12.09 13.4751 11.8858 13.2568 11.5727C13.1201 11.3767 13.04 11.138 13.04 10.88V10.28C13.04 9.61001 13.58 9.07001 14.25 9.07001H17.84C18.51 9.07001 19.05 9.61001 19.05 10.28V10.88C19.0539 11.1355 18.9777 11.372 18.8449 11.5669C18.6294 11.8833 18.2646 12.09 17.85 12.09Z\" fill=\"#FCD53F\"/>\n<path d=\"M8.03853 23.59C8.42853 23.59 8.75853 23.88 8.80853 24.26L9.07853 26.12C9.13853 26.58 8.77853 27 8.30853 27H7.77853C7.30853 27 6.93853 26.59 7.00853 26.12L7.26853 24.26C7.32853 23.87 7.64853 23.59 8.03853 23.59ZM7.60853 24.36C7.60853 24.6 7.79853 24.79 8.03853 24.79C8.27853 24.79 8.46853 24.6 8.46853 24.36C8.46853 24.12 8.27853 23.93 8.03853 23.93C7.79853 23.93 7.60853 24.12 7.60853 24.36Z\" fill=\"#FCD53F\"/>\n</svg>\n",
    "clipboard": "<svg width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n<path d=\"M5 4.5C5 3.67157 5.67157 3 6.5 3H25.5C26.3284 3 27 3.67157 27 4.5V28.5C27 29.3284 26.3284 30 25.5 30H6.5C5.67157 30 5 29.3284 5 28.5V4.5Z\" fill=\"#E19747\"/>\n<path d=\"M25 6C25 5.44772 24.5523 5 24 5H8C7.44772 5 7 5.44772 7 6V27C7 27.5523 7.44772 28 8 28H18.5858C18.7327 28 18.8764 27.9677 19.0071 27.9069L19.3282 27.1239L19.96 23.0379L24.4166 22.255L24.9064 22.0082C24.9675 21.8772 25 21.7332 25 21.5858V6Z\" fill=\"#F3EEF8\"/>\n<path d=\"M24.9102 22H20C19.4477 22 19 22.4477 19 23V27.9102C19.108 27.861 19.2074 27.7926 19.2929 27.7071L24.7071 22.2929C24.7926 22.2074 24.861 22.108 24.9102 22Z\" fill=\"#CDC4D6\"/>\n<path d=\"M18 4C18 2.89543 17.1046 2 16 2C14.8954 2 14 2.89543 14 4H13C11.8954 4 11 4.89543 11 6V7.5C11 7.77614 11.2239 8 11.5 8H20.5C20.7761 8 21 7.77614 21 7.5V6C21 4.89543 20.1046 4 19 4H18ZM17 4C17 4.55228 16.5523 5 16 5C15.4477 5 15 4.55228 15 4C15 3.44772 15.4477 3 16 3C16.5523 3 17 3.44772 17 4Z\" fill=\"#9B9B9B\"/>\n<path d=\"M9 12.5C9 12.2239 9.22386 12 9.5 12H22.5C22.7761 12 23 12.2239 23 12.5C23 12.7761 22.7761 13 22.5 13H9.5C9.22386 13 9 12.7761 9 12.5Z\" fill=\"#9B9B9B\"/>\n<path d=\"M9 15.5C9 15.2239 9.22386 15 9.5 15H22.5C22.7761 15 23 15.2239 23 15.5C23 15.7761 22.7761 16 22.5 16H9.5C9.22386 16 9 15.7761 9 15.5Z\" fill=\"#9B9B9B\"/>\n<path d=\"M9.5 18C9.22386 18 9 18.2239 9 18.5C9 18.7761 9.22386 19 9.5 19H22.5C22.7761 19 23 18.7761 23 18.5C23 18.2239 22.7761 18 22.5 18H9.5Z\" fill=\"#9B9B9B\"/>\n<path d=\"M9 21.5C9 21.2239 9.22386 21 9.5 21H17.5C17.7761 21 18 21.2239 18 21.5C18 21.7761 17.7761 22 17.5 22H9.5C9.22386 22 9 21.7761 9 21.5Z\" fill=\"#9B9B9B\"/>\n</svg>\n",
    "speech": "<svg width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n<path d=\"M16.0278 4C8.16615 4 3.53108 9.75575 1.66714 12.7026C0.772249 14.1175 0.772247 15.8825 1.66714 17.2974C3.53108 20.2442 8.16615 26 16.0278 26C17.2577 26 18.413 25.8582 19.4936 25.6063L23.8434 27.8365C24.8416 28.3483 26.0278 27.6235 26.0278 26.5017V22.3015C28.083 20.6044 29.5201 18.6702 30.3884 17.2974C31.2833 15.8825 31.2833 14.1175 30.3884 12.7026C28.5245 9.75575 23.8894 4 16.0278 4Z\" fill=\"#9B9B9B\"/>\n<path d=\"M24.2997 26.9467L19.6172 24.5458C18.5104 24.8344 17.3146 25 16.0278 25C8.70189 25 4.32778 19.6331 2.51227 16.7628C1.82387 15.6744 1.82387 14.3256 2.51228 13.2372C4.32778 10.3669 8.7019 5 16.0278 5C23.3537 5 27.7278 10.3669 29.5433 13.2372C30.2317 14.3256 30.2317 15.6744 29.5433 16.7628C28.6595 18.16 27.1695 20.1489 25.0278 21.8222V26.5017C25.0278 26.8757 24.6324 27.1173 24.2997 26.9467Z\" fill=\"white\"/>\n</svg>\n",
}
CAMPING_LICENSE = """Fluent Emoji flat icons included in WildSpark: Camping, Backpack, Clipboard, and Left Speech Bubble.
Copyright (c) Microsoft Corporation
Sources:
https://github.com/microsoft/fluentui-emoji/tree/main/assets/Camping/Flat
https://github.com/microsoft/fluentui-emoji/tree/main/assets/Backpack/Flat
https://github.com/microsoft/fluentui-emoji/tree/main/assets/Clipboard/Flat
https://github.com/microsoft/fluentui-emoji/tree/main/assets/Left%20speech%20bubble/Flat

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
ARTWORK_NOTICE = """WildSpark replaces all original CampingKit media artwork with new assets.

The original tent, kit, control, ring, glow, mask, and divider artwork described in CampingKitEmbedded/LICENSE is not included in this package. Code and bundled libraries retain their original notices. Replacement emoji art is from Microsoft Fluent Emoji under MIT; its full notice is in Media/WildFireIcon-LICENSE.txt. The remaining masks and UI effects are clean replacement textures generated for WildSpark."""

def to_tga(image):
    output = io.BytesIO()
    image.convert("RGBA").save(output, format="TGA")
    return output.getvalue()

def render_fluent(name, size):
    png = cairosvg.svg2png(bytestring=CAMPING_SVGS[name].encode("utf-8"), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")

def _downsample(image, size):
    return image.resize((size, size), Image.Resampling.LANCZOS)

def _ring(size, dashed=False, double=False):
    factor = 4
    px = size * factor
    image = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    margin = int(size * factor * 0.12)
    box = (margin, margin, px - margin - 1, px - margin - 1)
    width = max(2, int(size * factor * 0.045))
    color = (255, 255, 255, 225)
    if dashed:
        for angle in range(0, 360, 45):
            draw.arc(box, angle + 4, angle + 29, fill=color, width=width)
    else:
        draw.ellipse(box, outline=color, width=width)
    if double:
        inner = margin + int(size * factor * 0.085)
        draw.ellipse((inner, inner, px-inner-1, px-inner-1), outline=(255,255,255,150), width=max(1,width//2))
    return _downsample(image, size)

def _glow(size, square=False):
    factor = 4
    px = size * factor
    base = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    draw = ImageDraw.Draw(base)
    inset = int(px * 0.17)
    width = max(2, int(px * 0.05))
    if square:
        draw.rounded_rectangle((inset, inset, px-inset, px-inset), radius=int(px*0.12),
                               outline=(255, 211, 112, 220), width=width)
    else:
        draw.ellipse((inset, inset, px-inset, px-inset), outline=(255, 211, 112, 220), width=width)
    blur = base.filter(ImageFilter.GaussianBlur(max(2, px * 0.045)))
    blur.alpha_composite(base)
    return _downsample(blur, size)

def _divider():
    width, height, factor = 256, 16, 4
    image = Image.new("RGBA", (width*factor, height*factor), (0,0,0,0))
    draw = ImageDraw.Draw(image)
    w, h = image.size
    mid = h // 2
    for x in range(w):
        fade = min(1.0, x/(w*0.22), (w-x)/(w*0.22))
        alpha = max(0, int(210 * fade))
        draw.line((x, mid, x, mid+factor-1), fill=(236, 190, 91, alpha))
    cx, cy = w//2, mid
    r=2*factor
    draw.polygon([(cx,cy-r),(cx+r,cy),(cx,cy+r),(cx-r,cy)], fill=(255,226,150,230))
    return image.resize((width,height), Image.Resampling.LANCZOS)

def _mask(size):
    factor=4
    px=size*factor
    image=Image.new("RGBA",(px,px),(0,0,0,255))
    draw=ImageDraw.Draw(image)
    margin=2*factor
    draw.ellipse((margin,margin,px-margin-1,px-margin-1),fill=(255,255,255,255))
    return _downsample(image,size)

def _pin(size=32):
    factor=4
    px=size*factor
    image=Image.new("RGBA",(px,px),(0,0,0,0))
    draw=ImageDraw.Draw(image)
    draw.ellipse((2*factor,2*factor,px-2*factor,px-2*factor),fill=(116,70,20,220))
    draw.ellipse((4*factor,4*factor,px-4*factor,px-4*factor),fill=(255,190,64,255))
    draw.ellipse((8*factor,8*factor,px-8*factor,px-8*factor),fill=(255,246,202,255))
    return _downsample(image,size)

def _slot_border(size=64):
    factor=4
    px=size*factor
    image=Image.new("RGBA",(px,px),(0,0,0,0))
    draw=ImageDraw.Draw(image)
    inset=2*factor
    draw.rounded_rectangle((inset,inset,px-inset-1,px-inset-1),radius=7*factor,
                           outline=(226,190,118,230),width=max(2,factor*2))
    return _downsample(image,size)

def generate_wildfire_art():
    assets={}
    for stem,size in [("tent_closed",32),("tent_closed",48),("tent_closed",64),("tent_closed",96),("tent_closed",128),("tent_closed",256),
                      ("tent_open",32),("tent_open",48),("tent_open",64),("tent_open",96),("tent_open",128),("tent_open",256)]:
        icon=render_fluent("camping",size)
        if stem == "tent_open":
            icon=ImageEnhance.Brightness(icon).enhance(1.08)
        assets[f"{stem}_{size}.tga"]=to_tga(icon)
    for size in (32,48,64,96,128):
        assets[f"wildfire_pack_{size}.tga"]=to_tga(render_fluent("backpack",size))
    assets["camp_list.tga"]=to_tga(render_fluent("clipboard",64))
    assets["chat_bubble.tga"]=to_tga(render_fluent("speech",64))
    assets["circle_mask.tga"]=to_tga(_mask(128))
    assets["divider.tga"]=to_tga(_divider())
    assets["glow_ring.tga"]=to_tga(_glow(64))
    assets["glow_square.tga"]=to_tga(_glow(64, square=True))
    assets["pin_dot.tga"]=to_tga(_pin(32))
    assets["ring_dashed_64.tga"]=to_tga(_ring(64,dashed=True))
    for size in (128,32,48,64):
        assets[f"ring_prof_{size}.tga"]=to_tga(_ring(size,double=True))
    for size in (128,256,32,48,64,96):
        assets[f"ring_slot_{size}.tga"]=to_tga(_ring(size,double=True))
    assets["ring_small.tga"]=to_tga(_ring(32))
    assets["slot_border.tga"]=to_tga(_slot_border(64))
    return assets

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
        text = re.sub(r"(?m)^## Version:.*$", "## Version: 1.5.18", text)
        if not re.search(r"(?m)^## Author:", text):
            text = text.replace("## Title: WildSpark", "## Title: WildSpark\n## Author: Uncle Bone", 1)

    if name.endswith("/WildAuctions.toc"):
        text = re.sub(r"(?m)^## Author:.*$", "## Author: Uncle Bone", text)
        text = re.sub(r"(?m)^## Title:.*$", "## Title: WildAuctions", text)
        text = re.sub(r"(?m)^## Version:.*$", "## Version: 1.5.18", text)
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
    if name == "WildSpark/CampingKitEmbedded/Data.lua":
        old_path = "Media" + chr(92)*2 + "CampingKit" + chr(92)*2
        new_path = "Media" + chr(92)*2 + "WildFire" + chr(92)*2
        text = text.replace(old_path, new_path)
    if name == "WildSpark/CampingKitEmbedded/Libs/KitDock/KitDock.lua":
        old_path = "Media" + chr(92)*2 + "CampingKit" + chr(92)*2
        new_path = "Media" + chr(92)*2 + "WildFire" + chr(92)*2
        text = text.replace(old_path, new_path)
        text = text.replace("kits_chest_", "wildfire_pack_")
    if name == "WildSpark/Modules/WildAuctions/aux-addon.lua":
        text = text.replace("post_duration = post.DURATION_8,", "post_duration = post.DURATION_24,")
    if name == "WildSpark/Modules/WildAuctions/tabs/post/core.lua":
        nl = chr(10)
        tab = chr(9)
        old_login = "function aux.event.PLAYER_LOGIN()" + nl + tab + "data = aux.faction_data.post" + nl + "end"
        new_login = "function aux.event.PLAYER_LOGIN()" + nl + tab + "data = aux.faction_data.post" + nl + tab + "if not aux.account_data.wildspark_1517_duration_migrated then" + nl + tab*2 + "if aux.account_data.post_duration == M.DURATION_8 then" + nl + tab*3 + "aux.account_data.post_duration = M.DURATION_24" + nl + tab*2 + "end" + nl + tab*2 + "for item_key, saved_record in pairs(data) do" + nl + tab*3 + "local saved = persistence.read(settings_schema, saved_record)" + nl + tab*3 + "if saved and saved.duration == M.DURATION_8 then" + nl + tab*4 + "saved.duration = M.DURATION_24" + nl + tab*4 + "data[item_key] = persistence.write(settings_schema, saved)" + nl + tab*3 + "end" + nl + tab*2 + "end" + nl + tab*2 + "aux.account_data.wildspark_1517_duration_migrated = true" + nl + tab + "end" + nl + "end"
        text = text.replace(old_login, new_login)
        duration_line = "settings.duration = duration_dropdown:GetIndex()"
        duration_pos = text.find(duration_line)
        if duration_pos >= 0:
            line_start = text.rfind(nl, 0, duration_pos) + 1
            line_end = text.find(nl, duration_pos)
            indent = text[line_start:duration_pos]
            text = text[:line_end] + nl + indent + "aux.account_data.post_duration = settings.duration" + text[line_end:]
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
        text = re.sub(r"(?m)^WildSpark \d+\.\d+\.\d+.*$", "WildSpark 1.5.18", text, count=1)
        if "Credits" in text:
            text = text[:text.rfind("Credits")] + (
                "Credits\nMade by Uncle Bone.\n"
                "Bundled components retain their original copyright and license notices in their included license files.\n")
        text = text.replace(
            "The Blizzard auction-house window is opened at normal scale to avoid broken child-control layout.",
            "WildAuctions keeps Blizzard's native auction-house frame at normal scale to prevent displaced controls.")
        text += "\n1.5.18: Fixes WildAuctions' module-scoped duration migration and defaults new posts to 24 hours. Replaces all original CampingKit artwork, fixes the Auction House nil calls, and fits the settings panel and tabs to the screen.\n"

    return text.encode("utf-8")

with zipfile.ZipFile(baseline, "r") as src, zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as dst:
    seen = set()
    for info in src.infolist():
        old_name = info.filename
        name = old_name
        if name.startswith("WildSpark/Media/CampingKit/"):
            continue
        if name == "WildSpark/Modules/WildAuctions/auxForever.toc":
            name = "WildSpark/Modules/WildAuctions/WildAuctions.toc"
        if name in seen:
            raise SystemExit(f"Duplicate archive path: {name}")
        seen.add(name)
        data = rewrite_text(old_name, src.read(info.filename))
        dst.writestr(name, data, compress_type=zipfile.ZIP_DEFLATED)
    for asset_name, asset_data in generate_wildfire_art().items():
        dst.writestr("WildSpark/Media/WildFire/" + asset_name, asset_data, compress_type=zipfile.ZIP_DEFLATED)
    dst.writestr("WildSpark/Media/WildFireIcon.tga", to_tga(render_fluent("camping", 64)), compress_type=zipfile.ZIP_DEFLATED)
    dst.writestr("WildSpark/Media/WildFireIcon-LICENSE.txt", CAMPING_LICENSE, compress_type=zipfile.ZIP_DEFLATED)
    dst.writestr("WildSpark/CampingKitEmbedded/ARTWORK_NOTICE.txt", ARTWORK_NOTICE, compress_type=zipfile.ZIP_DEFLATED)

with zipfile.ZipFile(output_zip, "r") as z:
    required = [
        "WildSpark/WildSpark.toc",
        "WildSpark/Modules/WildAuctions/aux-addon.lua",
        "WildSpark/Modules/WildAuctions/frame.lua",
        "WildSpark/Modules/WildLayer/Modules/Detection.lua",
        "WildSpark/Media/WildFireIcon.tga",
        "WildSpark/Media/WildFire/camp_list.tga",
        "WildSpark/Media/WildFire/wildfire_pack_64.tga",
    ]
    missing = [name for name in required if name not in z.namelist()]
    if missing:
        raise SystemExit("Missing expected packaged files: " + ", ".join(missing))
    old_camping_art = [name for name in z.namelist() if name.startswith("WildSpark/Media/CampingKit/")]
    new_camping_art = [name for name in z.namelist() if name.startswith("WildSpark/Media/WildFire/")]
    if old_camping_art or len(new_camping_art) != 37:
        raise SystemExit(f"Expected all 37 old CampingKit assets replaced; old={len(old_camping_art)}, new={len(new_camping_art)}")
    data_source = z.read("WildSpark/CampingKitEmbedded/Data.lua")
    dock_source = z.read("WildSpark/CampingKitEmbedded/Libs/KitDock/KitDock.lua")
    old_media_path = b"Media" + bytes([92,92]) + b"CampingKit" + bytes([92,92])
    if old_media_path in data_source or old_media_path in dock_source:
        raise SystemExit("Old CampingKit art path is still referenced")
    if b"wildfire_pack_" not in dock_source:
        raise SystemExit("WildFire backpack art is not referenced by the kit dock")
    toc = z.read("WildSpark/WildSpark.toc").decode("utf-8")
    if "## Version: 1.5.18" not in toc:
        raise SystemExit("Packaged TOC version is not 1.5.18")
    duration_core = z.read("WildSpark/Modules/WildAuctions/tabs/post/core.lua").decode("utf-8")
    if "DURATION_24" not in duration_core or "wildspark_1517_duration_migrated" not in duration_core or "aux.account_data.post_duration = settings.duration" not in duration_core:
        raise SystemExit("WildAuctions 24-hour duration persistence/migration missing")
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
    text = text.replace(chr(92) + "n", chr(10))
    text = text.replace("/releases/download/v1.5.17/WildSpark-1.5.17.zip",
                        "/releases/download/v1.5.18/WildSpark-1.5.18.zip")
    text = text.replace("WildSpark 1.5.17 — Latest Stable", "WildSpark 1.5.18 — Latest Stable")
    text = text.replace("Current stable release: 1.5.17", "Current stable release: 1.5.18")
    duration_note = "- Fix WildAuctions duration migration to use module-scoped constants, preventing the PLAYER_LOGIN nil error."
    newline = chr(10)
    heading = "## Features" + newline
    if duration_note not in text:
        text = text.replace(heading, heading + newline + duration_note + newline, 1)
    repeated_note = "- Fix the Blizzard Auction House window layout when switching from WildAuctions to Blizzard UI; credits show Uncle Bone."
    kept, found = [], False
    for line in text.splitlines():
        if line == repeated_note:
            if found:
                continue
            found = True
        kept.append(line)
    text = newline.join(kept) + newline
    readme.write_text(text, encoding="utf-8")

    subprocess.run(["git", "config", "user.name", "github-actions[bot]"], check=True)
    subprocess.run(["git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com"], check=True)
    subprocess.run(["git", "add", "Wildspark", "README.md"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "Sync WildSpark 1.5.18 source with complete artwork, duration, AH, and panel fixes"], cwd=repo, check=True)
    subprocess.run(["git", "push", "origin", "main"], cwd=repo, check=True)
    notes = """Fixes WildAuctions' PLAYER_LOGIN duration migration using module-scoped duration constants, and corrects the default to 24 hours. Replaces all 37 CampingKit artworks with Fluent Emoji icons/effects, excluding the original proprietary artwork. Includes the Blizzard Auction House and panel fixes."""
    subprocess.run([
        "gh", "release", "create", "v1.5.18", str(output_zip),
        "--repo", subprocess.check_output(["git", "remote", "get-url", "origin"], cwd=repo, text=True).strip().replace("https://github.com/", "").replace(".git", ""),
        "--title", "WildSpark 1.5.18 — Artwork, duration, and UI fixes",
        "--notes", notes,
        "--target", "main",
        "--latest",
    ], cwd=repo, check=True)
finally:
    shutil.rmtree(extract, ignore_errors=True)
