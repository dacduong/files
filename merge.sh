#!/bin/bash

# Script to decode base64 files and merge them back to original zip
# Usage: ./decode_and_merge.sh <split_directory>

# Check if directory is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <split_directory>"
    echo "Example: $0 myfile_split"
    exit 1
fi

SPLIT_DIR="$1"

# Check if directory exists
if [ ! -d "$SPLIT_DIR" ]; then
    echo "Error: Directory '$SPLIT_DIR' not found!"
    exit 1
fi

# Check if manifest file exists
MANIFEST_FILE="$SPLIT_DIR"/*_manifest.txt
if [ ! -f $MANIFEST_FILE ]; then
    echo "Error: Manifest file not found in '$SPLIT_DIR'!"
    exit 1
fi

# Extract base name from manifest
BASE_NAME=$(grep "Base name:" $MANIFEST_FILE | cut -d' ' -f3)
if [ -z "$BASE_NAME" ]; then
    echo "Error: Could not determine base name from manifest file!"
    exit 1
fi

echo "Reconstructing '$BASE_NAME.zip' from parts in '$SPLIT_DIR'..."

cd "$SPLIT_DIR"

# Find all base64 files and sort them numerically
BASE64_FILES=($(ls "${BASE_NAME}_part_"*.b64 2>/dev/null | sort -V))

if [ ${#BASE64_FILES[@]} -eq 0 ]; then
    echo "Error: No base64 files found matching pattern '${BASE_NAME}_part_*.b64'!"
    exit 1
fi

echo "Found ${#BASE64_FILES[@]} base64 files to process..."

# Decode each base64 file back to binary
for BASE64_FILE in "${BASE64_FILES[@]}"; do
    # Extract part number from filename
    PART_NUM=$(echo "$BASE64_FILE" | grep -o '[0-9]\+' | tail -1)
    BINARY_FILE="${BASE_NAME}_part_$(printf "%03d" $PART_NUM).bin"
    
    echo "Decoding $BASE64_FILE to $BINARY_FILE..."
    base64 -D -i "$BASE64_FILE" -o "$BINARY_FILE"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to decode $BASE64_FILE!"
        exit 1
    fi
done

# Get list of binary files and sort them to ensure proper ordering
BINARY_FILES=($(ls "${BASE_NAME}_part_"*.bin | sort -V))

# Merge all binary files back into the original zip
OUTPUT_ZIP="../${BASE_NAME}_reconstructed.zip"
echo "Merging ${#BINARY_FILES[@]} parts into '$OUTPUT_ZIP'..."

cat "${BINARY_FILES[@]}" > "$OUTPUT_ZIP"

# Verify the zip file
if command -v unzip >/dev/null 2>&1; then
    echo "Verifying reconstructed zip file..."
    if unzip -t "$OUTPUT_ZIP" >/dev/null 2>&1; then
        echo "✅ Zip file verification successful!"
    else
        echo "⚠️  Warning: Zip file verification failed. The file may be corrupted."
    fi
else
    echo "Note: 'unzip' command not found. Cannot verify zip file integrity."
fi

# Clean up binary files
echo "Cleaning up temporary binary files..."
rm -f "${BINARY_FILES[@]}"

echo "Done! Reconstructed file: $OUTPUT_ZIP"

# Show file sizes for comparison
if [ -f "$OUTPUT_ZIP" ]; then
    ORIGINAL_INFO=$(grep "Original file:" $MANIFEST_FILE | cut -d' ' -f3-)
    if [ -f "../$ORIGINAL_INFO" ]; then
        ORIGINAL_SIZE=$(stat -f%z "../$ORIGINAL_INFO" 2>/dev/null || stat -c%s "../$ORIGINAL_INFO" 2>/dev/null)
        RECONSTRUCTED_SIZE=$(stat -f%z "$OUTPUT_ZIP" 2>/dev/null || stat -c%s "$OUTPUT_ZIP" 2>/dev/null)
        
        echo ""
        echo "Size comparison:"
        echo "Original: $ORIGINAL_SIZE bytes"
        echo "Reconstructed: $RECONSTRUCTED_SIZE bytes"
        
        if [ "$ORIGINAL_SIZE" -eq "$RECONSTRUCTED_SIZE" ]; then
            echo "✅ File sizes match perfectly!"
        else
            echo "⚠️  Warning: File sizes don't match!"
        fi
    fi
fi
