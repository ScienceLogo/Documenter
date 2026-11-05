# ScienceLogo Documenter

`sciencelogo-documenter` is a Python package that publishes a ScienceLogo
workflow as a web hypertext and a PDF booklet. Give it the workflow's entry
file, on your machine or in CI, and it builds both and publishes the site to
GitHub, GitLab, Forgejo or Codeberg Pages.

## How to use it

### Requirements

- Python 3.12 or later, and [uv](https://docs.astral.sh/uv/) to run the
  package with `uvx`.
- The workflow must sit in a Git repository, as ScienceLogo includes
  require.

Nothing else needs to be installed. On first use the Documenter downloads
the tested versions of Racket and of the `sciencelogo` package and keeps
them in a cache. The booklet is compiled with Typst, which comes as a Python
dependency.

### Build the website and the booklet

```
uvx sciencelogo-documenter build workflow.rkt
```

`workflow.rkt` is the workflow's entry file. The files it includes are read
too. The website goes to `site/` and the booklet to `booklet.pdf`, in the
output folder (`--out DIR`).

If the workflow is invalid, the build stops with the reader's message and
produces nothing.

### Publish

```
uvx sciencelogo-documenter publish --target pages-branch
```

The targets are:

| Target | Where the website goes | Platforms |
| --- | --- | --- |
| `pages-branch` | a `pages` branch of the repository | GitHub, GitLab, Forgejo, Codeberg |
| `github-pages` | the folder that GitHub Pages deploys | GitHub |
| `gitlab-pages` | the folder that GitLab Pages deploys | GitLab |
| `dir` | a plain folder | any |

`publish` uses the CI job's own token. It writes only to the publishing
branch or folder, never to the workflow's files. The intended use is a CI
job that builds and publishes the documentation on every push.

### Customise

Everything is optional. Without configuration, the Documenter uses its
standard style (see the next section).

To change it, add `sciencelogo-documenter.toml` at the root of the workflow
repository, or pass another file with `--config FILE`. The file can set:

- fonts, colours for each category and for the page, in light and dark
  mode;
- logos for the website header and the booklet title page;
- layout parameters, such as page depth and paper size (A4 or A5);
- index entries;
- the Racket and `sciencelogo` versions, if you want to try versions other
  than the tested ones, at your own risk.

The build warns when a chosen colour has a text contrast below 4.5:1.

### Link to a library's documentation

Libraries that a workflow imports publish their own documentation, and the
Documenter links to it instead of regenerating it. A library declares its
documentation URL with a marker in a comment at the top of its entry file:

```
@doc url: https://example.org/my-library/
```

If the marker appears more than once, the first one wins and the build
warns. A library without the marker is neither mapped nor documented, but
its procedures still appear wherever the workflow calls them.

## Justification of choices

Every layout choice is a parameter. The defaults come from a narrative
review of research on hypertext comprehension, text signalling, typography,
colour, communicating uncertainty, and reading on paper and on screen.

Each finding is labelled by strength:

- **strong:** meta-analyses, or consistent results across many studies;
- **moderate:** several experiments that agree, or one large experiment;
- **weak:** one small study, or grey literature;
- **practice:** standards or professional practice, not tested.

No study has tested documentation of scientific workflows, and most
participants were students. The defaults are therefore well-founded
starting points, not proven optima. That is why every one of them can be
changed.

### Pages of medium size, not one item per page

There is no evidence that splitting a text into small, one-item pages helps
comprehension. Following links has a cost: choosing and navigating raise
cognitive load, and hypertext helps searching more than understanding
(Dillon & Gabbard, 1998; DeStefano & LeFevre, 2007; strong). Longer nodes
did better in a retrieval task (Kim & Eastman, 1999; weak). Very long
scrolling pages also hurt, and page-by-page reading beat scrolling (Piolat
et al., 1997; Sanchez & Wiley, 2009; moderate). Help that suits novices can
hinder experts (Kalyuga et al., 2003; strong).

**Default:** one page for each unit that has its own `about`: the workflow,
each stage and each procedure. A stage page shows each procedure it calls as
a short block, with a link to the procedure's own page, so the reader
understands the stage without leaving it. Deeper detail is shown inline.

### Structure, reading order and search

A visible hierarchy improves comprehension for readers new to a topic, and
does not affect experts (Potelle & Rouet, 2003; Amadieu et al., 2009;
moderate). A coherent reading order helps the same readers (Salmerón et al.,
2005; McNamara et al., 1996; moderate), and suggested links help through the
reading order they create (Madrid et al., 2009; moderate). Breadcrumbs
reduced use of the Back button and gave a more hierarchical picture of a
site (Rogers & Chaparro, 2003; weak).

In online documentation, browsing the structure was faster and gave fewer
errors than searching (Hertzum & Frøkjær, 1996). Site search did not beat
browsing the menus (Katz & Byrne, 2003), and people prefer small navigation
steps even when they know their target (Teevan et al., 2004).

**Defaults:**

- an always-visible nested outline of the method that marks the current
  page, and breadcrumbs under the title;
- Previous and Next links on every page, in method order, which is the same
  order as the booklet;
- a search box on every page, over names, `about` texts and the verbose
  code, as a complement to the structure and never a substitute for it.

### Summary first, links and previews

Text signals, such as headings, overviews and summaries, improve memory for
what they mark (Lorch, 1989; Hyönä & Lorch, 2004; Schneider et al., 2018;
strong). Readers treat linked words as markers of importance and, when
skimming, process mainly the linked words (Fitzsimmons et al., 2019, 2020;
moderate). They choose links by the cues these give about the target
(Pirolli & Card, 1999; moderate), and previews of the target made search
more efficient (Maes et al., 2006; weak).

**Defaults:**

- each page shows, in order, the title, the `about`, a block of facts
  (performer, inputs, result with units, uncertainty), and then the verbose
  code;
- a missing `about` is flagged visibly;
- an item is linked at its first mention in each section;
- hovering over or focusing a link shows the target's `about`.

### Type

Reading speed is at its maximum over a wide range of text sizes (Legge &
Bigelow, 2011; strong). On screen, comprehension improved with text up to
about 24 px (Rello et al., 2016; moderate). Serifs make no meaningful
difference to legibility (Arditi & Cho, 2005; moderate). Distinct letter
shapes reduce misreading (Beier & Larson, 2010; moderate). No font is best
for everyone: each reader's fastest and slowest fonts differed by about
35 % in reading speed (Wallace et al., 2022; moderate). Dark text on a light
background is more legible than the reverse (Piepenbrock et al., 2013;
Dobres et al., 2016; moderate).

**Defaults:**

- **Fonts:** Atkinson Hyperlegible Next for text and Atkinson Hyperlegible
  Mono for code and values. These were chosen for distinct letter shapes,
  a large x-height and a marked zero; the font's own design claims have not
  been tested in peer-reviewed work. Every font must pass a glyph test
  (`Il1 O0 rn m 5S 8B µ ± × ° ²`) before adoption.
- **Font switch:** because readers differ, the website lets each reader
  switch to IBM Plex Serif or IBM Plex Sans, and remembers the choice.
- **On screen:** a base size of 1.25 rem (20 px) that follows the browser's
  setting, line height 1.5, and lines of about 70 characters.
- **On paper:** body text of 10.5 to 11 pt (practice).
- **Polarity:** a light background, with dark mode only when the reader's
  system asks for it.

### Colour and categories

About 8 % of men of European descent have a red-green colour deficiency
(Birch, 2012; strong). The Okabe–Ito palette stays distinguishable for them
(Okabe & Ito, 2008; Wong, 2011; practice), and red-green contrasts should be
avoided (Crameri et al., 2020; strong). Colour coding helps readers find
things but can also hurt (Christ, 1975; moderate), and general syntax
highlighting did not improve code comprehension (Hannebauer et al., 2018;
moderate). No more than 5 to 7 colour codes should be used at once (Healey,
1996; weak). Text needs at least 4.5:1 contrast, and colour must never be
the only cue (WCAG 2.2; practice).

**Defaults:**

- five categories are marked: stages, performers, procedures, values with
  units, and uncertainty;
- each has its own type style, so the meaning survives without colour and
  in a greyscale print;
- an Okabe–Ito hue is added as a marker, or as a darkened text colour that
  passes 4.5:1 and stays distinguishable under simulated colour-vision
  deficiency;
- links are underlined rather than given a sixth colour;
- there is no general syntax highlighting.

### Values and uncertainty

Units follow the SI Brochure and ISO 80000-1 (practice): a non-breaking
space between number and unit keeps them on one line. Stating uncertainty
as a numerical range barely reduced trust, and readers did perceive it (van
der Bles et al., 2020; moderate). **Default:** uncertainty always appears
next to its value, never only behind a link or a hover.

### The booklet

Comprehension of expository text is better on paper than on screen (Clinton,
2019; Kong et al., 2018; Delgado et al., 2018; strong), so a method
description deserves a version designed for careful reading on paper.

**Defaults:**

- **Order:** an overview, then one chapter per stage followed by the
  procedures only that stage uses, then the shared procedures, the record
  types and the index. This keeps related content together, following the
  reading-order findings above.
- **Two indexes:**
  - a structural index (table of contents) at the front, which shows the
    whole method in order with page numbers;
  - an analytical index at the back, grouped by kind (stages, procedures,
    performers, record types with their fields, requirements), alphabetical
    within each kind, with the defining page in bold (ISO 999, practice).

  In e-books, a back-of-book index was faster and more useful for finding
  information than the table of contents or full-text search (Abdullah &
  Gibb, 2008, 2009; weak).
- **Paper:** running titles, PDF bookmarks, page references next to every
  internal link, and library documentation URLs printed in full. The page
  size is A4, with A5 as an option.

### References

- Abdullah, N., & Gibb, F. (2008). Using a task-based approach in evaluating
  the usability of BoBIs in an e-book environment. *ECIR 2008*, LNCS 4956,
  246–257. https://doi.org/10.1007/978-3-540-78646-7_24
- Abdullah, N., & Gibb, F. (2009). Students' attitudes towards e-books in a
  Scottish higher education institute: Part 3 – search and browse tasks.
  *Library Review*, 58(1), 17–27. https://doi.org/10.1108/00242530910928906
- Amadieu, F., van Gog, T., Paas, F., Tricot, A., & Mariné, C. (2009).
  Effects of prior knowledge and concept-map structure on disorientation,
  cognitive load, and learning. *Learning and Instruction*, 19(5), 376–386.
  https://doi.org/10.1016/j.learninstruc.2009.02.005
- Arditi, A., & Cho, J. (2005). Serifs and font legibility. *Vision
  Research*, 45(23), 2926–2933. https://doi.org/10.1016/j.visres.2005.06.013
- Beier, S., & Larson, K. (2010). Design improvements for frequently
  misrecognized letters. *Information Design Journal*, 18(2), 118–137.
  https://doi.org/10.1075/idj.18.2.03bei
- BIPM (2019). *The International System of Units (SI)*, 9th edition.
- Birch, J. (2012). Worldwide prevalence of red-green color deficiency.
  *JOSA A*, 29(3), 313–320. https://doi.org/10.1364/JOSAA.29.000313
- Christ, R. E. (1975). Review and analysis of color coding research for
  visual displays. *Human Factors*, 17(6), 542–570.
  https://doi.org/10.1177/001872087501700602
- Clinton, V. (2019). Reading from paper compared to screens: A systematic
  review and meta-analysis. *Journal of Research in Reading*, 42(2),
  288–325. https://doi.org/10.1111/1467-9817.12269
- Crameri, F., Shephard, G. E., & Heron, P. J. (2020). The misuse of colour
  in science communication. *Nature Communications*, 11, 5444.
  https://doi.org/10.1038/s41467-020-19160-7
- Delgado, P., Vargas, C., Ackerman, R., & Salmerón, L. (2018). Don't throw
  away your printed books: A meta-analysis on the effects of reading media
  on reading comprehension. *Educational Research Review*, 25, 23–38.
  https://doi.org/10.1016/j.edurev.2018.09.003
- DeStefano, D., & LeFevre, J.-A. (2007). Cognitive load in hypertext
  reading: A review. *Computers in Human Behavior*, 23(3), 1616–1641.
  https://doi.org/10.1016/j.chb.2005.08.012
- Dillon, A., & Gabbard, R. (1998). Hypermedia as an educational technology:
  A review of the quantitative research literature on learner
  comprehension, control, and style. *Review of Educational Research*,
  68(3), 322–349. https://doi.org/10.3102/00346543068003322
- Dobres, J., Chahine, N., Reimer, B., Gould, D., Mehler, B., & Coughlin,
  J. F. (2016). Utilising psychophysical techniques to investigate the
  effects of age, typeface design, size and display polarity on glance
  legibility. *Ergonomics*, 59(10), 1377–1391.
  https://doi.org/10.1080/00140139.2015.1137637
- Fitzsimmons, G., Weal, M. J., & Drieghe, D. (2019). The impact of
  hyperlinks on reading text. *PLOS ONE*, 14(2), e0210900.
  https://doi.org/10.1371/journal.pone.0210900
- Fitzsimmons, G., Jayes, L. T., Weal, M. J., & Drieghe, D. (2020). The
  impact of skim reading and navigation when reading hyperlinks on the web.
  *PLOS ONE*, 15(9), e0239134. https://doi.org/10.1371/journal.pone.0239134
- Hannebauer, C., Hesenius, M., & Gruhn, V. (2018). Does syntax highlighting
  help programming novices? *Empirical Software Engineering*, 23(5),
  2795–2828. https://doi.org/10.1007/s10664-017-9579-0
- Healey, C. G. (1996). Choosing effective colours for data visualization.
  *Proceedings IEEE Visualization '96*, 263–270.
  https://doi.org/10.1109/VISUAL.1996.568118
- Hertzum, M., & Frøkjær, E. (1996). Browsing and querying in online
  documentation: A study of user interfaces and the interaction process.
  *ACM Transactions on Computer-Human Interaction*, 3(2), 136–161.
  https://doi.org/10.1145/230562.230570
- Hyönä, J., & Lorch, R. F. (2004). Effects of topic headings on text
  processing: Evidence from adult readers' eye fixation patterns. *Learning
  and Instruction*, 14(2), 131–152.
  https://doi.org/10.1016/j.learninstruc.2004.01.001
- ISO 999:1996. *Information and documentation: Guidelines for the content,
  organization and presentation of indexes.*
- ISO 80000-1:2022. *Quantities and units, Part 1: General.*
- Kalyuga, S., Ayres, P., Chandler, P., & Sweller, J. (2003). The expertise
  reversal effect. *Educational Psychologist*, 38(1), 23–31.
  https://doi.org/10.1207/S15326985EP3801_4
- Katz, M. A., & Byrne, M. D. (2003). Effects of scent and breadth on use of
  site-specific search on e-commerce Web sites. *ACM Transactions on
  Computer-Human Interaction*, 10(3), 198–220.
  https://doi.org/10.1145/937549.937551
- Kim, S. H., & Eastman, C. M. (1999). An experiment on node size in a
  hypermedia system. *Journal of the American Society for Information
  Science*, 50(6), 530–536.
  [doi:10.1002/(SICI)1097-4571(1999)50:6<530::AID-ASI8>3.0.CO;2-U](https://doi.org/10.1002/(SICI)1097-4571(1999)50:6%3C530::AID-ASI8%3E3.0.CO;2-U)
- Kong, Y., Seo, Y. S., & Zhai, L. (2018). Comparison of reading performance
  on screen and on paper: A meta-analysis. *Computers & Education*, 123,
  138–149. https://doi.org/10.1016/j.compedu.2018.05.005
- Legge, G. E., & Bigelow, C. A. (2011). Does print size matter for reading?
  A review of findings from vision science and typography. *Journal of
  Vision*, 11(5):8. https://doi.org/10.1167/11.5.8
- Lorch, R. F. (1989). Text-signaling devices and their effects on reading
  and memory processes. *Educational Psychology Review*, 1(3), 209–234.
  https://doi.org/10.1007/BF01320135
- Madrid, R. I., van Oostendorp, H., & Puerta Melguizo, M. C. (2009). The
  effects of the number of links and navigation support on cognitive load
  and learning with hypertext: The mediating role of reading order.
  *Computers in Human Behavior*, 25(1), 66–75.
  https://doi.org/10.1016/j.chb.2008.06.005
- Maes, A., van Geel, A., & Cozijn, R. (2006). Signposts on the digital
  highway: The effect of semantic and pragmatic hyperlink previews.
  *Interacting with Computers*, 18(2), 265–282.
  https://doi.org/10.1016/j.intcom.2005.05.004
- McNamara, D. S., Kintsch, E., Songer, N. B., & Kintsch, W. (1996). Are
  good texts always better? Interactions of text coherence, background
  knowledge, and levels of understanding in learning from text. *Cognition
  and Instruction*, 14(1), 1–43. https://doi.org/10.1207/s1532690xci1401_1
- Okabe, M., & Ito, K. (2008). *Color Universal Design (CUD): How to make
  figures and presentations that are friendly to colorblind people.* Web
  resource. https://jfly.uni-koeln.de/color/
- Piepenbrock, C., Mayr, S., Mund, I., & Buchner, A. (2013). Positive
  display polarity is advantageous for both younger and older adults.
  *Ergonomics*, 56(7), 1116–1124.
  https://doi.org/10.1080/00140139.2013.790485
- Piolat, A., Roussey, J.-Y., & Thunin, O. (1997). Effects of screen
  presentation on text reading and revising. *International Journal of
  Human-Computer Studies*, 47(4), 565–589.
  https://doi.org/10.1006/ijhc.1997.0145
- Pirolli, P., & Card, S. (1999). Information foraging. *Psychological
  Review*, 106(4), 643–675. https://doi.org/10.1037/0033-295X.106.4.643
- Potelle, H., & Rouet, J.-F. (2003). Effects of content representation and
  readers' prior knowledge on the comprehension of hypertext.
  *International Journal of Human-Computer Studies*, 58(3), 327–345.
  https://doi.org/10.1016/S1071-5819(03)00016-8
- Rello, L., Pielot, M., & Marcos, M.-C. (2016). Make it big! The effect of
  font size and line spacing on online readability. *CHI '16*, 3637–3648.
  https://doi.org/10.1145/2858036.2858204
- Rogers, B. L., & Chaparro, B. (2003). Breadcrumb navigation: Further
  investigation of usage. *Usability News*, 5(2).
  https://portfolio.erau.edu/en/publications/breadcrumb-navigation-further-investigation-of-usage/
- Salmerón, L., Cañas, J. J., Kintsch, W., & Fajardo, I. (2005). Reading
  strategies and hypertext comprehension. *Discourse Processes*, 40(3),
  171–191. https://doi.org/10.1207/s15326950dp4003_1
- Sanchez, C. A., & Wiley, J. (2009). To scroll or not to scroll: Scrolling,
  working memory capacity, and comprehending complex texts. *Human
  Factors*, 51(5), 730–738. https://doi.org/10.1177/0018720809352788
- Schneider, S., Beege, M., Nebel, S., & Rey, G. D. (2018). A meta-analysis
  of how signaling affects learning with media. *Educational Research
  Review*, 23, 1–24. https://doi.org/10.1016/j.edurev.2017.11.001
- Teevan, J., Alvarado, C., Ackerman, M. S., & Karger, D. R. (2004). The
  perfect search engine is not enough: A study of orienteering behavior in
  directed search. *CHI '04*, 415–422. https://doi.org/10.1145/985692.985745
- van der Bles, A. M., van der Linden, S., Freeman, A. L. J., &
  Spiegelhalter, D. J. (2020). The effects of communicating uncertainty on
  public trust in facts and numbers. *PNAS*, 117(14), 7672–7683.
  https://doi.org/10.1073/pnas.1913678117
- W3C (2023). *Web Content Accessibility Guidelines (WCAG) 2.2.*
- Wallace, S., et al. (2022). Towards individuated reading experiences:
  Different fonts increase reading speed for different individuals. *ACM
  Transactions on Computer-Human Interaction*, 29(4), 38.
  https://doi.org/10.1145/3502222
- Wong, B. (2011). Points of view: Color blindness. *Nature Methods*, 8, 441.
  https://doi.org/10.1038/nmeth.1618

## Licence and attribution

The ScienceLogo Documenter is released under the MIT licence, copyright
2026 Riccardo Boero. See [LICENSE](LICENSE).

It builds on the work of others:

- **[ScienceLogo](https://github.com/ScienceLogo/Language)**, the language
  and its reference implementation, the Racket package `sciencelogo` (MIT).
  It is downloaded at first use, not redistributed.
- **[Racket](https://racket-lang.org/)** (MIT or Apache 2.0), downloaded at
  first use, not redistributed.
- **[Typst](https://typst.app/)** (Apache 2.0), which typesets the booklet.
- **Atkinson Hyperlegible Next** and **Atkinson Hyperlegible Mono**, by the
  Braille Institute of America, and **IBM Plex**, by IBM. All are under the
  SIL Open Font License 1.1, and will be bundled with their licence files.
- **The Okabe–Ito colour palette** (Okabe & Ito, 2008).

The defaults rest on the research listed under [References](#references).
If you use the Documenter in published work, please cite this repository:
https://github.com/ScienceLogo/Documenter.
