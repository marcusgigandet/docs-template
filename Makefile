# Documentation build (Sphinx). Targets:
#   make deps    - create .venv and install requirements
#   make gettext - extract translatable strings into docs/gettext/
#   make update  - refresh .po files under docs/locales/
#   make local   - build the working tree ("dev") into pages-local/
#   make live    - live-rebuild preview (English) at http://localhost:8000
#   make versions- build one site per released version (git tag) into pages/<tag>/
#   make pages   - "dev" at the pages/ root plus every released version
#   make clean   - remove build output
#
# Site layout: pages/ holds the working-tree ("dev") docs at the root,
# pages/<lang>/ for non-English languages of the dev build, and
# pages/<tag>/ for each released version, built from that tag's own docs
# (including its Doxygen XML) via a temporary git worktree. "dev" is
# special-cased as the site root in the docs templates and here.

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
	cd docs && ../$(INTL) build

local: deps doxygen
	$(SPHINX) -b html $(LANG_FLAGS) $(DEV_VERSION_FLAGS) -A docs_version=dev docs pages-local
	for lang in $(filter-out en,$(LANGUAGES)); do \
		$(SPHINX) -b html -D language=$$lang $(LANG_FLAGS) $(DEV_VERSION_FLAGS) -A docs_version=dev docs pages-local/$$lang; \
	done

live: deps doxygen
	$(LIVE) --port 8000 --watch README.md --watch src $(LANG_FLAGS) $(DEV_VERSION_FLAGS) -A docs_version=dev docs pages-local

# One site per released version, built from that tag's own checkout so
# each version's docs match its release. Worktrees land in .versions/
# and are removed again; the per-tag Doxygen XML never touches the
# working tree's doxygen-xml/.
versions: deps
	mkdir -p pages
	for tag in $(VERSIONS); do \
		worktree=.versions/$$tag; \
		git worktree add --detach $$worktree $$tag || continue; \
		( cd $$worktree && $(DOXYGEN) Doxyfile ); \
		$(SPHINX) -b html $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=$$tag $$worktree/docs pages/$$tag; \
		for lang in $(filter-out en,$(LANGUAGES)); do \
			$(SPHINX) -b html -D language=$$lang $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=$$tag $$worktree/docs pages/$$tag/$$lang; \
		done; \
		git worktree remove --force $$worktree; \
	done

pages: deps doxygen versions
	$(SPHINX) -b html $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=dev docs pages
	for lang in $(filter-out en,$(LANGUAGES)); do \
		$(SPHINX) -b html -D language=$$lang $(LANG_FLAGS) $(ALL_VERSION_FLAGS) -A docs_version=dev docs pages/$$lang; \
	done

clean:
	rm -rf pages-local pages doxygen-xml docs/api docs/gettext .versions
	git worktree prune
