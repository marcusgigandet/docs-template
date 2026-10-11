# Documentation build (Sphinx). Targets:
#   make deps    - create .venv and install requirements
#   make gettext - extract translatable strings into docs/gettext/
#   make update  - refresh .po files under docs/locales/
#   make live    - live-rebuild preview (English) at http://localhost:8000
#   make versions- build one site per released version (git tag), newest at the root
#   make pages   - every released version plus the working tree ("dev")
#   make clean   - remove build output
#
# Site layout: the newest git tag is the site root (the default
# documentation), each older tag is served from docs/pages/<tag>/, and
# the working-tree ("dev") build from docs/pages/dev/. Each version's
# English pages sit at its root, one <lang>/ subdirectory per other
# language. Released versions are built from that tag's content
# (including its Doxygen XML) via a temporary git worktree under
# docs/.versions/, with the site chrome overlaid from the working tree
# (see the versions target). The version serving as the root is passed
# to the docs templates as docs_root_version; without tags, "dev" is
# the root — and `make live` always serves the working tree at the
# preview root.

VENV    := .venv
PIP     := $(VENV)/bin/pip
SPHINX  := $(VENV)/bin/sphinx-build
LIVE    := $(VENV)/bin/sphinx-autobuild
INTL    := $(VENV)/bin/sphinx-intl
DOXYGEN := doxygen

# Site languages: English at each version's root, one <lang>/ subdirectory
# per other language. LANG_NAMES pairs positionally with LANGUAGES.
LANGUAGES  := en fr
LANG_NAMES := English,Français

# Released docs versions: one git tag per version. Override to build a
# subset, e.g. `make pages VERSIONS="v1.0"`. Each tag must contain the
# docs (docs/, Doxyfile, and the sources Doxygen consumes).
VERSIONS ?= $(shell git tag --list 'v*' | sort -V)

# The newest released version: its build is the site root (the
# default documentation) and the "latest" docs, so it also skips the
# out-of-date banner (docs/_templates/page.html compares docs_version
# against docs_latest_version). Falls back to "dev" for repositories
# without tags yet.
LATEST_VERSION := $(if $(VERSIONS),$(lastword $(VERSIONS)),dev)

# Where the working-tree ("dev") build lands: the site root when it is
# the newest version (no tags yet), otherwise docs/pages/dev/.
DEV_OUTDIR := docs/pages$(if $(filter dev,$(LATEST_VERSION)),,/dev)

empty :=
space := $(empty) $(empty)
comma := ,
LANGUAGES_CSV := $(subst $(space),$(comma),$(LANGUAGES))
VERSIONS_CSV  := $(subst $(space),$(comma),$(VERSIONS))
ALL_VERSIONS  := dev$(if $(VERSIONS_CSV),$(comma)$(VERSIONS_CSV))
# Every version id as a grep alternation (manifest and sitemap
# generation below), for excluding one version's pages from another
# version's file lists. Without tags this is just "dev", which then
# being the site root excludes nothing.
VERSIONS_ALT  := $(subst $(comma),|,$(ALL_VERSIONS))

# Switcher data injected into every build (docs/_templates/page.html).
# The language flags apply everywhere; the version list depends on the
# target — `local`/`live` build only the working tree, so they advertise
# just "dev" (linking to a tag from the preview would 404), while
# `pages`/`versions` build and advertise every released version.
# docs_root_version (the version served at the site root) follows
# LATEST_VERSION; the live preview keeps conf.py's "dev" default.
LANG_FLAGS := -A docs_languages=$(LANGUAGES_CSV) \
              -A docs_language_names=$(LANG_NAMES)
DEV_VERSION_FLAGS := -A docs_versions=dev
ALL_VERSION_FLAGS := -A docs_versions=$(ALL_VERSIONS) \
                    -A docs_latest_version=$(LATEST_VERSION) \
                    -A docs_root_version=$(LATEST_VERSION)

.PHONY: deps doxygen gettext update live linkcheck versions pages clean

deps: $(SPHINX)

$(SPHINX):
	@python3 -m venv $(VENV)
	@$(PIP) install -r requirements-docs.txt

# Regenerate the Doxygen XML consumed by Breathe (C++ reference).
doxygen:
	@$(DOXYGEN) Doxyfile

# Extract translatable strings into .pot files.
gettext: deps doxygen
	@$(SPHINX) -b gettext docs docs/gettext

# Create/refresh per-language .po files under docs/locales/ from the .pot
# files, then compile .mo catalogs used at build time. Untranslated
# strings fall back to English, so partial translations are fine.
update: gettext
	@$(INTL) update -p docs/gettext -d docs/locales $(addprefix -l ,$(filter-out en,$(LANGUAGES)))
	@cd docs && ../$(INTL) build

# Check external links in the documentation. The linkcheck builder
# exits non-zero on broken links; CI runs this weekly
# (.github/workflows/docs-linkcheck.yml).
linkcheck: deps doxygen
	@$(SPHINX) -b linkcheck docs docs/linkcheck

live: deps doxygen
	$(LIVE) --port 8000 --watch README.md --watch src -D release=dev $(LANG_FLAGS) $(DEV_VERSION_FLAGS) -A docs_version=dev docs docs/pages-local

