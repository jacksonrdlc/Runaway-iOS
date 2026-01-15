#!/bin/sh

# ci_post_clone.sh
# Xcode Cloud runs this script after cloning the repository

set -e

echo "=== Creating config files for Xcode Cloud build ==="

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Create Info.plist from template
cp Runaway-iOS-Info.plist.template Runaway-iOS-Info.plist

# Use environment variables if set, otherwise use placeholders
MAPBOX_TOKEN="${MAPBOX_PUBLIC_TOKEN:-pk.placeholder}"
SUPABASE_URL="${SUPABASE_URL:-https://placeholder.supabase.co}"
SUPABASE_KEY="${SUPABASE_KEY:-placeholder_key}"
RUNAWAY_API_KEY="${RUNAWAY_API_KEY:-placeholder_api_key}"

sed -i '' "s|YOUR_MAPBOX_TOKEN_HERE|${MAPBOX_TOKEN}|g" Runaway-iOS-Info.plist
sed -i '' "s|YOUR_SUPABASE_PROJECT_URL_HERE|${SUPABASE_URL}|g" Runaway-iOS-Info.plist
sed -i '' "s|YOUR_SUPABASE_ANON_KEY_HERE|${SUPABASE_KEY}|g" Runaway-iOS-Info.plist
sed -i '' "s|YOUR_RUNAWAY_API_KEY_HERE|${RUNAWAY_API_KEY}|g" Runaway-iOS-Info.plist

echo "✓ Runaway-iOS-Info.plist created"

# Create GoogleService-Info.plist if it doesn't exist
if [ ! -f "Runaway iOS/GoogleService-Info.plist" ]; then
  cat > "Runaway iOS/GoogleService-Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key>
  <string>placeholder</string>
  <key>GCM_SENDER_ID</key>
  <string>123456789</string>
  <key>BUNDLE_ID</key>
  <string>com.jackrudelic.labs.Runaway-iOS</string>
  <key>PROJECT_ID</key>
  <string>placeholder</string>
  <key>GOOGLE_APP_ID</key>
  <string>1:123456789:ios:placeholder</string>
</dict>
</plist>
EOF
  echo "✓ GoogleService-Info.plist created"
fi

echo "=== Config files ready ==="
