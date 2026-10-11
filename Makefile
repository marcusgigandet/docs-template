# Documentation build (Sphinx). Targets:
#   make deps    - create .venv and install requirements
#   make gettext - extract translatable strings into docs/gettext/
#   make update  - refresh .po files under docs/locales/
#   make live    - live-rebuild preview (English) at http://localhost:8000
#   make versions- build one site per released version (git tag) into docs/pages/<tag>/
#   make pages   - "dev" at the docs/pages/ root plus every released version
#   make clean   - remove build output
#
# Site layout: docs/pages/ holds the working-tree ("dev") docs at the
# root, docs/pages/<lang>/ for non-English languages of the dev build,
# and docs/pages/<tag>/ for each released version, built from that
# tag's content (including its Doxygen XML) via a temporary git
# worktree under docs/.versions/, with the site chrome overlaid from
# the working tree (see the versions target). "dev" is special-cased
# as the site root in the docs templates and here.

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

# The newest released version. Its build is the "latest" docs, so it
# skips the out-of-date banner (docs/_templates/page.html compares
# docs_version against docs_latest_version). Falls back to "dev" for
# repositories without tags yet.
LATEST_VERSION := $(if $(VERSIONS),$(lastword $(VERSIONS)),dev)

empty :=
space := $(empty) $(empty)
comma := ,
LANGUAGES_CSV := $(subst $(space),$(comma),$(LANGUAGES))
VERSIONS_CSV  := $(subst $(space),$(comma),$(VERSIONS))
ALL_VERSIONS  := dev$(if $(VERSIONS_CSV),$(comma)$(VERSIONS_CSV))
# Released versions as a grep alternation (manifest generation below);
# "___" never matches a path, for repositories without tags yet.
VERSIONS_ALT  := $(if $(VERSIONS_CSV),$(subst $(comma),|,$(VERSIONS_CSV)),___)

# Switcher data injected into every build (docs/_templates/page.html).
# The language flags apply everywhere; the version list depends on the
# target — `local`/`live` build only the working tree, so they advertise
# just "dev" (linking to a tag from the preview would 404), while
# `pages`/`versions` build and advertise every released version.
LANG_FLAGS := -A docs_languages=$(LANGUAGES_CSV) \
              -A docs_language_names=$(LANG_NAMES)
DEV_VERSION_FLAGS := -A docs_versions=dev
ALL_VERSION_FLAGS := -A docs_versions=$(ALL_VERSIONS) \
                    -A docs_latest_version=$(LATEST_VERSION)

.PHONY: deps doxygen gettext update live linkcheck versions pages clean

deps: $(SPHINX)

$(SPHINX):
	python3 -m venv $(VENV)
	$(PIP) install -r requirements-docs.txt

# Regenerate the Doxygen XML consumed by Breathe (C++ reference).
doxygen:
	$(DOXYGEN) Doxyfile

# Extract translatable strings into .pot files.
gettext: deps doxygen
	$(SPHINX) -b gettext docs docs/gettext

# Create/refresh per-language .po files under docs/locales/ from the .pot
# files, then compile .mo catalogs used at build time. Untranslated
# strings fall back to English, so partial translations are fine.
update: gettext
	$(INTL) update -p docs/gettext -d docs/locales $(addprefix -l ,$(filter-out en,$(LANGUAGES)))
	@cd docs && ../$(INTL) build

# Check external links in the documentation. The linkcheck builder
# exits non-zero on broken links; CI runs this weekly
# (.github/workflows/docs-linkcheck.yml).
linkcheck: deps doxygen
	$(SPHINX) -b linkcheck docs docs/linkcheck

live: deps doxygen
	$(LIVE) --port 8000 --watch README.md --watch src -D release=dev $(LANG_FLAGS) $(DEV_VERSION_FLAGS) -A docs_version=dev docs docs/pages-local

# One site per released version, built from that tag's own checkout so
# each version's docs content matches its release. Worktrees land in
# docs/.versions/ and are removed again; the per-tag Doxygen XML never
# touches the working tree's docs/doxygen-xml/. The site chrome — Doxyfile,
# conf.py, _templates/, and the switcher JS/CSS, overlaid from the
# working tree before building (Doxyfile and conf.py travel together:
# the XML path the former writes is the one the latter reads) — is
# current, so every version's site (including tags cut before a chrome
# change) renders the current switcher, banners, and "latest" badge.
versions: deps
	@mkdir -p docs/pages
	@for tag in $(VERSIONS); do \
		worktree=docs/.versions/$$tag; \
		git worktree add --detach $$worktree $$tag || continue; \
		cp -R docs/_templates/. $$worktree/docs/_templates/; \
		cp docs/conf.py $$worktree/docs/conf.py; \
		cp Doxyfile $$worktree/Doxyfile; \
		cp docs/_static/language-switcher.js docs/_static/language-switcher.css $$worktree/docs/_static/; \
		( cd $$worktree && $(DOXYGEN) Doxyfile ); \
		$(SPHINX) -b html -D release=$$tag $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=$$tag $$worktree/docs docs/pages/$$tag; \
		for lang in $(filter-out en,$(LANGUAGES)); do \
			$(SPHINX) -b html -D language=$$lang -D release=$$tag $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=$$tag $$worktree/docs docs/pages/$$tag/$$lang; \
		done; \
		git worktree remove --force $$worktree; \
	done

pages: deps doxygen versions
	$(SPHINX) -b html -D release=dev $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=dev docs docs/pages
	@for lang in $(filter-out en,$(LANGUAGES)); do \
		$(SPHINX) -b html -D language=$$lang -D release=dev $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=dev docs docs/pages/$$lang; \
	done

# Page manifests for the switcher's existence check (see
# docs/_static/language-switcher.js): one docs-pages.js per version
# root, listing every built page relative to that root, all
# languages, recursively — including nested pages such as api/.
# "dev" is the site root; its manifest excludes the released-version
# subdirectories, which carry their own. Language subdirectories of
# the dev site are skipped as sites (their pages belong to the dev
# manifest).
	@for site in docs/pages docs/pages/*; do \
		[ -f "$$site/index.html" ] || continue; \
		ver=$${site#docs/pages}; ver=$${ver#/}; \
		case " $(LANGUAGES) " in *" $$ver "*) continue;; esac; \
		ver=$${ver:-dev}; \
		{ echo 'window.docsPages = window.docsPages || {};'; \
		  printf 'window.docsPages["%s"] = [' "$$ver"; \
		  find "$$site" -name '*.html' \
		    | grep -vE "^$$site/($(VERSIONS_ALT))/" \
		    | sed -e "s|^$$site/|  \"|" -e 's|$$|",|'; \
		  echo '];'; \
		} > "$$site/docs-pages.js"; \
	done
# Sitemap and robots.txt for the site root, written after the builds.
# Only indexable pages are listed: released versions are marked
# robots-noindex by the html-page-context hook in docs/conf.py, so
# their pages stay out of the sitemap, while the "dev" build's
# languages (<lang>/) are in. The URLs match the pages' canonical URLs
# (html_baseurl from docs/conf.py plus the language prefix). The 404
# and search pages are excluded — both are noindex. robots.txt points
# crawlers at the sitemap.
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
	git worktree prune
