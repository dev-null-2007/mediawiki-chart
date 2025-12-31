#!/bin/bash
set -e

# Generate timestamp for unique tagging (YYYYMMDD-HHMM)
TIMESTAMP=$(date +%Y%m%d-%H%M)
VERSION="1.45.1-intl"
IMAGE_TAG="${VERSION}-${TIMESTAMP}"

LOCAL_IMAGE="mediawiki:${IMAGE_TAG}"
REGISTRY_IMAGE="localhost:32000/mediawiki:${IMAGE_TAG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building MediaWiki Docker image with intl extension..."
echo "Image tag: ${IMAGE_TAG}"
echo ""
docker build -t "$LOCAL_IMAGE" "$SCRIPT_DIR"

echo ""
echo "✓ Image built successfully: $LOCAL_IMAGE"
echo ""

# Tag for registry
echo "Tagging image for registry..."
docker tag "$LOCAL_IMAGE" "$REGISTRY_IMAGE"

# Push to registry
echo "Pushing to MicroK8s registry at localhost:32000..."
if docker push "$REGISTRY_IMAGE"; then
    echo ""
    echo "=========================================="
    echo "✓ Image successfully pushed to registry!"
    echo "=========================================="
    echo ""
    echo "Image: $REGISTRY_IMAGE"
    echo ""
    echo "Update helm/mediawiki/values.yaml with:"
    echo ""
    echo "  image:"
    echo "    registry: localhost:32000"
    echo "    repository: mediawiki"
    echo "    tag: ${IMAGE_TAG}"
    echo ""
    echo "Then upgrade your deployment:"
    echo "  microk8s helm upgrade testwiki ./helm/mediawiki/ -n test"
    echo ""
else
    echo ""
    echo "✗ Failed to push to registry. Is the registry running?"
    echo ""
    echo "To enable MicroK8s registry:"
    echo "  microk8s enable registry"
    echo ""
    echo "Or import directly to MicroK8s (alternative):"
    echo "  docker save $LOCAL_IMAGE | microk8s ctr image import /dev/stdin"
fi
