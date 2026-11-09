// Standard style of the ScienceLogo Documenter booklet.
// booklet.typ, written for each workflow, imports this file.

#let sl-colours = state("sl-colours", (
  stage: rgb("#0072B2"),
  performer: rgb("#E69F00"),
  procedure: rgb("#009E73"),
  uncertainty: rgb("#D55E00"),
))

#let booklet(
  title: "",
  paper: "a4",
  body-size: 10.5pt,
  text-font: "Atkinson Hyperlegible Next",
  code-font: "Atkinson Hyperlegible Mono",
  colours: (:),
  body,
) = {
  set document(title: title)
  set page(
    paper: paper,
    margin: (x: 2.2cm, top: 2.6cm, bottom: 2.4cm),
    header: context {
      let p = here().page()
      if p <= 1 { return }
      let starts = query(heading.where(level: 1)).filter(h => h.location().page() == p)
      if starts.len() > 0 { return }
      let before = query(heading.where(level: 1).before(here()))
      if before.len() > 0 {
        set text(size: 0.85em)
        emph(before.last().body)
        v(-0.6em)
        line(length: 100%, stroke: 0.4pt)
      }
    },
    footer: context {
      if here().page() > 1 { align(center, text(size: 0.9em, counter(page).display())) }
    },
  )
  set text(font: (text-font, "Atkinson Hyperlegible Next"), size: body-size, lang: "en")
  set par(leading: 0.7em, spacing: 1.1em)
  show raw: set text(font: (code-font, "Atkinson Hyperlegible Mono"), size: 0.92em)
  show link: it => it
  set heading(numbering: "1.1")
  // Chapters start on a new page: booklet.typ breaks the page before each
  // chapter, so that a label above the heading stays with it.
  show heading.where(level: 1): it => {
    v(0.5em)
    block(text(size: 1.7em, it))
    v(0.6em)
  }
  show heading.where(level: 2): it => block(above: 1.8em, below: 0.8em, text(size: 1.25em, it))
  sl-colours.update(c => c + colours)
  body
}

#let title-page(title: "", about: (), logo: none) = {
  set page(header: none, footer: none)
  v(18%)
  if logo != none { image(logo, height: 2.5cm); v(1cm) }
  text(size: 2.4em, weight: "bold", title)
  v(1.2em)
  for p in about { par(text(size: 1.15em, p)) }
  // The language the method is written in, at the foot of the title page.
  v(1fr)
  grid(
    columns: (auto, 1fr),
    column-gutter: 0.8em,
    align: horizon,
    image("sciencelogo.png", height: 1.1cm),
    text(size: 0.9em)[This method is written in ScienceLogo: #link("https://sciencelogo.org/")],
  )
  pagebreak()
}

#let contents() = {
  outline(title: "Contents", depth: 3, indent: auto)
}

// Index entries: kind, name, and whether this is where the item is defined.
#let idx(kind, name, def: false, sub: ()) = [#metadata((kind: kind, name: name, def: def, sub: sub)) <sl-index>]

#let kind-label(kind) = block(below: 0.2em, text(size: 0.9em, tracking: 0.05em, upper(kind)))

// Categories: the type style carries the meaning; colour is a second cue.
#let marked(colour-key, body) = context {
  let c = sl-colours.get().at(colour-key)
  underline(stroke: 1.5pt + c, offset: 2.5pt, evade: false, body)
}
#let phase-name(name) = text(weight: "bold", tracking: 0.04em, upper(name))
#let stage-name(name) = marked("stage", text(weight: "bold", smallcaps(name)))
#let performer-name(name) = marked("performer", emph(name))
#let procedure-name(name) = marked("procedure", raw(name))
#let uncertainty(body) = context {
  let c = sl-colours.get().at("uncertainty")
  underline(stroke: (paint: c, thickness: 1pt, dash: "dotted"), offset: 2.5pt, body)
}

