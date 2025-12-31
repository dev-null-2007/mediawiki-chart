# MediaWiki Kubernetes Deployment

This repository contains everything needed to deploy MediaWiki on Kubernetes (specifically MicroK8s) with MariaDB.

## Project Structure

```
.
├── docker/          # Custom MediaWiki Docker image with required extensions
│   ├── Dockerfile   # Extends official mediawiki:1.45.1 with intl extension
│   ├── build.sh     # Build script for the custom image
│   └── README.md    # Docker build and usage documentation
│
└── helm/            # Helm chart for Kubernetes deployment
    └── mediawiki/   # MediaWiki + MariaDB consolidated chart
```

## Quick Start

### 1. Build the Custom MediaWiki Image

The official MediaWiki Docker image is missing the required `intl` PHP extension. Build and push to your registry:

```bash
cd docker
./build.sh
```

The script will automatically build and push to `localhost:32000/mediawiki:1.45.1-intl`.

See [docker/README.md](docker/README.md) for detailed build instructions.

### 2. Deploy with Helm

```bash
# Install
microk8s helm install testwiki ./helm/mediawiki/ -n test --create-namespace

# Or upgrade
microk8s helm upgrade testwiki ./helm/mediawiki/ -n test
```

### 3. Access MediaWiki

```bash
# Port-forward to access locally
microk8s kubectl port-forward -n test svc/testwiki-mediawiki 8080:80

# Then open http://localhost:8080 in your browser
```

## What's Included

### Custom Docker Image
- **Base**: Official `mediawiki:1.45.1`
- **Added**: `php-intl` extension (required for MediaWiki 1.36+)
- **User**: `www-data` (uid 33) for security

### Helm Chart
- **MediaWiki**: Latest version 1.45.1 with official Docker image
- **MariaDB**: Integrated database with persistent storage
- **Configuration**:
  - Ports: Container runs on 8080/8443 (non-privileged), Service exposes 80/443
  - Security: Non-root user, minimal capabilities
  - Storage: PersistentVolumeClaims for both MediaWiki and MariaDB data

## Key Features

- ✅ **Consolidated Chart**: Single Helm chart with MediaWiki + MariaDB (no external dependencies)
- ✅ **Official Image**: Uses official MediaWiki Docker image (with intl extension added)
- ✅ **Security**: Runs as non-privileged user (www-data, uid 33)
- ✅ **Persistence**: Data survives pod restarts via PVCs
- ✅ **Production-Ready**: Password management, proper probes, volume mount handling

## Documentation

- [Docker Image Documentation](docker/README.md) - Building and using the custom image
- [Helm Chart Values](helm/mediawiki/values.yaml) - Configuration options
- [Chart Notes](helm/mediawiki/templates/NOTES.txt) - Post-install instructions

## Common Operations

### Get Passwords
```bash
# MediaWiki admin password
microk8s kubectl get secret -n test testwiki-mediawiki -o jsonpath="{.data.mediawiki-password}" | base64 -d

# MariaDB root password
microk8s kubectl get secret -n test testwiki-mediawiki-mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 -d
```

### Check Status
```bash
microk8s kubectl get pods -n test
microk8s kubectl logs -n test -l app.kubernetes.io/name=mediawiki
```

### Uninstall
```bash
microk8s helm uninstall testwiki -n test
microk8s kubectl delete pvc -n test --all
```

## Troubleshooting

### Pod stuck in Init:Error
The init container includes volume readiness checks to avoid timing issues. If you see this, the pod will automatically retry.

### Database connection errors
Check that MariaDB pod is running and the password secret exists:
```bash
microk8s kubectl get pods -n test
microk8s kubectl get secret -n test testwiki-mediawiki-mariadb
```

### 404 errors from MediaWiki
The init container copies MediaWiki files to the persistent volume. Check the init container logs:
```bash
microk8s kubectl logs -n test <pod-name> -c prepare-base-dir
```

## Migration from Bitnami

This chart was originally based on Bitnami's MediaWiki chart but has been adapted to:
1. Use the official MediaWiki Docker image (instead of Bitnami's yanked images)
2. Work with non-privileged ports (8080/8443)
3. Consolidate all dependencies into a single chart (no OCI registry dependencies)

## License

The Helm chart templates are based on Bitnami's charts and retain their Apache 2.0 license headers.
