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
# and docs/pages/<tag>/ for each released version, built from that tag's
# own docs (including its Doxygen XML) via a temporary git worktree under
# docs/.versions/. "dev" is special-cased as the site root in the docs
# templates and here.

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

empty :=
space := $(empty) $(empty)
comma := ,
LANGUAGES_CSV := $(subst $(space),$(comma),$(LANGUAGES))
VERSIONS_CSV  := $(subst $(space),$(comma),$(VERSIONS))
ALL_VERSIONS  := dev$(if $(VERSIONS_CSV),$(comma)$(VERSIONS_CSV))

# Switcher data injected into every build (docs/_templates/page.html).
# The language flags apply everywhere; the version list depends on the
# target — `local`/`live` build only the working tree, so they advertise
# just "dev" (linking to a tag from the preview would 404), while
# `pages`/`versions` build and advertise every released version.
LANG_FLAGS := -A docs_languages=$(LANGUAGES_CSV) \
              -A docs_language_names=$(LANG_NAMES)
DEV_VERSION_FLAGS := -A docs_versions=dev
ALL_VERSION_FLAGS := -A docs_versions=$(ALL_VERSIONS)

.PHONY: deps doxygen gettext update local live versions pages clean

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

live: deps doxygen
	$(LIVE) --port 8000 --watch README.md --watch src -D release=dev $(LANG_FLAGS) $(DEV_VERSION_FLAGS) -A docs_version=dev docs docs/pages-local

# One site per released version, built from that tag's own checkout so
# each version's docs match its release. Worktrees land in docs/.versions/
# and are removed again; the per-tag Doxygen XML never touches the
# working tree's docs/doxygen-xml/.
versions: deps
	@mkdir -p docs/pages
	@for tag in $(VERSIONS); do \
		worktree=docs/.versions/$$tag; \
		git worktree add --detach $$worktree $$tag || continue; \
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
# languages. "dev" is the site root; language subdirectories of the
# dev site are skipped (their pages belong to the dev manifest).
	@for site in docs/pages docs/pages/*; do \
		[ -f "$$site/index.html" ] || continue; \
		ver=$${site#docs/pages}; ver=$${ver#/}; \
		case " $(LANGUAGES) " in *" $$ver "*) continue;; esac; \
		ver=$${ver:-dev}; \
		{ echo 'window.docsPages = window.docsPages || {};'; \
		  printf 'window.docsPages["%s"] = [' "$$ver"; \
		  { find "$$site" -maxdepth 1 -name '*.html'; \
		    for lang in $(filter-out en,$(LANGUAGES)); do \
		      find "$$site/$$lang" -name '*.html'; \
		    done; \
		  } | sed -e "s|^$$site/|  \"|" -e 's|$$|",|'; \
		  echo '];'; \
		} > "$$site/docs-pages.js"; \
	done

clean:
	@rm -rf docs/pages-local docs/pages doxygen-xml docs/doxygen-xml docs/api docs/gettext docs/.versions
	git worktree prune
