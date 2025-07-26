# Build Scripts

This directory contains scripts for automating build processes.

## Auto-Increment Build Number

### `increment-build.sh`

Automatically increments the app's build number using a timestamp format (YYMMDD.HHMM).

#### Usage:

**Before building/archiving:**
```bash
./Scripts/increment-build.sh
```

**As Xcode Build Phase:**
1. In Xcode, select your target
2. Go to Build Phases
3. Add "New Run Script Phase"
4. Set shell to `/bin/bash`
5. Add script: `${SRCROOT}/Scripts/increment-build.sh`
6. Make sure it runs before "Compile Sources"

#### Build Number Format:
- **Format**: `YYMMDD.HHMM` (e.g., `250726.1552`)
- **YYMMDD**: Year, Month, Day
- **HHMM**: Hour, Minute (24-hour format)

#### What it does:
1. Generates a timestamp-based build number
2. Updates `Config/Shared.xcconfig` with the new `CURRENT_PROJECT_VERSION`
3. This ensures each build has a unique, incrementing build number

#### Alternative Methods:
The script includes commented code for using git commit count instead of timestamp. Uncomment those lines if you prefer git-based versioning.

#### Manual Usage:
You can also manually run the script before each build to ensure the build number is current.