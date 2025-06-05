import os

from fontTools.ttLib import TTFont  # pip install fonttools

# Steps to custom build Maple Mono NF CN font (mainly for JetBrains IntelliJ IDEA):
#
# 1. Download MapleMono-NF-CN-unhinted.zip from: <https://font.subf.dev/en/download/>
# 2. Build Font In Browser: <https://font.subf.dev/en/playground/> (CLI Flags: --cn --no-hinted --feat cv35,cv61,cv62,ss06)
# 3. Install: Open `MapleMono-NF-CN-Custom-*.ttf` in `Font Book` app
# 4. Check for any errors: `ttx -t name MapleMono-NF-CN-Regular.ttf` (from fonttools)


def patch_font_name(ttf_path):
    print(f"🔧 Processing: {ttf_path}")
    font = TTFont(ttf_path)
    name_table = font["name"]

    for record in name_table.names:
        if record.nameID in [1, 3, 4, 6, 16] or True:
            try:
                text = record.toUnicode()
                new_text = text.replace(
                    "Maple Mono NF CN", "Maple Mono NF CN Custom"
                ).replace("MapleMono-NF-CN", "MapleMono-NF-CN-Custom")
                if new_text != text:
                    record.string = new_text.encode("utf_16_be")
            except UnicodeDecodeError:
                print(
                    f"⚠️ UnicodeDecodeError in {ttf_path}: nameID={record.nameID}, platformID={record.platformID}, langID={record.langID}"
                )

    base, ext = os.path.splitext(ttf_path)
    base_replaced = base.replace("MapleMono-NF-CN", "MapleMono-NF-CN-Custom")
    new_path = f"{base_replaced}{ext}"

    font.save(new_path)
    print(f"✔️ Saved: {new_path}")


# Process all .ttf files in the current directory
for filename in os.listdir("."):
    if filename.endswith(".ttf"):
        patch_font_name(filename)
