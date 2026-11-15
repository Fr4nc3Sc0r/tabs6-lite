# SPDX-License-Identifier: GPL-3.0-or-later
#
# The S26 default/"Featured" wallpapers are interactive videos (res/raw/video_00N.mp4,
# about 134 MB each). wallpaper-res.apk also ships the matching stills
# (wallpaper_00N): turn every video entry of resources_info.json into its still,
# drop the still entries that would become duplicates and remove the videos.
# JSON transformation taken from target/a52sxq/patches/wallpaper of the base.
APK="$WORK_DIR/system/system/priv-app/wallpaper-res/wallpaper-res.apk"
if [ -f "$APK" ] && unzip -l "$APK" "res/raw/video_001.mp4" &> /dev/null; then
    TMP_DIR="$(mktemp -d)"

    LOG "- Replacing the video wallpapers of wallpaper-res.apk with their still images"
    unzip -q "$APK" "res/raw/resources_info.json" -d "$TMP_DIR" || ABORT "Failed to extract resources_info.json"
    python3 - "$TMP_DIR/res/raw/resources_info.json" << 'EOF' || ABORT "Failed to patch resources_info.json"
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

phone = []
for item in data["phone"]:
    name = item.get("filename", "")
    if item.get("screen") == 0 and item.get("type") == 10 and name.startswith("video_"):
        item = {
            "isDefault": item["isDefault"], "index": item["index"], "which": item["which"],
            "screen": 0, "target_screen_only": True, "type": 0,
            "filename": "wallpaper_" + name[len("video_"):].replace(".mp4", ".png"), "frame_no": -1,
            "desc_str_id": item.get("desc_str_id", ""), "cmf_info": item.get("cmf_info", [""]),
            "logging_info": item.get("logging_info", {}),
        }
    elif item.get("screen") == 0 and item.get("type") == 0 and item.get("which") == 1:
        continue
    elif name.endswith(".mp4"):
        continue
    phone.append(item)
assert any(i.get("isDefault") for i in phone), "no default wallpaper left"
data["phone"] = phone

for t in data["types"]:
    if t.get("type") in (8, 10):
        t["type"] = 0

with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False)
EOF

    (cd "$TMP_DIR" && zip -q "$APK" "res/raw/resources_info.json") || ABORT "Failed to update wallpaper-res.apk"
    zip -q -d "$APK" "res/raw/video_00*.mp4" || ABORT "Failed to strip wallpaper videos"

    CERT_PREFIX="aosp"
    $ROM_IS_OFFICIAL && CERT_PREFIX="unica"
    EVAL "signapk \"$SRC_DIR/security/${CERT_PREFIX}_platform.x509.pem\" \"$SRC_DIR/security/${CERT_PREFIX}_platform.pk8\" \"$APK\" \"$TMP_DIR/signed.apk\"" \
        || ABORT "Failed to sign wallpaper-res.apk"
    mv -f "$TMP_DIR/signed.apk" "$APK"

    rm -rf "$TMP_DIR"
    unset TMP_DIR CERT_PREFIX
fi
unset APK