#let styled(kind, name) = {
  if kind == "Phases" { phase-name(name) }
  else if kind == "Stages" { stage-name(name) }
  else if kind == "Procedures" { procedure-name(name) }
  else if kind == "Performers" { performer-name(name) }
  else if kind == "Record types" { strong(name) }
  else { name }
}

// A named reference to an item, with its page number for readers on paper.
#let item-ref(target, kind, name) = {
  idx(kind, name)
  link(label(target), styled(kind, name))
  context [~(p.~#counter(page).at(label(target)).first())]
}

#let anchor(target) = [#metadata("anchor") #label(target)]

#let about-text(paragraphs) = {
  if paragraphs.len() == 0 {
    par(emph[No summary was given for this item.])
  } else {
    for p in paragraphs { par(p) }
  }
}

#let facts(rows) = {
  if rows.len() == 0 { return }
  block(above: 1em, below: 1em, grid(
    columns: (auto, 1fr),
    column-gutter: 1em,
    row-gutter: 0.7em,
    ..rows.map(r => (strong(r.at(0)), r.at(1))).flatten(),
  ))
}

#let state-lines(lines) = {
  for l in lines {
    pad(left: l.at(0) * 1em, block(above: 0.25em, below: 0.25em, l.at(1)))
  }
}

// The method text, with its structure marked: structure words in bold,
// inputs with a dashed underline, outputs in italics with a solid underline,
// and the names of stages, procedures and performers in their categories.
#let code-token(class, s) = {
  let r = raw(s)
  if class == "keyword" { text(weight: "bold", r) }
  else if class == "input" { underline(stroke: (thickness: 0.6pt, dash: "dashed"), offset: 2pt, r) }
  else if class == "output" { underline(stroke: 0.6pt, offset: 2pt, emph(r)) }
  else if class == "phase" { text(weight: "bold", r) }
  else if class == "stage" { marked("stage", r) }
  else if class == "procedure" { marked("procedure", r) }
  else if class == "performer" { marked("performer", r) }
  else { r }
}

#let method-code(lines) = {
  block(
    width: 100%,
    fill: luma(245),
    inset: 0.8em,
    radius: 3pt,
    breakable: true,
    {
      set par(leading: 0.55em, justify: false)
      for (i, line) in lines.enumerate() {
        if i > 0 { linebreak() }
        for t in line { code-token(t.at(0), t.at(1)) }
      }
    },
  )
}

#let method-text(code) = {
  block(
    width: 100%,
    fill: luma(245),
    inset: 0.8em,
    radius: 3pt,
    breakable: true,
    raw(code, block: true),
  )
}

#let analytical-index(kinds) = {
  pagebreak(weak: true)
  heading(level: 1, numbering: none)[Index]
  context {
    let entries = query(<sl-index>)
    for kind in kinds {
      let items = entries.filter(e => e.value.kind == kind)
      if items.len() == 0 { continue }
      heading(level: 2, numbering: none, outlined: false, kind)
      let names = items.map(e => e.value.name).dedup().sorted(key: n => lower(n))
      for n in names {
        let hits = items.filter(e => e.value.name == n)
        let pages = ()
        let subs = ()
        for h in hits {
          let pg = counter(page).at(h.location()).first()
          let i = pages.position(p => p.page == pg)
          if i == none {
            pages.push((page: pg, loc: h.location(), def: h.value.def))
          } else if h.value.def {
            pages.at(i) = (page: pg, loc: h.location(), def: true)
          }
          if h.value.def { subs = h.value.sub }
        }
        pages = pages.sorted(key: p => p.page)
        let numbers = pages.map(p => link(p.loc, if p.def { strong(str(p.page)) } else { str(p.page) }))
        block(above: 0.45em, below: 0.45em, [#styled(kind, n) #h(0.6em) #numbers.join(", ")])
        for s in subs {
          pad(left: 1.5em, block(above: 0.3em, below: 0.3em, [#raw(s) #h(0.6em) #numbers.join(", ")]))
        }
      }
    }
  }
}
