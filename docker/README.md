# MediaWiki Docker Image with intl Extension

This directory contains a Dockerfile that extends the official MediaWiki 1.45.1 image to include the required `intl` PHP extension.

## Why This is Needed

MediaWiki 1.36+ requires the `intl` PHP extension as a mandatory dependency. The official MediaWiki Docker images are intentionally minimal and don't include all required extensions to keep the image size small.

## Building the Image

The build script automatically creates a timestamped tag to ensure each build is unique:

```bash
# From the docker/ directory
./build.sh

# This creates a tag like: mediawiki:1.45.1-intl-20251231-1430
# And pushes to: localhost:32000/mediawiki:1.45.1-intl-20251231-1430
```

### Manual Build (not recommended)
```bash
docker build -t mediawiki:1.45.1-intl .
```

**Note**: Manual builds should also use unique tags to avoid confusion.

## Using with MicroK8s

The build script automatically pushes to your MicroK8s registry at `localhost:32000`.

### Quick Start
```bash
# Build and push to registry (automated by build.sh)
./build.sh
```

### Manual Registry Push
```bash
# Build the image
docker build -t mediawiki:1.45.1-intl .

# Tag for the local registry
docker tag mediawiki:1.45.1-intl localhost:32000/mediawiki:1.45.1-intl

# Push to MicroK8s registry
docker push localhost:32000/mediawiki:1.45.1-intl
```

### Alternative: Direct Import (not recommended)
If you need to import without using the registry:
```bash
docker save mediawiki:1.45.1-intl | microk8s ctr image import /dev/stdin
```

## Updating the Helm Chart

After building the image, the build script will show you the exact tag to use. Update `helm/mediawiki/values.yaml`:

```yaml
image:
  registry: localhost:32000
  repository: mediawiki
  tag: 1.45.1-intl-20251231-1430  # Use the timestamp from build output
  pullPolicy: IfNotPresent
```

Then upgrade your deployment:
```bash
microk8s helm upgrade testwiki ./helm/mediawiki/ -n test
```

## What's Included

- Base: `mediawiki:1.45.1`
- Added: `php-intl` extension
- User: `www-data` (uid 33)

## Verification

To verify the intl extension is installed:

```bash
docker run --rm mediawiki:1.45.1-intl php -m | grep intl
```

You should see `intl` in the output.
