FROM mediawiki:1.45.1

# Metadata
LABEL maintainer="devnu"
LABEL description="MediaWiki 1.45.1 with required intl extension"
LABEL version="1.45.1-intl"

# Switch to root to install extensions
USER root

# Install intl extension and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libicu-dev \
    && docker-php-ext-install -j$(nproc) intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify intl extension is installed
RUN php -m | grep intl

# Switch back to www-data user for security
USER www-data

# Expose the same ports as the base image
EXPOSE 80

# Use the same entrypoint as the base image
# (inherited from FROM)
