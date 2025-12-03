#!/bin/bash

set -e

echo "==================================================================="
echo "DOS to Unix Line Ending Converter"
echo "==================================================================="
echo ""
echo "This script will convert all script files from DOS (CRLF) to Unix (LF) format."
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Check if dos2unix is installed
if ! command -v dos2unix &> /dev/null; then
    echo "ERROR: 'dos2unix' command not found."
    echo ""
    echo "Please install dos2unix:"
    echo "  - Ubuntu/Debian: sudo apt-get install dos2unix"
    echo "  - macOS: brew install dos2unix"
    echo "  - Windows WSL: sudo apt-get install dos2unix"
    echo ""
    exit 1
fi

echo "Found dos2unix command: $(which dos2unix)"
echo ""

# Define file patterns to convert
FILE_PATTERNS=(
    "*.sh"
    "*.py"
    "*.yml"
    "*.yaml"
    "*.json"
    "*.md"
    "*.txt"
    "*.env.example"
    ".env"
    "Caddyfile"
)

# Count files first
echo "Scanning for files to convert..."
TOTAL_FILES=0
for pattern in "${FILE_PATTERNS[@]}"; do
    COUNT=$(find "$SCRIPT_DIR" -type f -name "$pattern" 2>/dev/null | wc -l)
    TOTAL_FILES=$((TOTAL_FILES + COUNT))
done

echo "Found $TOTAL_FILES file(s) to convert."
echo ""

if [ $TOTAL_FILES -eq 0 ]; then
    echo "No files found to convert."
    exit 0
fi

read -p "Do you want to proceed with conversion? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Conversion cancelled."
    exit 0
fi

echo ""
echo "Converting files..."
echo ""

CONVERTED=0
FAILED=0

for pattern in "${FILE_PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
        # Get relative path for display
        rel_path="${file#$SCRIPT_DIR/}"

        # Convert the file
        if dos2unix "$file" 2>/dev/null; then
            echo "✓ $rel_path"
            CONVERTED=$((CONVERTED + 1))
        else
            echo "✗ $rel_path (failed)"
            FAILED=$((FAILED + 1))
        fi
    done < <(find "$SCRIPT_DIR" -type f -name "$pattern" -print0 2>/dev/null)
done

echo ""
echo "==================================================================="
echo "Conversion Complete!"
echo "==================================================================="
echo "Successfully converted: $CONVERTED file(s)"
if [ $FAILED -gt 0 ]; then
    echo "Failed: $FAILED file(s)"
fi
echo ""

# Make all .sh and .py files executable
echo "Setting execute permissions on script files..."
find "$SCRIPT_DIR" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null
echo "✓ Execute permissions set"
echo ""

echo "All done! Your files are now using Unix line endings (LF)."
