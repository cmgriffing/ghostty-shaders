#!/bin/bash

CONFIG_FILE="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
BACKUP_FILE="$CONFIG_FILE.backup"

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg is required but not installed. Please install it with 'brew install ffmpeg'"
    exit 1
fi

# Create videos directory if it doesn't exist and clean existing recordings
rm -rf shader_previews
mkdir -p shader_previews

# Start README.md with a header
echo "# Ghostty Shader Previews" > README.md
echo "" >> README.md
echo "A collection of shader previews for Ghostty terminal." >> README.md
echo "" >> README.md

# Capture original shader setting
ORIGINAL_SHADER=$(grep "^custom-shader=" "$CONFIG_FILE" || echo "")

# Create backup of original config
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Loop through all .glsl files in the current directory
for file in *.glsl; do
    if [ -f "$file" ]; then
        echo "Applying shader: $file"
        
        # Remove existing custom-shader line if it exists
        sed -i '' '/^custom-shader = /d' "$CONFIG_FILE"
        
        # Add new shader config on a new line, ensuring there's a blank line before it
        echo "" >> "$CONFIG_FILE"
        echo "custom-shader = $(pwd)/$file" >> "$CONFIG_FILE"
        
        # Get filename without extension for the video name
        filename=$(basename "$file" .glsl)
        
        # Open Ghostty
        open -a Ghostty
        
        # Give it a moment to open
        sleep 2
        
        # Type commands using AppleScript
        osascript -e 'tell application "System Events"
            keystroke "cd '"$(pwd)"' && ls -la"
            key code 36 # Return key
        end tell'
        
        # Start screen recording with ffmpeg (compressed mp4)
        ffmpeg -f avfoundation -capture_cursor 1 -i "0:none" -t 10 \
            -vf "scale=iw/2:ih/2" \
            -c:v libx264 -preset fast -crf 23 \
            -y "shader_previews/${filename}.mp4"
        
        # Close Ghostty (force kill if necessary)
        pkill -9 -x "ghostty"
        
        # Give it a moment to close
        sleep 1
        
        # Add shader section to README.md
        echo "## ${filename}" >> README.md
        echo "" >> README.md
        echo "![${filename}](https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[\/:]//' | sed 's/\.git$//')/raw/main/shader_previews/${filename}.mp4)" >> README.md
        echo "" >> README.md
    fi
done

# Restore original config
cp "$BACKUP_FILE" "$CONFIG_FILE"

# If there was an original shader, restore it properly
if [ -n "$ORIGINAL_SHADER" ]; then
    sed -i '' '/^custom-shader=/d' "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "$ORIGINAL_SHADER" >> "$CONFIG_FILE"
fi

rm "$BACKUP_FILE"
