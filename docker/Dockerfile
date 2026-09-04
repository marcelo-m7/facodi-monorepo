FROM odoo:19.0

LABEL org.opencontainers.image.title="FACODI Odoo"
LABEL org.opencontainers.image.description="Odoo 19 Community with FACODI addons baked into the image"
LABEL org.opencontainers.image.source="https://github.com/marcelo-m7/facodi-monorepo"

USER root
COPY addons/ /opt/facodi-addon-sources/
RUN set -eux; \
    mkdir -p /mnt/extra-addons; \
    found=0; \
    for manifest in /opt/facodi-addon-sources/*/*/__manifest__.py; do \
        [ -e "$manifest" ] || continue; \
        module_dir="$(dirname "$manifest")"; \
        module_name="$(basename "$module_dir")"; \
        [ ! -e "/mnt/extra-addons/$module_name" ] || { echo "duplicate Odoo module: $module_name" >&2; exit 1; }; \
        cp -a "$module_dir" "/mnt/extra-addons/$module_name"; \
        found=1; \
    done; \
    [ "$found" -eq 1 ] || { echo "no Odoo addons found in submodule sources" >&2; exit 1; }; \
    chown -R odoo:odoo /mnt/extra-addons
USER odoo
