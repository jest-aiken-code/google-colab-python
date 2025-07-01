#!/bin/bash

# --- Configuration ---
MODEL_NAME="qwen-aiken-coder-LLM"
MODEL_DIR_NAME="~/ollama-models/${MODEL_NAME}" # Directory to create for your model
# The Modelfile will be created locally, so MODELFILE_URL is no longer needed for download.
MODELFILE_URL="" # No longer used for direct download, but kept for reference if needed.
GGUF_MODEL_URL="https://huggingface.co/AmiBening/Qwen2.5-Coder-Aiken-GGUF/resolve/main/qwen2.5-coder-aiken-q4_K_M.gguf" # Your GGUF model URL
MODELFILE_NAME="Modelfile"                   # Default name for the Modelfile
GGUF_FILE_NAME="qwen2.5-coder-aiken-q4_K_M.gguf" # Updated to match the exact GGUF filename
MIN_GGUF_SIZE_MB=50 # Minimum expected size for the GGUF file in MB (adjust if your model is smaller)

# --- Script Start ---

echo "Starting setup for Ollama model: ${MODEL_NAME}"

# 1. Create a directory for the model and Modelfile
echo "1. Creating directory: ${MODEL_DIR_NAME}"
mkdir -p "${MODEL_DIR_NAME}"

# Check if directory creation was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create directory ${MODEL_DIR_NAME}. Exiting."
    exit 1
fi
echo "Directory created successfully."

# Navigate into the model directory
cd "${MODEL_DIR_NAME}" || { echo "Error: Could not change to directory ${MODEL_DIR_NAME}. Exiting."; exit 1; }

# 2. Create the Modelfile locally with correct content
echo "2. Creating Modelfile locally..."
cat <<EOF > "${MODELFILE_NAME}"
FROM ./${GGUF_FILE_NAME}
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
"""
# You can add more parameters here if needed, e.g.:
# PARAMETER stop <|im_end|>
# PARAMETER stop <|im_start|>
EOF

# Check if Modelfile creation was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create Modelfile locally. Exiting."
    exit 1
fi
echo "Modelfile created successfully as ${MODELFILE_NAME}."

# 3. Download the LLM (GGUF format)
echo "3. Downloading GGUF model from ${GGUF_MODEL_URL}..."
# Use -L to follow redirects, -f to fail silently on server errors (though we check exit code)
curl -L -o "${GGUF_FILE_NAME}" "${GGUF_MODEL_URL}"

# Check if GGUF model download was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to download GGUF model. Please check the URL and your internet connection. Exiting."
    exit 1
fi
echo "GGUF model downloaded successfully as ${GGUF_FILE_NAME}."

# Verify downloaded GGUF file size
DOWNLOADED_SIZE_BYTES=$(stat -f%z "${GGUF_FILE_NAME}" 2>/dev/null || du -b "${GGUF_FILE_NAME}" | awk '{print $1}')
MIN_SIZE_BYTES=$((MIN_GGUF_SIZE_MB * 1024 * 1024))

if [ -z "$DOWNLOADED_SIZE_BYTES" ] || [ "$DOWNLOADED_SIZE_BYTES" -lt "$MIN_SIZE_BYTES" ]; then
    echo "Error: Downloaded GGUF file '${GGUF_FILE_NAME}' is too small (${DOWNLOADED_SIZE_BYTES} bytes)."
    echo "Expected at least ${MIN_GGUF_SIZE_MB}MB. The download might have failed or been incomplete."
    echo "Please check the GGUF_MODEL_URL and try again."
    exit 1
fi
echo "GGUF file size check passed. (${DOWNLOADED_SIZE_BYTES} bytes)"


# 4. Set up a local Ollama setting
echo "4. Creating Ollama model '${MODEL_NAME}' using the downloaded Modelfile..."
ollama create "${MODEL_NAME}" -f "${MODELFILE_NAME}"

# Check if Ollama model creation was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create Ollama model. Please ensure Ollama is running and the Modelfile is correctly formatted."
    echo "The Modelfile should reference the GGUF file as 'FROM ./${GGUF_FILE_NAME}'."
    exit 1
fi
echo "Ollama model '${MODEL_NAME}' created successfully!"
echo "You can now run it using: ollama run ${MODEL_NAME}"

# Navigate back to the original directory (optional)
cd - > /dev/null

echo "Setup complete!"
