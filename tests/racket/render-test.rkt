#lang racket/base
;; The website and the booklet source of the example workflow.

(require racket/file racket/path racket/port racket/runtime-path racket/string rackunit
         "../../src/sciencelogo_documenter/racket/extract.rkt"
         "../../src/sciencelogo_documenter/racket/html.rkt"
         "../../src/sciencelogo_documenter/racket/typst.rkt")

(define-runtime-path example "../../examples/pendulum/workflow.rkt")
(define-runtime-path package "../../src/sciencelogo_documenter")

(define doc (extract-documentation example))
(define settings (hasheq 'layout (hasheq 'page_depth 3)))
(define site (make-temporary-file "site-~a" 'directory))
(render-site doc settings site (build-path package "static") (build-path package "fonts"))
(define (page p) (file->string (build-path site p)))

(test-case "one page per stage and per procedure, an overview and a reference"
  (for ([p '("index.html" "reference.html" "phases/measurement.html" "phases/analysis.html"
             "stages/prepare.html" "stages/observe.html"
             "stages/compare.html" "stages/revise.html"
             "procedures/calculate-period.html" "procedures/compare-periods.html"
             "assets/site.css" "assets/site.js" "assets/search-index.js" "assets/favicon.svg")])
    (check-true (file-exists? (build-path site p)) p)))

(test-case "a page opens with the title, breadcrumbs and about, in that order"
  (define html (page "stages/observe.html"))
  (define (at s) (car (car (regexp-match-positions (regexp-quote s) html))))
  (check-true (< (at "<h1>") (at "class=\"breadcrumbs\"") (at "class=\"about\"")
                 (at "class=\"facts\"") (at "Method text"))))

(test-case "breadcrumbs and the reading order go through the phases"
  (define html (page "procedures/calculate-period.html"))
  (check-true (string-contains? html "<li><a href=\"../phases/measurement.html\">Measurement</a></li><li><a href=\"../stages/observe.html\">Observe</a></li>"))
  (check-true (string-contains? (page "phases/measurement.html") "href=\"../stages/prepare.html\" rel=\"next\"")))

(test-case "navigation: outline with the current page, and the reading order"
  (define html (page "stages/compare.html"))
  (check-true (string-contains? html "href=\"../stages/compare.html\" class=\"cat-stage\" aria-current=\"page\""))
  (check-true (string-contains? html "rel=\"prev\""))
  (check-true (string-contains? html "href=\"../procedures/compare-periods.html\" rel=\"next\"")))

(test-case "the overview, and only the overview, names the language"
  (check-true (string-contains? (page "index.html") "This method is written in <a href=\"https://sciencelogo.org/\">ScienceLogo</a>"))
  (check-true (file-exists? (build-path site "assets" "sciencelogo.png")))
  (check-false (string-contains? (page "stages/observe.html") "language-note")))

(test-case "a page shows its diagram after its summary"
  (define html (page "stages/observe.html"))
  (define (at s) (car (car (regexp-match-positions (regexp-quote s) html))))
  (check-true (< (at "class=\"about\"") (at "<figure class=\"diagram-figure\">") (at "class=\"facts\"")))
  (check-true (string-contains? html "<figcaption>Diagram of the stage Observe</figcaption>"))
  ;; The calls link to their procedures, and the frame shows what the stage reads and writes.
  (check-true (string-contains? html "<a href=\"../procedures/calculate-period.html\">"))
  (check-true (string-contains? html ">large-swing.elapsed</text>"))
  (check-true (string-contains? html ">large-swing.period</text>"))
  ;; Text, lines and boxes take the page's palette, in light and dark mode.
  (check-false (regexp-match? #rx"<text [^>]*fill=\"#" html))
  (check-true (regexp-match? #rx"<text [^>]*fill=\"currentColor\"" html))
  ;; A stage without steps has no diagram.
  (check-false (string-contains? (page "stages/revise.html") "<svg")))

(test-case "diagrams can be turned off"
  (define site2 (make-temporary-file "site-~a" 'directory))
  (render-site doc (hasheq 'layout (hasheq 'page_depth 3 'diagrams #f)) site2
               (build-path package "static") (build-path package "fonts"))
  (check-false (string-contains? (file->string (build-path site2 "stages" "observe.html")) "<svg"))
  (delete-directory/files site2))

(test-case "the booklet places the same diagrams, as files next to its source"
  (define work (make-temporary-file "work-~a" 'directory))
  (define typ (with-output-to-string (lambda () (write-booklet doc settings (current-output-port) work))))
  (check-true (string-contains? typ "#diagram(\"diagram-stage-observe.svg\", \"Diagram of the stage Observe\")"))
  (check-true (file-exists? (build-path work "diagram-stage-observe.svg")))
  (check-true (string-contains? (file->string (build-path work "diagram-stage-observe.svg"))
                                "font-family=\"Atkinson Hyperlegible Next\""))
  (delete-directory/files work))

(test-case "pages use the ScienceLogo favicon"
  (check-true (string-contains? (page "stages/observe.html")
                                "<link rel=\"icon\" href=\"../assets/favicon.svg\" type=\"image/svg+xml\">")))

(test-case "links carry the target's about as a preview"
  (check-true (string-contains? (page "stages/observe.html")
                                "data-preview=\"Divide the elapsed time by the number of full swings.\"")))

(test-case "the site links the booklet and holds no file paths"
  (check-true (string-contains? (page "index.html") "booklet.pdf"))
  (for ([f (in-directory site)] #:when (regexp-match? #rx"[.](html|js)$" (path->string f)))
    (define text (file->string f))
    (check-false (string-contains? text ".rkt") (path->string f))))

(test-case "the booklet source has labels, page references and the index"
  (define typ (with-output-to-string (lambda () (write-booklet doc settings (current-output-port)))))
  (check-true (string-contains? typ "<stage-observe>"))
  (check-true (string-contains? typ "item-ref(\"procedure-calculate-period\""))
  (check-true (string-contains? typ "#analytical-index("))
  (check-false (string-contains? typ ".rkt")))

(delete-directory/files site)
