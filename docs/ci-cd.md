# FACODI CI/CD

## Purpose

`facodi-monorepo` composes and deploys the FACODI Odoo runtime. Feature implementation remains in dedicated repositories.

Pinned components:

- `marcelo-m7/facodi-learning` -> `facodi_learning`;
- `marcelo-m7/facodi-theme` -> `theme_facodi`;
- `odoo/design-themes` -> upstream dependency, with only `theme_common` copied into the runtime image.

Current verified integration pins:

```text
facodi-theme: be35673a5649f5e6f7b01777905d0899e3daaf7b
odoo/design-themes: a1818df4ade65406c0cacae8b1ea676e6f70095f
```

## Build lifecycle

```text
facodi-monorepo commit
  + facodi-learning Gitlink
  + facodi-theme Gitlink
  + design-themes Gitlink
             |
             v
      recursive checkout
             |
             v
        Dockerfile
  FACODI addons + theme_common only
             |
             v
Artifact Registry :<monorepo-sha>
```

The container never executes `git clone`, `git fetch`, `git checkout` or `git pull`.

## CI

Pull requests execute:

1. recursive submodule checkout;
2. repository and GCP helper contracts;
3. Compose validation;
4. immutable Odoo 19 image build;
5. PostgreSQL startup;
6. disposable `website_facodi -> theme_facodi` transition with HTTP smoke tests;
7. clean installation of the discovered FACODI modules.

The `theme_facodi` repository has its own Odoo 19 CI and must be pinned only after that CI is green. Its CI verifies native Odoo Website translations, theme-template generation, frontend asset compilation, homepage rendering, standard favicon ownership and `/slides` rendering.

## Google Cloud authentication

GitHub Actions uses OpenID Connect and Workload Identity Federation. Do not create or upload a long-lived Google service-account JSON key.

Repository Actions variables:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_GITHUB_SERVICE_ACCOUNT
DEPLOY_STAGING_ENABLED
DEPLOY_PRODUCTION_ENABLED
```

The VM uses its own runtime service account and obtains short-lived Artifact Registry credentials through the Compute Engine metadata identity.

## VM `.env`

The workflow does not overwrite runtime secrets. Create `.env` once per environment and protect it with filesystem permissions.

Required values include:

```text
POSTGRES_PASSWORD
ODOO_ADMIN_PASSWD
ODOO_DB
FACODI_MODULES=facodi_learning,theme_facodi
```

Odoo 19 does not accept `admin_passwd` as a server CLI option. The immutable image includes `facodi-odoo-server.sh`, which writes that value into a private mode-`0600` runtime config inside the disposable container and delegates to the official image entrypoint. Compose passes the configured database as the standard two-argument `-d`, `<ODOO_DB>` pair.

If an existing environment still contains `website_facodi`, `deploy-image.sh` normalizes that known legacy token for the deployment, but the operator should update the persisted `.env` after a successful transition.

## Deployment sequence

For staging/production when enabled:

1. checkout monorepo and recursive submodules;
2. validate architecture and pins;
3. authenticate GitHub to Google Cloud through WIF;
4. build an immutable image containing `facodi_learning`, `theme_facodi` and `theme_common`;
5. push the image tagged with `${GITHUB_SHA}`;
6. copy Compose plus `deploy-image.sh`, `migrate-theme-module-name.sh`, `apply-facodi-theme.sh` and `healthcheck.sh` to the VM;
7. pull the exact image using the VM identity;
8. stop the persistent Odoo process and start PostgreSQL;
9. run the guarded one-time legacy theme transition if required;
10. install/update `facodi_learning` and `theme_facodi`;
11. apply `theme_facodi` through Odoo's standard `button_choose_theme()` API;
12. start Odoo and require the HTTP health check to pass.

The VM does not need a clone of the monorepo.

## Why theme installation and application are separate

Odoo native themes first install/register theme templates. A website then selects a theme through the Website theme lifecycle. Therefore deployment must not assume that `-i theme_facodi` alone changes the current website.

`scripts/apply-facodi-theme.sh` uses `ir.module.module.button_choose_theme()` with a `website_id` context. It skips websites already using `theme_facodi`, keeping subsequent deployments idempotent.

## Legacy `website_facodi` transition

The previous presentation addon was not a native Odoo theme. Its single known inherited layout view cannot safely be renamed into the XML-ID namespace of `theme.ir.ui.view` templates.

The migration helper therefore removes only the known old view/module metadata after checking for ambiguity. It refuses to proceed when unexpected XML IDs or dependent custom views exist, and it never edits `website_page` content.

Take a PostgreSQL + filestore backup before the first deployment of this transition. If rollback is required after the transition, restore both persistent components with the previous image.

## Updating pins

Update a submodule only to a reviewed/verified commit, then commit the Gitlink change in this repository. The validator also enforces the exact `facodi-theme` and `odoo/design-themes` commits expected by the current integration.

## Rollback

Normal code-only rollback redeploys a previously known Artifact Registry image URI. Database compatibility still matters. For the first legacy-theme transition, image rollback alone is insufficient; restore the matching pre-deployment PostgreSQL database and filestore.
