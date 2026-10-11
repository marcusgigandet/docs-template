import os
import sys

# Let autodoc import Python modules from the repo root once they exist.
sys.path.insert(0, os.path.abspath(".."))

# --- Project identity (edit these per project) ---
project = "Project Name"
author = "Author Name (s)"
copyright = "Copyright"
# Version shown in page titles. The Makefile overrides this per build
# with -D: the released git tag for each version site, "dev" for
# working-tree builds. This default covers direct sphinx-build /
# sphinx-autobuild runs, which build the working tree.
release = "dev"

# --- Multilingual support (gettext via sphinx-intl) ---
# Source strings are English. `make gettext` extracts them into
# docs/gettext/*.pot, `make update` refreshes docs/locales/<lang>/LC_MESSAGES
# .po files, and the Makefile builds one site per language (English at the
# root, other languages in <lang>/ subdirectories). Messages without a
# translation fall back to the English source — the Exhale-generated
# docs/api/ pages need no manual translation.
language = "en"
locale_dirs = ["locales/"]
# One .pot/.po per source page instead of a single combined file.
gettext_compact = False

# --- Site switcher data (language + version dropdowns) ---
# Comma-separated values consumed by docs/_templates/page.html. The
# Makefile overrides these per build with -A flags (see its build loops);
# these defaults only apply to direct sphinx-build / sphinx-autobuild
# runs (e.g. `make live`), which build the working tree as version "dev".
# "dev" is special-cased as the site root; released versions (git tags)
# are served from <tag>/ subdirectories.
# Working-tree ("dev") builds show this notice in the announcement bar
# (see docs/_templates/page.html). Sphinx's gettext pipeline only covers
# document sources, not templates, so the per-language text lives here:
# add one entry per language in docs_languages below.
dev_banner = {
    "en": "Development version — built from the working tree; content may change.",
    "fr": "Version de développement — construite depuis l'arborescence de travail ; le contenu peut changer.",
}

# Released-version builds show this notice in the announcement bar
# instead (docs/_templates/page.html): the reader may be on an
# outdated release, with a link to the same page in the current
# ("dev") build at the site root. The latest git tag
# (docs_latest_version, set by the Makefile) shows no banner.
# Template strings, not covered by
# gettext — one entry per language in docs_languages below.
# "{version}" is replaced with the version id at render time.
old_version_banner = {
    "en": {
        "message": "You are reading the documentation for {version}, which may be out of date.",
        "latest": "See the current version",
    },
    "fr": {
        "message": "Vous lisez la documentation de la version {version}, qui peut être obsolète.",
        "latest": "Voir la version actuelle",
    },
}

# Notice shown by the version switcher when the target page does not
# exist in the target version (docs/_static/language-switcher.js). Not
# covered by gettext either; "{version}" is replaced with the target
# version at runtime.
switcher_notice = {
    "en": {
        "message": "This page does not exist in the {version} version. It may have been added after, or removed before, that release.",
        "home": "Go to the {version} home page",
        "dismiss": "Dismiss",
    },
    "fr": {
        "message": "Cette page n'existe pas dans la version {version}. Elle a peut-être été ajoutée après, ou supprimée avant cette version.",
        "home": "Aller à la page d'accueil de {version}",
        "dismiss": "Fermer",
    },
}

# Strings for the version switcher panel
# (docs/_templates/components/version-switcher.html): the filter box
# placeholder (shown once there are many versions) and the badge marking
# the newest release. Not covered by gettext either — one entry per
# language in docs_languages below.
version_labels = {
    "en": {"filter": "Filter versions", "latest": "latest"},
    "fr": {"filter": "Filtrer les versions", "latest": "dernière"},
}

html_context = {
    "docs_version": "dev",
    "docs_versions": "dev",
    # The latest released version (newest git tag), passed by the
    # Makefile via -A. Its build skips the out-of-date banner; this
    # default only covers direct sphinx-build runs, which build the
    # working tree as "dev" and never show it either.
    "docs_latest_version": "dev",
    "docs_languages": "en,fr",
    "docs_language_names": "English,Français",
    "dev_banner": dev_banner,
    "old_version_banner": old_version_banner,
    "switcher_notice": switcher_notice,
    "version_labels": version_labels,
    # Project icon in the sidebar (docs/_templates/sidebar/brand.html):
    # a path under docs/, e.g. "_static/icon.svg". Leave None for a
    # text-only brand.
    "sidebar_icon": None,
}

