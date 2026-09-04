FROM odoo:19.0

LABEL org.opencontainers.image.title="FACODI Odoo"
LABEL org.opencontainers.image.description="Odoo 19 Community with FACODI addons baked into the image"
LABEL org.opencontainers.image.source="https://github.com/marcelo-m7/facodi-monorepo"

USER root
COPY addons/ /mnt/extra-addons/
RUN chown -R odoo:odoo /mnt/extra-addons
USER odoo
