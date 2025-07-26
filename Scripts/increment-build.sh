#!/bin/bash

# Auto-increment build number script
# This script can be run as a build phase in Xcode or manually

# Generate build number based on current timestamp (YYMMDD.HHMM format)
BUILD_NUMBER=$(date +"%y%m%d.%H%M")

echo "🔧 Auto-incrementing build number to: $BUILD_NUMBER"

# Update the xcconfig file with the new build number
XCCONFIG_FILE="Config/Shared.xcconfig"

if [ -f "$XCCONFIG_FILE" ]; then
    # Use sed to replace the CURRENT_PROJECT_VERSION line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS version of sed
        sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$XCCONFIG_FILE"
    else
        # Linux version of sed
        sed -i "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$XCCONFIG_FILE"
    fi
    
    echo "✅ Updated $XCCONFIG_FILE with build number: $BUILD_NUMBER"
else
    echo "❌ Could not find $XCCONFIG_FILE"
    exit 1
fi

# Alternative: Git commit count method (commented out)
# Uncomment the lines below if you prefer git commit count as build number
# GIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
# echo "Git commit count: $GIT_COUNT"