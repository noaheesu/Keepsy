#!/bin/sh
# Renders design/screenshots.html into 1320×2868 App Store screenshots in store/screenshots/.
set -e
cd "$(dirname "$0")"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for lang in ko en; do
  for i in 0 1 2; do
    "$chrome" --headless=new --hide-scrollbars --window-size=440,956 --force-device-scale-factor=3 \
      --virtual-time-budget=5000 --screenshot="../store/screenshots/$lang-$((i + 1)).png" \
      "file://$PWD/screenshots.html#$lang-$i" 2>/dev/null
  done
done
