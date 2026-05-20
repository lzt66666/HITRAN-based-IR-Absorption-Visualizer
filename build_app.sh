#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Building release binary..."
swift build -c release
echo "Packaging IRVisualizer.app..."
rm -rf IRVisualizer.app
mkdir -p IRVisualizer.app/Contents/MacOS IRVisualizer.app/Contents/Resources
cp .build/release/IRVisualizer IRVisualizer.app/Contents/MacOS/IRVisualizer
# App icon: compile Assets.xcassets → Assets.car (modern macOS approach)
if [ -d "logo.icon" ] && [ -f "logo.icon/Assets/logo_0000s_0000_CHECK.png" ]; then
    python3 -c "
from PIL import Image; import glob, os, json
r = Image.new('RGBA',(1024,1024),(0,0,0,0))
for f in sorted(glob.glob('logo.icon/Assets/logo_*.png'), reverse=True):
    r = Image.alpha_composite(r, Image.open(f).convert('RGBA'))
os.makedirs('Assets.xcassets/AppIcon.iconset', exist_ok=True)
with open('Assets.xcassets/Contents.json','w') as f:
    json.dump({'info':{'author':'xcode','version':1}},f,indent=2)
entries = []
for fn,sz,sc in [('icon_16x16.png',16,1),('icon_16x16@2x.png',16,2),('icon_32x32.png',32,1),
    ('icon_32x32@2x.png',32,2),('icon_128x128.png',128,1),('icon_128x128@2x.png',128,2),
    ('icon_256x256.png',256,1),('icon_256x256@2x.png',256,2),('icon_512x512.png',512,1),
    ('icon_512x512@2x.png',512,2)]:
    r.resize((sz*sc,sz*sc),Image.LANCZOS).save(f'Assets.xcassets/AppIcon.iconset/{fn}')
    entries.append({'size':f'{sz}x{sz}','filename':fn,'idiom':'mac','scale':f'{sc}x'})
with open('Assets.xcassets/AppIcon.iconset/Contents.json','w') as f:
    json.dump({'info':{'author':'xcode','version':1},'images':entries},f,indent=2)
" 2>/dev/null
    xcrun actool Assets.xcassets --compile IRVisualizer.app/Contents/Resources --platform macosx --minimum-deployment-target 13.0 >/dev/null 2>&1
    rm -rf Assets.xcassets
fi
# Built-in partition function files
for f in ../Partfun_*.txt; do
    if [ -f "$f" ]; then cp "$f" IRVisualizer.app/Contents/Resources/; fi
done
cat > IRVisualizer.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>IRVisualizer</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.user.irvisualizer.gpu</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>IR Absorption Visualizer GPU</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF
echo "Done. IRVisualizer.app is at $(pwd)/IRVisualizer.app"
