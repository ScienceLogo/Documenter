#lang racket/base
;; Documentation markers in libraries, and libraries in the documentation.

(require json racket/file racket/port racket/string racket/system rackunit
         "../../src/sciencelogo_documenter/racket/extract.rkt"
         "../../src/sciencelogo_documenter/racket/markers.rkt"
         "../../src/sciencelogo_documenter/racket/structure.rkt")

(define (markers text)
  (define-values (found warnings) (read-doc-markers text))
  (list found warnings))

(test-case "the url marker in a line comment"
  (check-equal? (markers "#lang sciencelogo\n; @doc url: https://example.org/tools/\nlibrary tools []\n")
                (list (make-hash '(("url" . "https://example.org/tools/"))) '())))

(test-case "markers in a block comment, with other hints kept"
  (define-values (found warnings)
    (read-doc-markers "#lang sciencelogo\n#| Tools.\n   @doc url: https://example.org/t\n   @doc logo: tools.png\n|#\nlibrary tools []\n"))
  (check-equal? (hash-ref found "url") "https://example.org/t")
  (check-equal? (hash-ref found "logo") "tools.png")
  (check-equal? warnings '()))

(test-case "the first url marker wins, and duplicates are reported"
  (define-values (found warnings)
    (read-doc-markers "#lang sciencelogo\n;; @doc url: https://one.example\n; @doc url: https://two.example\nlibrary t []\n"))
  (check-equal? (hash-ref found "url") "https://one.example")
  (check-equal? warnings '("more than one @doc url marker; the first one is used")))

(test-case "only the comments at the top count"
  (define-values (found warnings)
    (read-doc-markers "#lang sciencelogo\nlibrary t [\n  ; @doc url: https://late.example\n]\n"))
  (check-equal? (hash-count found) 0))

(test-case "a url marker must hold an http(s) URL"
  (define-values (found warnings) (read-doc-markers "#lang sciencelogo\n; @doc url: tools.html\n"))
  (check-equal? (hash-count found) 0)
  (check-equal? (length warnings) 1))

;; A library in a local Git repository, imported with a file:// URL.
(define (git . args)
  (unless (parameterize ([current-output-port (open-output-nowhere)]
                         [current-error-port (open-output-nowhere)])
            (apply system* (find-executable-path "git") args))
    (error 'git "git ~a failed" args)))

(define (make-library dir marker)
  (make-directory* dir)
  (git "-C" (path->string dir) "init" "-q" "-b" "main")
  (git "-C" (path->string dir) "config" "user.name" "Test")
  (git "-C" (path->string dir) "config" "user.email" "test@example.org")
  (display-to-file
   (string-append "#lang sciencelogo\n" marker
                  "library tools [\n  to double :x [\n    about \"Double a number.\"\n    output :x * 2\n  ]\n]\n")
   (build-path dir "library.rkt"))
  (git "-C" (path->string dir) "add" "library.rkt")
  (git "-C" (path->string dir) "commit" "-q" "-m" "library")
  (git "-C" (path->string dir) "tag" "v1"))

(define (make-workflow dir library)
  (make-directory* dir)
  (git "-C" (path->string dir) "init" "-q")
  (display-to-file
   (string-append
    "#lang sciencelogo\nworkflow \"Uses a library\"\n"
    (format "import \"file://~a\" at \"v1\" as tools\n" (path->string library))
    "performer researcher []\n"
    "stage Compute by researcher from state [information = [x = 2]]\n"
    "  do tools.double with [x at information.x] into information.y\n"
    "end stage with state [information = [x = 2 y = unknown]]\n")
   (build-path dir "workflow.rkt"))
  (build-path dir "workflow.rkt"))

(define (with-library marker proc)
  (define tmp (make-temporary-file "markers-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (make-library (build-path tmp "lib") marker)
      (proc (extract-documentation (make-workflow (build-path tmp "flow") (build-path tmp "lib")))))
    (lambda () (delete-directory/files tmp))))

(test-case "a library with the marker is mapped to its documentation"
  (with-library "; @doc url: https://example.org/tools/\n"
    (lambda (doc)
      (check-equal? (get doc 'libraries)
                    (list (hasheq 'name "tools" 'version "v1" 'url "https://example.org/tools/")))
      (define double (find-named (get doc 'procedures) "tools.double"))
      (check-equal? (get double 'library_url) "https://example.org/tools/")
      (check-equal? (get double 'about) "Double a number.")
      (check-false (get double 'stage))
      (check-equal? (shared-procedures doc) '()))))

(test-case "a library without the marker is neither mapped nor documented"
  (with-library ""
    (lambda (doc)
      (check-equal? (get doc 'libraries) '())
      (check-false (get (find-named (get doc 'procedures) "tools.double") 'library_url))
      (check-equal? (map (lambda (c) (get c 'procedure))
                         (get (car (get doc 'stages)) 'calls))
                    '("tools.double")))))
