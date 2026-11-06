# Changelog

## [0.0.2] - 2026-11-06

### Added

- ScienceLogo favicon on generated websites, replaceable with the `site.favicon` setting
- The language the method is written in, named once with its logo and a link to https://sciencelogo.org/: in the navigation bar of the overview page and at the foot of the booklet's title page
- Concept DOI in the citation file and the README

## [0.0.1] - 2026-11-05

### Added

- `build`: reads a workflow with the reference implementation and writes a website and a PDF booklet that describe its method
- Website: overview, stage and procedure pages, reference page, nested outline, breadcrumbs, reading order, search, link previews and a font switch
- Booklet: table of contents, page references, running titles and an analytical index, typeset with Typst
- `publish`: to a branch, the GitHub or GitLab Pages folder, or a plain folder
- Settings file `sciencelogo-documenter.toml`; Racket and `sciencelogo` installed automatically at pinned versions
- Example workflow, published to this repository's Pages on each release or on demand
