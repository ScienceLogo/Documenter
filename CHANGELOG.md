# Changelog

## [0.2.0] - 2026-11-09

Works with ScienceLogo 0.2. From this release, the first two numbers of the version name the language version that the Documenter reads.

### Added

- Phases: a page for each phase on the website, with phases in the outline, breadcrumbs and reading order; a chapter for each top-level phase in the booklet, and a Phases heading in its index
- The language version that each library states, shown with the library

### Changed

- Reads workflows written in ScienceLogo 0.2, installed at that pinned release
- The method text of each stage, phase and procedure ends where the reference reader says it ends
- A workflow no longer needs to sit in a Git repository; only publishing to a branch uses Git
- The example workflow uses the 0.2 syntax and groups its stages into two phases

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
