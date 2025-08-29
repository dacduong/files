#!/bin/bash

# Script to split a zip file into multiple parts and encode each to base64
# Usage: ./split_and_encode.sh <zip_file> [max_size_mb]

# Check if zip file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <zip_file> [max_size_mb]"
    echo "Example: $0 myfile.zip 10"
    exit 1
fi

ZIP_FILE="$1"
MAX_SIZE_MB="${2:-10}"  # Default to 10MB if not specified

# Check if zip file exists
if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File '$ZIP_FILE' not found!"
    exit 1
fi

# Convert MB to bytes
MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))

# Get the base name without extension
BASE_NAME=$(basename "$ZIP_FILE" .zip)

# Create output directory
OUTPUT_DIR="${BASE_NAME}_split"
mkdir -p "$OUTPUT_DIR"

echo "Splitting '$ZIP_FILE' into chunks of max ${MAX_SIZE_MB}MB..."

# Split the file using macOS's split command
# -b specifies byte size, -a specifies suffix length
cd "$OUTPUT_DIR"
split -b "$MAX_SIZE_BYTES" -a 3 "../$ZIP_FILE" "${BASE_NAME}_part_"

# Get list of split files and sort them to ensure proper ordering
SPLIT_FILES=($(ls "${BASE_NAME}_part_"* | sort))

echo "Created ${#SPLIT_FILES[@]} parts. Converting to base64..."

# Convert each split file to base64
for i in "${!SPLIT_FILES[@]}"; do
    SPLIT_FILE="${SPLIT_FILES[$i]}"
    # Create numbered base64 files to maintain order
    BASE64_FILE=$(printf "%s_part_%03d.b64" "$BASE_NAME" $((i+1)))
    
    echo "Converting $SPLIT_FILE to $BASE64_FILE..."
    base64 -b 0 -i "$SPLIT_FILE" -o "$BASE64_FILE"
    
    # Remove the binary split file to save space
    #rm "$SPLIT_FILE"
done

# Create a manifest file with information about the split
cat > "${BASE_NAME}_manifest.txt" << EOF
Original file: $ZIP_FILE
Number of parts: ${#SPLIT_FILES[@]}
Max size per part: ${MAX_SIZE_MB}MB
Base name: $BASE_NAME
Created on: $(date)
EOF

echo "Done! Files created in '$OUTPUT_DIR' directory:"
echo "- ${#SPLIT_FILES[@]} base64 encoded parts: ${BASE_NAME}_part_001.b64 to ${BASE_NAME}_part_$(printf "%03d" ${#SPLIT_FILES[@]}).b64"
echo "- Manifest file: ${BASE_NAME}_manifest.txt"
echo ""
echo "To reconstruct the original file, use: ./decode_and_merge.sh $OUTPUT_DIR"
