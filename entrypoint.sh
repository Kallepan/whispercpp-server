#!/bin/bash

# Download the model
./models/download-ggml-model.sh large-v3

# Start the server
./server \
    --host 0.0.0.0 \
    --model /whisper.cpp/models/ggml-large-v3.bin \
    --port 8080

