# Build the Alif Retail extension on top of the official Tryton 8.0 image.
# Keep the server, desktop client and custom module on the same 8.0 series.
ARG TRYTON_BASE_IMAGE=tryton/tryton:8.0
FROM ${TRYTON_BASE_IMAGE}

USER root
COPY modules/alif_retail /tmp/alif_retail
RUN python3 -m pip install --no-cache-dir --no-deps /tmp/alif_retail \
    && rm -rf /tmp/alif_retail

# The official image creates and uses this unprivileged service account.
USER trytond