# One site per released version, built from that tag's own checkout so
# each version's docs content matches its release. The newest tag
# builds into the site root (docs/pages/), older tags into
# docs/pages/<tag>/. Worktrees land in docs/.versions/ and are removed
# again; the per-tag Doxygen XML never touches the working tree's
# docs/doxygen-xml/. The site chrome — Doxyfile, conf.py, 404.md (so
# the root build emits the 404 page GitHub Pages serves for missing
# paths), _templates/, and the switcher JS/CSS, overlaid from the
# working tree before building (Doxyfile and conf.py travel together:
# the XML path the former writes is the one the latter reads) — is
# current, so every version's site (including tags cut before a chrome
# change) renders the current switcher, banners, and "latest" badge.
versions: deps
	@mkdir -p docs/pages
	@for tag in $(VERSIONS); do \
		worktree=docs/.versions/$$tag; \
		git worktree add --detach $$worktree $$tag || continue; \
		outdir=docs/pages/$$tag; \
		if [ "$$tag" = "$(LATEST_VERSION)" ]; then outdir=docs/pages; fi; \
		cp -R docs/_templates/. $$worktree/docs/_templates/; \
		cp docs/conf.py docs/404.md $$worktree/docs/; \
		cp Doxyfile $$worktree/Doxyfile; \
		cp docs/_static/language-switcher.js docs/_static/language-switcher.css $$worktree/docs/_static/; \
		( cd $$worktree && $(DOXYGEN) Doxyfile ); \
		$(SPHINX) -b html -D release=$$tag $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=$$tag $$worktree/docs $$outdir; \
		for lang in $(filter-out en,$(LANGUAGES)); do \
			$(SPHINX) -b html -D language=$$lang -D release=$$tag $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=$$tag $$worktree/docs $$outdir/$$lang; \
		done; \
		git worktree remove --force $$worktree; \
	done

# The working-tree ("dev") build: DEV_OUTDIR is the site root until the
# first tag exists, docs/pages/dev/ afterwards (the newest tag owns the
# root — see versions above).
pages: deps doxygen versions
	@$(SPHINX) -b html -D release=dev $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=dev docs $(DEV_OUTDIR)
	@for lang in $(filter-out en,$(LANGUAGES)); do \
		$(SPHINX) -b html -D language=$$lang -D release=dev $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=dev docs $(DEV_OUTDIR)/$$lang; \
	done

# Remove the sites of versions that no longer exist: a deleted or
# renamed tag (or an older site layout) would otherwise leave an
# orphaned site under docs/pages/ that gets deployed on every push —
# reachable by URL but listed in no version switcher. Kept: the
# current versions ("dev" plus the tags, including a VERSIONS override
# subset), the language directories, and the root site itself.
	@for site in docs/pages/*; do \
		[ -f "$$site/index.html" ] || continue; \
		ver=$${site#docs/pages/}; \
		case ",$(ALL_VERSIONS)," in *",$$ver,"*) continue;; esac; \
		case " $(LANGUAGES) " in *" $$ver "*) continue;; esac; \
		echo "Removing stale version directory: $$site"; \
		rm -rf "$$site"; \
	done

# Page manifests for the switcher's existence check (see
# docs/_static/language-switcher.js): one docs-pages.js per version
# root, listing every built page relative to that root, all
# languages, recursively — including nested pages such as api/. The
# site root's manifest is keyed by the latest version id (that build
# lives there); "dev" and each older tag carry their own manifest in
# their subdirectory. Each manifest excludes the other versions'
# subdirectories; language subdirectories are skipped as sites (their
# pages belong to the enclosing version's manifest).
	@for site in docs/pages docs/pages/*; do \
		[ -f "$$site/index.html" ] || continue; \
		ver=$${site#docs/pages}; ver=$${ver#/}; \
		case " $(LANGUAGES) " in *" $$ver "*) continue;; esac; \
		ver=$${ver:-$(LATEST_VERSION)}; \
		{ echo 'window.docsPages = window.docsPages || {};'; \
		  printf 'window.docsPages["%s"] = [' "$$ver"; \
		  find "$$site" -name '*.html' \
		    | grep -vE "^$$site/($(VERSIONS_ALT))/" \
		    | sed -e "s|^$$site/|  \"|" -e 's|$$|",|'; \
		  echo '];'; \
		} > "$$site/docs-pages.js"; \
	done
# Sitemap and robots.txt for the site root, written after the builds.
# Only indexable pages are listed: the latest release's pages (the
# site root, all languages). The "dev" build and older tags are
# marked robots-noindex by the html-page-context hook in
# docs/conf.py, so their subdirectories stay out of the sitemap. The
# URLs match the pages' canonical URLs (html_baseurl from docs/conf.py
# plus the language prefix). The 404 and search pages are excluded —
# both are noindex. robots.txt points crawlers at the sitemap.
	@base=`$(VENV)/bin/python -c "import sys; sys.path.insert(0, 'docs'); import conf; print(conf.html_baseurl.rstrip('/'))"`; \
	{ echo '<?xml version="1.0" encoding="UTF-8"?>'; \
	  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'; \
	  find docs/pages -name '*.html' \
	    | grep -vE "^docs/pages/($(VERSIONS_ALT))/" \
	    | grep -vE "/(404|search)\.html$$" \
	    | sort \
	    | sed -e "s|^docs/pages/|  <url><loc>$$base/|" -e 's|$$|</loc></url>|'; \
	  echo '</urlset>'; \
	} > docs/pages/sitemap.xml; \
	printf 'User-agent: *\nSitemap: %s/sitemap.xml\n' "$$base" > docs/pages/robots.txt
	@for tag in $(VERSIONS); do rm -f docs/pages/$$tag/sitemap.xml docs/pages/$$tag/robots.txt; done

clean:
	@rm -rf docs/pages-local docs/pages doxygen-xml docs/doxygen-xml docs/api docs/gettext docs/linkcheck docs/.versions
	@git worktree prune
