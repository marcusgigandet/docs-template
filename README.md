# Docs Template

Sphinx documentation template for C++ projects: Markdown (MyST) pages,
Doxygen/Breathe/Exhale C++ reference, multi-language support via gettext,
and multi-version site builds from git tags. Use this repo as a template
("Use this template" on GitHub, or clone and strip the `.git` directory)
to get a configured docs site for a new project in minutes.

## Quick start

```sh
make deps     # create .venv and install requirements (once)
make live     # live-rebuild preview at http://localhost:8000
```

`make live` serves a live-rebuild preview at `http://localhost:8000`
(built into `docs/pages-local/`); `make pages` builds the deployable
multi-version site into `docs/pages/` — the newest released version
serves as the site root (the default documentation), each older tag
from `docs/pages/<tag>/`, and the working-tree ("dev") build from
`docs/pages/dev/`. `make local` builds just the current checkout's
site (the tag HEAD is on, or the working tree as "dev") into
`docs/pages-local/`, without the multi-version chrome — use `make
pages` for that. The Doxygen binary is required for the C++ reference
(`brew install doxygen` on macOS).

The switcher checks its target before navigating: `make pages` writes a
`docs-pages.js` manifest of built pages into each version's root, and
switching to a version that lacks the current page shows a notice
instead of navigating. `make pages` also writes `sitemap.xml` and
`robots.txt` at the site root, covering the indexable pages only — the
latest release's pages and their translations (the "dev" build and
older released versions are robots-noindex'd; see the
`html-page-context` hook in `docs/conf.py`).

`make linkcheck` checks external links and exits non-zero on broken
ones; a weekly scheduled workflow (`.github/workflows/docs-linkcheck.yml`)
runs it in CI.

## Configure your project

Work through this checklist after cloning from the template:

1. **Project identity** — set `project`, `author`, and `copyright` in
   `docs/conf.py`. The version shown in page titles is derived from git
   tags by the `Makefile`: released sites show their tag, working-tree
   builds show `dev`. When the version being viewed is not the latest
   release, a brief toast (`version_notice` in `docs/conf.py`) pops up
   linking the same page in the latest release at the site root; the
   latest release shows none.
2. **Site URL** — set `html_baseurl` in `docs/conf.py` to your deployed
   site (for GitHub Pages: `https://<user>.github.io/<repo>/`), and the
   `source_repository` / `footer_icons` URLs in `docs/conf.py` to your
   repository — they drive the header "edit this page" icon and the
   footer link. Each page's canonical URL is derived from
   `html_baseurl` plus the build's version and language, and every
   build other than the latest release (the site root) — the "dev"
   build and older tags — gets
   `<meta name="robots" content="noindex">`, so only the latest
   release's pages appear in search results. The
   404 page is never indexed — it is served for every unknown path, so
   it carries no canonical URL either — and search pages are left
   alone because Sphinx already marks them noindex. See the
   `html-page-context` hook at the bottom of `docs/conf.py`.
   Branding goes in `docs/conf.py` (`html_logo`,
   `html_favicon`, and the `sidebar_icon` project icon) and
   `docs/_static/custom.css` (accent colors, announcement-bar notices).
3. **Doxygen project name** — set `PROJECT_NAME` in `Doxyfile`.
4. **C++ sources** — point `INPUT` in `Doxyfile` at your sources, then
   replace the sample `src/example.hpp` (or delete `src/` and adjust
   `INPUT`). The C++ reference is regenerated automatically on every
   build; see `docs/code-reference.md`.
5. **Languages** — edit `LANGUAGES` and `LANG_NAMES` in the `Makefile`,
   the `docs_languages` / `docs_language_names` defaults and the
   `dev_banner` / `old_version_banner` / `switcher_notice` /
   `version_labels` translations
   in `docs/conf.py`,
   then run `make update` to generate `.po` files under
   `docs/locales/` and translate them. English needs no `.po` files;
   untranslated strings fall back to English.
6. **Pages** — write documentation as Markdown in `docs/`. The template
   ships stubs for the common pages (getting started, architecture with
   a mermaid diagram, changelog); fill them in and add new pages to the
   toctree in `docs/index.md`.
7. **Deployment** — the workflow at `.github/workflows/docs.yml` runs
   `make pages` on every push to the default branch and on every `v*`
   tag, then publishes `docs/pages/` to GitHub Pages. Enable Pages in
   the repository settings with "GitHub Actions" as the source. Adjust
   the workflow's `ref:` (and `source_branch` in `docs/conf.py`) if your
   default branch is not `main`.

## Layout

```text
Doxyfile               Doxygen configuration (C++ source -> XML)
Makefile               build targets: deps, doxygen, gettext, update,
                       live, linkcheck, versions, pages, clean
requirements-docs.txt  Python dependencies for the docs build
src/                   sample source consumed by Doxygen (replace)
docs/conf.py           Sphinx configuration
docs/index.md          home page + toctree
docs/getting-started.md build/install stub
docs/architecture.md   system overview stub + mermaid example
docs/changelog.md      release notes stub (mirrors the tag versions)
docs/404.md            not-found page; offers the dev version of pages
                       missing from the version being browsed, and is
                       never indexed (robots noindex, no canonical URL)
docs/code-reference.md C++ reference entry point
docs/_templates/       switcher, sidebar brand, and page-header
                       (edit/view) templates
docs/_static/          switcher styles, script, theme overrides
                       (version-switcher items verify their target
                       against the version's docs-pages.js manifest;
                       missing pages show a notice with a link to that
                       version's home)
docs/locales/          gettext translations (generated by `make update`)
.github/workflows/     CI: builds `make pages` and deploys to Pages;
                       a weekly scheduled workflow runs
                       `make linkcheck` for broken external links
```

Generated at build time under `docs/` (git-ignored):
`docs/doxygen-xml/`, `docs/api/`, `docs/gettext/`, `docs/pages/`,
`docs/pages-local/`, `docs/.versions/`.