extensions = [
    "myst_parser",
    "sphinxcontrib.mermaid",
    "sphinx.ext.autodoc",
    "sphinx.ext.napoleon",
    "sphinx.ext.viewcode",
    "breathe",
    "exhale",
    "sphinx_last_updated_by_git",
    "sphinx_copybutton",
]

# "Last updated" in the page footer: the date of the last commit that
# touched that page's source file, from git history.
html_last_updated_fmt = "%Y-%m-%d"
git_last_updated_timezone = "UTC"

# C++ API reference. The Doxygen XML in doxygen-xml/ (next to this file)
# is generated by `make doxygen` (see Doxyfile at the repo root, which
# points Doxygen at the project's sources).
breathe_projects = {"myproject": os.path.abspath("doxygen-xml")}
breathe_default_project = "myproject"
# Breathe skips members defined in implementation files (.cpp) by
# default. Empty the list so {doxygenfunction} finds definitions in .cpp
# files too; harmless for header-only projects.
breathe_implementation_filename_extensions = []

# Exhale auto-generates the full C++ reference (docs/api/) from the Doxygen
# XML on every build — no per-function directives to maintain.
exhale_args = {
    "containmentFolder": "./api",
    "rootFileName": "libraryroot.rst",
    "rootFileTitle": "C++ Reference",
    "doxygenStripFromPath": "..",
    "createTreeView": True,
}

breathe_domain_by_extension = {
    ".hpp": ".cpp",
    ".h": "cpp",
    ".cpp": "cpp",
    ".cppm": ".cpp",
}

# Treat ```mermaid fences in Markdown as the mermaid directive, so plain
# .md pages with mermaid diagrams work unmodified.
myst_fence_as_directive = ["mermaid"]

mermaid_version = "12.1.0"

# Branding: drop a logo and favicon into docs/_static/ and uncomment.
# html_logo appears centered above the sidebar navigation; for a small
# icon next to the project name in the sidebar instead, set
# "sidebar_icon" in html_context above.
# html_logo = "_static/logo.svg"
# html_favicon = "_static/favicon.png"

html_theme = "furo"
# Public URL of the deployed site (GitHub Pages), used for the canonical
# URL of built pages (see the html-page-context hook at the bottom of
# this file). Set to https://<user>.github.io/<repo>/.
html_baseurl = "https://example.github.io/project/"
templates_path = ["_templates"]
html_static_path = ["_static"]
# Generated output lives inside the source tree (docs/pages/,
# docs/pages-local/, docs/gettext/), and `make versions` checks each
# git tag out into docs/.versions/ while building it. Keep all of it
# out of the document set — Sphinx otherwise re-discovers built files
# (e.g. copied LICENSE.md assets) on the next build.
exclude_patterns = ["pages/*", "pages-local/*", ".versions/*", "linkcheck/*"]
html_css_files = ["language-switcher.css", "custom.css"]
html_js_files = ["language-switcher.js"]

# Non-empty so Furo renders the announcement bar that hosts the language
# dropdown markup; language-switcher.js then moves the dropdown into the
# page header.
html_theme_options = {
    "announcement": "Language switcher",
    # "Edit this page" / "view source" icons in the page header: set to
    # your repository and default branch. Pages generated by Exhale
    # (api/) hide the icons via docs/_templates/components/.
    "source_repository": "https://github.com/example/project",
    "source_branch": "main",
    "source_directory": "docs",
    "footer_icons": [
        {
            "name": "GitHub",
            # Set to your project's GitHub repository URL.
            "url": "https://github.com/example/project",
            "html": (
                '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"'
                ' viewBox="0 0 16 16" fill="currentColor" role="img"'
                ' aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0'
                " 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38"
                " 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01"
                " 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95"
                " 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18"
                " 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08"
                " 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54"
                " 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16"
                " 8c0-4.42-3.58-8-8-8Z"
                '"/></svg>'
            ),
        },
    ],
}

def _page_meta(app, pagename, templatename, context, doctree):
    version = context.get("docs_version", "dev")
    language = app.config.language or "en"

    if app.config.html_baseurl:
        prefix = "" if version == "dev" else f"{version}/"

        if language != "en":
            prefix += f"{language}/"

        context["pageurl"] = (
            app.config.html_baseurl.rstrip("/")
            + "/"
            + prefix
            + pagename
            + ".html"
        )

    if pagename == "404":
        context["pageurl"] = None
        context["metatags"] = (
            context.get("metatags", "")
            + '<meta name="robots" content="noindex">\n'
        )
    elif version != "dev" and pagename != "search":
        context["metatags"] = (
            context.get("metatags", "")
            + '<meta name="robots" content="noindex">\n'
        )


def setup(app):
    app.connect("html-page-context", _page_meta)