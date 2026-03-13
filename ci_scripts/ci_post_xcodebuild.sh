#!/bin/zsh

# ci_post_xcodebuild.sh
# Xcode Cloud script to notify Discord after the build finishes.

if [[ -z "$DISCORD_WEBHOOK" ]]; then
    echo "Error: DISCORD_WEBHOOK environment variable is not set in Xcode Cloud."
    exit 0
fi

# Determine status and color
if [[ "$CI_XCODEBUILD_EXIT_CODE" -eq 0 ]]; then
    STATUS="Success ✅"
    COLOR=6750059 # Green (#66FF6B)
else
    STATUS="Failed ❌"
    COLOR=16724787 # Red (#FF3133)
fi

# Construct payload
# We use the Sarisia-style format to match the platform builds
PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "Runaway iOS: $STATUS",
    "description": "**Workflow**: $CI_WORKFLOW\n**Build**: #$CI_BUILD_NUMBER\n**Commit**: \`$CI_COMMIT\`",
    "color": $COLOR,
    "footer": {
      "text": "Xcode Cloud • $CI_PRODUCT"
    },
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }]
}
EOF
)

# Send to Discord
curl -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK"
