#!/bin/bash

echo "📱 Sekretar - Deploy to iPhone"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT="sekretar.xcodeproj"
SCHEME="sekretar"
CONFIGURATION="Debug"

echo -e "${YELLOW}📋 Pre-deployment checklist:${NC}"
echo "1. ✅ iPhone connected via USB cable"
echo "2. ✅ iPhone unlocked"
echo "3. ✅ Trust this computer on iPhone"
echo "4. ✅ Developer mode enabled (iOS 16+)"
echo ""

# List connected devices
echo -e "${YELLOW}🔍 Detecting connected devices...${NC}"
xcrun devicectl list devices | grep -E "iPhone|iPad" || {
    echo -e "${RED}❌ No iOS devices found. Please connect your iPhone.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Connect iPhone with USB cable"
    echo "2. Unlock your iPhone"
    echo "3. Tap 'Trust This Computer' if prompted"
    exit 1
}

# Get device name
DEVICE_NAME=$(xcrun devicectl list devices | grep iPhone | head -1 | awk -F'[()]' '{print $2}')

if [ -z "$DEVICE_NAME" ]; then
    echo -e "${RED}❌ Could not detect device name${NC}"
    echo "Using generic device name..."
    DEVICE_NAME="iPhone"
fi

echo -e "${GREEN}✅ Found device: $DEVICE_NAME${NC}"
echo ""

# Clean build folder
echo -e "${YELLOW}🧹 Cleaning build folder...${NC}"
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" -quiet

# Build for device
echo -e "${YELLOW}🔨 Building for device...${NC}"
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS,name=$DEVICE_NAME" \
    -derivedDataPath build \
    -quiet || {
    echo -e "${RED}❌ Build failed!${NC}"
    echo "Try building manually in Xcode for detailed errors"
    exit 1
}

echo -e "${GREEN}✅ Build succeeded!${NC}"
echo ""

# Install and run
echo -e "${YELLOW}📲 Installing on device...${NC}"
xcodebuild install \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS,name=$DEVICE_NAME" \
    -derivedDataPath build || {

    echo -e "${YELLOW}⚠️  Installation requires manual steps:${NC}"
    echo ""
    echo "1. In Xcode, select your iPhone in the device list (top bar)"
    echo "2. Click the Run button (▶️)"
    echo "3. If prompted about untrusted developer:"
    echo "   - On iPhone: Settings → General → VPN & Device Management"
    echo "   - Tap your Developer App certificate"
    echo "   - Tap 'Trust'"
    echo ""
    echo "4. Run this script again or use Xcode"
    exit 1
}

echo -e "${GREEN}✅ Successfully deployed to $DEVICE_NAME!${NC}"
echo ""
echo -e "${YELLOW}📱 Next steps:${NC}"
echo "1. Find 'Sekretar' app on your iPhone home screen"
echo "2. Tap to launch"
echo "3. Test the new AI features!"
echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"