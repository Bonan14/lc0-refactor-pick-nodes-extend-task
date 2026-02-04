#!/bin/bash
set -e

# Define the image to use, defaulting to ubuntu:22.04 if not supplied
IMAGE="${1:-ubuntu:22.04}"

echo "Starting Docker container ($IMAGE) to reproduce BLAS workflow..."
echo "This will mount the current directory ($(pwd)) to /workspace inside the container."

# Run the build steps inside the container
docker run --rm -v "$(pwd):/workspace" -w /workspace "$IMAGE" /bin/bash scripts/ci_build.sh

echo "Build and test completed successfully inside Docker."
