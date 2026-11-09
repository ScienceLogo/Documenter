#lang racket/base
;; Renders the documentation model as a static website.
;; Pages follow the method: an overview, one page per stage and per procedure,
;; and a reference page for record types. JavaScript only adds search, link
;; previews and the font switch; every page works without it.

(require racket/file racket/list racket/path racket/string json
         "code.rkt" "diagram.rkt" "markup.rkt" "structure.rkt" "values.rkt")

(provide render-site)

;; ---------------------------------------------------------------------------
;; Pages and link targets

(struct page (key title kind url about crumbs) #:transparent)

(define (render-site doc settings site-dir static-dir fonts-dir)
  (define depth (or (get (or (get settings 'layout) (hasheq)) 'page_depth) 3))
  (define procedure-pages? (>= depth 3))
  (define diagrams? (hash-ref (or (get settings 'layout) (hasheq)) 'diagrams #t))
  (define title (or (get settings 'title) (get doc 'title) "Workflow"))

  (define overview (page '(overview) title "Overview" "index.html" (get doc 'about) '()))
  (define reference
    (and (pair? (get doc 'record_types))
         (page '(reference) "Reference" "Reference" "reference.html"
               "Record types used in the method." '((overview)))))

  ;; Breadcrumbs lead from the overview through the phases that hold an item.
  (define (phase-crumbs item)
    (cons '(overview) (map (lambda (n) (cons 'phase n)) (phase-ancestors doc item))))
  (define (phase-page ph)
    (page (cons 'phase (get ph 'name)) (get ph 'name) "Phase"
          (format "phases/~a.html" (get ph 'slug)) (get ph 'about) (phase-crumbs ph)))
  (define (stage-page s)
    (page (cons 'stage (get s 'name)) (get s 'name) "Stage"
          (format "stages/~a.html" (get s 'slug)) (get s 'about) (phase-crumbs s)))
  (define (procedure-page p)
    (page (cons 'procedure (get p 'name)) (get p 'name) "Procedure"
          (format "procedures/~a.html" (get p 'slug)) (get p 'about)
          (if (get p 'stage)
              (let ([s (find-named (get doc 'stages) (get p 'stage))])
                (append (phase-crumbs s) (list (cons 'stage (get p 'stage)))))
              '((overview) (shared)))))

  ;; Reading order, depth first through phases and stages: the same order as
  ;; the booklet.
  (define (outline-pages node)
    (define name (get node 'name))
    (if (equal? (get node 'kind) "phase")
        (cons (phase-page (find-named (get doc 'phases) name))
              (append* (map outline-pages (get node 'children))))
        (let ([s (find-named (get doc 'stages) name)])
          (cons (stage-page s)
                (if procedure-pages? (map procedure-page (stage-procedures doc s)) '())))))
  (define sequence
    (append
     (list overview)
     (append* (map outline-pages (get doc 'outline)))
     (if procedure-pages? (map procedure-page (shared-procedures doc)) '())
     (if reference (list reference) '())))
  (define page-by-key (for/hash ([p (in-list sequence)]) (values (page-key p) p)))

  ;; Where each item is described, from the site root, and its preview text.
  (define (target kind name)
    (define (slug-of items) (let ([i (find-named items name)]) (and i (get i 'slug))))
    (case kind
      [(stage phase) (let ([p (hash-ref page-by-key (cons kind name) #f)]) (and p (page-url p)))]
      [(procedure)
       (define p (find-named (get doc 'procedures) name))
       (cond
         [(not p) #f]
         [(get p 'library) (get p 'library_url)]
         [procedure-pages? (page-url (hash-ref page-by-key (cons 'procedure name)))]
         [(get p 'stage)
          (format "stages/~a.html#procedure-~a" (slug-of* (get doc 'stages) (get p 'stage)) (get p 'slug))]
         [else (format "index.html#procedure-~a" (get p 'slug))])]
      [(performer) (format "index.html#performer-~a" (slugify* name))]
      [(record) (format "reference.html#record-~a" (slug-of (get doc 'record_types)))]
      [else #f]))
  (define (preview kind name)
    (case kind
      [(stage) (let ([s (find-named (get doc 'stages) name)]) (and s (get s 'about)))]
      [(phase) (let ([ph (find-named (get doc 'phases) name)]) (and ph (get ph 'about)))]
      [(procedure)
       (let ([p (find-named (get doc 'procedures) name)])
         (and p (if (get p 'library)
                    (format "~a (library ~a, version ~a)" (or (get p 'about) name)
                            (get p 'library) (get p 'library_version))
                    (get p 'about))))]
      [(performer)
       (let ([p (find-named (get doc 'performers) name)])
         (and p (string-join (for/list ([f (in-list (get p 'fields))])
                               (format "~a: ~a" (get f 'name) (display->plain (get f 'value))))
                             ", ")))]
      [else #f]))

  ;; ---------------------------------------------------------------------------
  ;; Writing

  (when (directory-exists? site-dir) (delete-directory/files site-dir))
  (make-directory* (build-path site-dir "assets"))
  (copy-directory/files fonts-dir (build-path site-dir "fonts"))
  (copy-file (build-path static-dir "site.js") (build-path site-dir "assets" "site.js"))
  (copy-file (build-path static-dir "sciencelogo.png") (build-path site-dir "assets" "sciencelogo.png"))
  (with-output-to-file (build-path site-dir "assets" "site.css")
    (lambda () (display (site-css settings (file->string (build-path static-dir "site.css"))))))
  (define logo (get (or (get settings 'site) (hasheq)) 'logo))
  (define logo-url
    (and logo
         (let ([name (format "logo~a" (or (path-get-extension logo) #""))])
           (copy-file logo (build-path site-dir "assets" name))
           (format "assets/~a" name))))
;; The favicon: the ScienceLogo one unless the settings name another.
  (define favicon-source
    (or (get (or (get settings 'site) (hasheq)) 'favicon) (build-path static-dir "favicon.svg")))
  (define favicon-url
    (let ([name (format "favicon~a" (or (path-get-extension favicon-source) #".svg"))])
      (copy-file favicon-source (build-path site-dir "assets" name))
      (format "assets/~a" name)))
  (with-output-to-file (build-path site-dir "assets" "search-index.js")
    (lambda () (display (search-index doc sequence target))))

  (for ([p (in-list sequence)] [i (in-naturals)])
    (define previous (and (> i 0) (list-ref sequence (sub1 i))))
    (define next (and (< (add1 i) (length sequence)) (list-ref sequence (add1 i))))
    (define root (if (regexp-match? #rx"/" (page-url p)) "../" ""))
    (define ctx (context root target preview (make-hash)))
    (define kind (car (page-key p)))
    (define item
      (case kind
        [(overview) doc]
        [(phase) (find-named (get doc 'phases) (cdr (page-key p)))]
        [(stage) (find-named (get doc 'stages) (cdr (page-key p)))]
        [(procedure) (find-named (get doc 'procedures) (cdr (page-key p)))]
        [else #f]))
    ;; The page's diagram, right after its summary.
    (define d (and diagrams? item (page-diagram doc kind item)))
    (define fig
      (if d
          (tag 'figure '((class . "diagram-figure"))
               (tag 'div '((class . "diagram-scroll")) (diagram-svg d 'web target root settings))
               (tag 'figcaption '() (esc (diagram-caption d))))
          ""))
    (define body
      (case kind
        [(overview) (overview-body doc ctx procedure-pages? fig)]
        [(phase) (phase-body doc item ctx fig)]
        [(stage) (stage-body doc item ctx procedure-pages? fig)]
        [(procedure) (procedure-body doc item ctx fig)]
        [(reference) (reference-body doc ctx)]))
    (define out (build-path site-dir (page-url p)))
    (make-directory* (path-only out))
    (with-output-to-file out
      (lambda ()
        (display (layout doc p body root title logo-url favicon-url sequence page-by-key previous next
                         procedure-pages?))))))

(define (slug-of* items name)
  (let ([i (find-named items name)]) (if i (get i 'slug) "")))

(define (slugify* name)
  (let* ([s (string-downcase (regexp-replace* #rx"[^A-Za-z0-9]+" name "-"))]
         [s (string-trim s "-")])
    (if (string=? s "") "item" s)))

;; ---------------------------------------------------------------------------
;; Links and categories

;; A rendering context: the path to the site root, the target and preview
;; lookups, and the items already linked in the current section.
(struct context (root target preview seen))

(define (section-start ctx) (hash-clear! (context-seen ctx)))

(define category-class
  (hasheq 'phase "cat-phase" 'stage "cat-stage" 'procedure "cat-procedure" 'performer "cat-performer" 'record "cat-record"))

;; item : context symbol string -> string
;; Names an item in its category style. The first mention in each section is a
;; link, with the target's `about` as its preview.
(define (item ctx kind name)
  (define class (hash-ref category-class kind "cat-other"))
  (define label (if (eq? kind 'procedure) (tag 'code '() (esc name)) (esc name)))
  (define url ((context-target ctx) kind name))
  (define key (cons kind name))
  (cond
    [(and url (not (hash-ref (context-seen ctx) key #f)))
     (hash-set! (context-seen ctx) key #t)
     (define pv ((context-preview ctx) kind name))
     (tag 'a (list (cons 'href (if (regexp-match? #rx"^https?://" url) url (string-append (context-root ctx) url)))
                   (cons 'class class)
                   (cons 'data-preview (and pv (about->plain pv))))
          label)]
    [else (tag 'span (list (cons 'class class)) label)]))

;; ---------------------------------------------------------------------------
;; Values

(define (value-html v)
  (case (get v 'kind)
    [("number")
     (tag 'span '((class . "value"))
          (esc (get v 'text))
          (if (get v 'unit) (string-append "&nbsp;" (tag 'span '((class . "unit")) (esc (get v 'unit)))) ""))]
    [("text") (tag 'span '((class . "text-value")) (esc (format "“~a”" (get v 'text))))]
    [("unknown") (tag 'span '((class . "unknown")) "unknown")]
    [("record")
     (if (null? (get v 'fields))
         (tag 'span '((class . "unknown")) "empty")
         (tag 'dl '((class . "record"))
              (apply string-append
                     (for/list ([f (in-list (get v 'fields))])
                       (string-append (tag 'dt '() (esc (get f 'name)))
                                      (tag 'dd '() (value-html (get f 'value))))))))]
    [("uncertain")
     (string-append (value-html (get v 'value)) " " (uncertainty-html v))]
    [else (tag 'code '() (esc (or (get v 'text) "")))]))

(define (uncertainty-html v)
  (define (sources label items)
    (if (null? items)
        '()
        (list (string-append
               label ": "
               (string-join
                (for/list ([s (in-list items)])
                  (string-append
                   (esc (get s 'name))
                   (if (null? (get s 'fields))
                       ""
                       (string-append
                        " ("
                        (string-join (for/list ([f (in-list (get s 'fields))])
                                       (string-append (esc (get f 'name)) " "
                                                      (inline-value (get f 'value))))
                                     ", ")
                        ")"))))
                "; ")))))
  (tag 'span '((class . "cat-uncertainty"))
       "± "
       (string-join (append (sources "declared" (get v 'declared))
                            (sources "omitted" (get v 'omitted)))
                    "; ")))

(define (inline-value v)
  (case (get v 'kind)
    [("number" "unknown") (value-html v)]
    [("text") (esc (get v 'text))]
    [else (esc (display->plain v))]))

;; Paths whose value differs between two states.
(define (flatten-state v [prefix '()])
  (if (and v (equal? (get v 'kind) "record"))
      (append* (for/list ([f (in-list (get v 'fields))])
                 (flatten-state (get f 'value) (append prefix (list (get f 'name))))))
      (list (cons (string-join prefix ".") (if v (display->plain v) "")))))

(define (state-changes entry exit)
  (define before (make-immutable-hash (flatten-state entry)))
  (for/list ([pair (in-list (flatten-state exit))]
             #:unless (equal? (hash-ref before (car pair) #f) (cdr pair)))
    (cons (car pair) (if (hash-has-key? before (car pair)) "changed" "added"))))

;; ---------------------------------------------------------------------------
;; Page bodies

(define (facts rows)
  (tag 'section '((class . "facts") (aria-label . "Facts"))
       (tag 'dl '()
            (apply string-append
                   (for/list ([r (in-list rows)] #:when (cdr r))
                     (string-append (tag 'dt '() (car r)) (tag 'dd '() (cdr r))))))))

(define (about-block text)
  (if text
      (tag 'div '((class . "about")) (about->html text))
      (tag 'p '((class . "missing-about")) "No summary was given for this item.")))

(define (verbose-block ctx doc text)
  (if (or (not text) (string=? text ""))
      ""
      (tag 'section '((class . "verbose") (aria-label . "Method text"))
           (tag 'h2 '() "Method text")
           (tag 'pre '() (tag 'code '() (mark-code ctx doc text))))))

;; Marks the structure of the method text: structure words, inputs,
;; outputs, and the names of stages, procedures and performers.
(define (mark-code ctx doc text)
  (define names (code-names doc))
  (string-join
   (for/list ([line (in-list (code-lines text names))])
     (apply string-append
            (for/list ([tok (in-list line)])
              (define class (and (car tok) (hash-ref code-classes (car tok))))
              (if class
                  (tag 'span (list (cons 'class class)) (esc (cdr tok)))
                  (esc (cdr tok))))))
   "\n"))

(define code-classes
  (hasheq 'phase "cat-phase" 'stage "cat-stage" 'procedure "cat-procedure" 'performer "cat-performer"
          'keyword "code-keyword" 'input "code-input" 'output "code-output"))

(define (call-html ctx c)
  (string-append
   (item ctx 'procedure (get c 'procedure))
   (if (get c 'performer) (string-append " by " (item ctx 'performer (get c 'performer))) "")
   (if (null? (get c 'inputs))
       ""
       (string-append
        ", with "
        (string-join (for/list ([i (in-list (get c 'inputs))])
                       (string-append (tag 'code '() (esc (get i 'name))) " from "
                                      (tag 'code '() (esc (get i 'location)))))
                     ", ")))
   (if (get c 'into) (string-append ", into " (tag 'code '() (esc (get c 'into)))) "")))

(define (overview-body doc ctx procedure-pages? fig)
  (section-start ctx)
  (define (outline-list nodes)
    (tag 'ul '()
         (apply string-append
                (for/list ([node (in-list nodes)])
                  (define name (get node 'name))
                  (if (equal? (get node 'kind) "phase")
                      (tag 'li '() (item ctx 'phase name) (outline-list (get node 'children)))
                      (let ([s (find-named (get doc 'stages) name)])
                        (tag 'li '()
                             (item ctx 'stage name)
                             (if (get s 'performer) (string-append ", by " (item ctx 'performer (get s 'performer))) "")
                             (let ([ps (stage-procedures doc s)])
                               (if (null? ps)
                                   ""
                                   (tag 'ul '()
                                        (apply string-append
                                               (for/list ([p (in-list ps)])
                                                 (tag 'li '() (item ctx 'procedure (get p 'name)))))))))))))))
  (define outline
    (tag 'div '((class . "method-outline")) (outline-list (get doc 'outline))))
  (section-start ctx)
  (define performers
    (if (null? (get doc 'performers))
        ""
        (tag 'section '()
             (tag 'h2 '() "Performers")
             (tag 'dl '((class . "performers"))
                  (apply string-append
                         (for/list ([p (in-list (get doc 'performers))])
                           (string-append
                            (tag 'dt (list (cons 'id (format "performer-~a" (slugify* (get p 'name)))))
                                 (tag 'span '((class . "cat-performer")) (esc (get p 'name))))
                            (tag 'dd '()
                                 (string-join (for/list ([f (in-list (get p 'fields))])
                                                (string-append (esc (get f 'name)) ": " (inline-value (get f 'value))))
                                              "; ")
                                 (if (null? (get p 'stages))
                                     ""
                                     (string-append
                                      ". Stages: "
                                      (string-join (map (lambda (n) (item ctx 'stage n)) (get p 'stages)) ", ")))))))))))
  (section-start ctx)
  (define propositions
    (apply string-append
           (for/list ([kind (in-list '("hypothesis" "assumption" "conclusion"))]
                      [heading (in-list '("Hypotheses" "Assumptions" "Conclusions"))])
             (define items (filter (lambda (p) (equal? (get p 'kind) kind)) (get doc 'propositions)))
             (if (null? items)
                 ""
                 (tag 'section '()
                      (tag 'h2 '() heading)
                      (tag 'dl '()
                           (apply string-append
                                  (for/list ([p (in-list items)])
                                    (string-append
                                     (tag 'dt (list (cons 'id (format "~a-~a" kind (slugify* (get p 'name)))))
                                          (esc (get p 'name)))
                                     (tag 'dd '() (esc (or (get p 'text) ""))))))))))))
  (section-start ctx)
  (define requirements
    (if (null? (get doc 'requirements))
        ""
        (tag 'section '()
             (tag 'h2 '() "Requirements")
             (tag 'ul '()
                  (apply string-append
                         (for/list ([r (in-list (get doc 'requirements))])
                           (tag 'li '() (requirement-html ctx r))))))))
  (section-start ctx)
  (define shared
    (if (or procedure-pages? (null? (shared-procedures doc)))
        ""
        (tag 'section '()
             (tag 'h2 '() "Shared procedures")
             (apply string-append (map (lambda (p) (procedure-block doc ctx p)) (shared-procedures doc))))))
  (define libraries
    (if (null? (get doc 'libraries))
        ""
        (tag 'section '()
             (tag 'h2 '() "Libraries")
             (tag 'ul '()
                  (apply string-append
                         (for/list ([l (in-list (get doc 'libraries))])
                           (tag 'li '() (esc (get l 'name))
                                (if (string=? (get l 'version) "") "" (string-append ", version " (esc (get l 'version))))
                                (if (get l 'language) (string-append ", for ScienceLogo " (esc (get l 'language))) "")
                                (if (get l 'url)
                                    (string-append ": " (tag 'a (list (cons 'href (get l 'url))) "documentation"))
                                    ""))))))))
  (string-append
   (about-block (get doc 'about))
   fig
   (tag 'section '() (tag 'h2 '() "Method") outline)
   performers propositions requirements shared libraries))

(define (requirement-html ctx r)
  (define targets (get r 'targets))
  (case (get r 'kind)
    [("stage-order")
     (string-append "Stages run in this order: "
                    (string-join (map (lambda (n) (item ctx 'stage n)) targets) " → ") ".")]
    [else
     (string-append (esc (get r 'kind)) ": "
                    (string-join (map (lambda (n) (tag 'code '() (esc n))) targets) ", "))]))

(define (procedure-block doc ctx p)
  (tag 'section (list (cons 'class "procedure-block") (cons 'id (format "procedure-~a" (get p 'slug))))
       (tag 'h3 '() (tag 'code '((class . "cat-procedure")) (esc (get p 'name))))
       (about-block (get p 'about))
       (facts (list (cons "Inputs" (if (null? (get p 'inputs)) #f
                                       (string-join (map (lambda (i) (tag 'code '() (esc i))) (get p 'inputs)) ", ")))))
       (verbose-block ctx doc (get p 'verbose))))

(define (phase-body doc ph ctx fig)
  (section-start ctx)
  (string-append
   (about-block (get ph 'about))
   fig
   (facts
    (list
     (cons "Contains"
           (tag 'ul '()
                (apply string-append
                       (for/list ([m (in-list (get ph 'members))])
                         (define kind (string->symbol (get m 'kind)))
                         (define about ((context-preview ctx) kind (get m 'name)))
                         (tag 'li '() (item ctx kind (get m 'name))
                              (if about (string-append ": " (esc (about->plain about))) ""))))))))
   (verbose-block ctx doc (get ph 'verbose))))

(define (stage-body doc s ctx procedure-pages? fig)
  (section-start ctx)
  (define changes (if (get s 'paired) (state-changes (get s 'entry) (get s 'exit)) '()))
  (define calls (get s 'calls))
  (define fact-block
    (facts
     (list
      (cons "Performer" (and (get s 'performer) (item ctx 'performer (get s 'performer))))
      (cons "Starts with" (and (get s 'entry) (value-html (get s 'entry))))
      (cons "Steps"
            (and (pair? calls)
                 (tag 'ol '() (apply string-append (for/list ([c (in-list calls)]) (tag 'li '() (call-html ctx c)))))))
      (cons "Changes"
            (and (pair? changes)
                 (tag 'ul '()
                      (apply string-append
                             (for/list ([c (in-list changes)])
                               (tag 'li '() (tag 'code '() (esc (car c))) " " (cdr c)))))))
      (cons "Ends with" (and (get s 'exit) (value-html (get s 'exit)))))))
  (section-start ctx)
  (define used
    (remove-duplicates (map (lambda (c) (get c 'procedure)) calls)))
  (define used-blocks
    (if (null? used)
        ""
        (tag 'section '((class . "procedures-used"))
             (tag 'h2 '() "Procedures used")
             (apply string-append
                    (for/list ([name (in-list used)])
                      (define p (find-named (get doc 'procedures) name))
                      (cond
                        [(and p (not procedure-pages?) (equal? (get p 'stage) (get s 'name)))
                         (procedure-block doc ctx p)]
                        [p
                         (tag 'div '((class . "procedure-summary"))
                              (tag 'h3 '() (item ctx 'procedure name))
                              (if (get p 'about) (about->html (get p 'about)) "")
                              (if (get p 'library)
                                  (tag 'p '() "From the library " (esc (get p 'library))
                                       ", version " (esc (get p 'library_version)) ".")
                                  "")
                              (if (null? (get p 'inputs)) ""
                                  (tag 'p '() "Inputs: "
                                       (string-join (map (lambda (i) (tag 'code '() (esc i))) (get p 'inputs)) ", "))))]
                        [else (tag 'p '() (tag 'code '() (esc name)))]))))))
  (string-append (about-block (get s 'about)) fig fact-block used-blocks
                 (verbose-block ctx doc (get s 'verbose))))

(define (procedure-body doc p ctx fig)
  (section-start ctx)
  (define uses
    (append*
     (for/list ([s (in-list (get doc 'stages))])
       (for/list ([c (in-list (get s 'calls))] #:when (equal? (get c 'procedure) (get p 'name)))
         (string-append (item ctx 'stage (get s 'name)) ": " (call-html ctx c))))))
  (string-append
   (about-block (get p 'about))
   fig
   (facts
    (list
     (cons "Inputs" (if (null? (get p 'inputs)) #f
                        (string-join (map (lambda (i) (tag 'code '() (esc i))) (get p 'inputs)) ", ")))
     (cons "Called by"
           (if (null? (get p 'called_by)) #f
               (string-join (for/list ([c (in-list (get p 'called_by))])
                              (item ctx (string->symbol (get c 'kind)) (get c 'name)))
                            ", ")))
     (cons "Calls" (if (null? (get p 'calls)) #f
                       (string-join (map (lambda (n) (item ctx 'procedure n)) (get p 'calls)) ", ")))
     (cons "Used in" (if (null? uses) #f
                         (tag 'ul '() (apply string-append (map (lambda (u) (tag 'li '() u)) uses)))))))
   (verbose-block ctx doc (get p 'verbose))))

(define (reference-body doc ctx)
  (apply string-append
         (for/list ([r (in-list (get doc 'record_types))])
           (section-start ctx)
           (tag 'section (list (cons 'id (format "record-~a" (get r 'slug))))
                (tag 'h2 '() (tag 'span '((class . "cat-record")) (esc (get r 'name)))
                     (if (get r 'version) (string-append " " (tag 'small '() "version " (esc (get r 'version)))) ""))
                (if (null? (get r 'fields))
                    ""
                    (tag 'table '()
                         (tag 'thead '() (tag 'tr '() (tag 'th '() "Field") (tag 'th '() "Kind")
                                              (tag 'th '() "Default") (tag 'th '() "Required")))
                         (tag 'tbody '()
                              (apply string-append
                                     (for/list ([f (in-list (get r 'fields))])
                                       (tag 'tr '()
                                            (tag 'td '() (tag 'code '() (esc (get f 'name))))
                                            (tag 'td '() (esc (or (get f 'type) "")))
                                            (tag 'td '() (esc (or (get f 'default) "")))
                                            (tag 'td '() (if (get f 'required) "yes" "no"))))))))
                (verbose-block ctx doc (get r 'verbose))))))

;; ---------------------------------------------------------------------------
;; Frame: header, outline, breadcrumbs and sequence links

(define (layout doc p body root title logo-url favicon-url sequence page-by-key previous next procedure-pages?)
  (define (href q) (string-append root (page-url q)))
  (define (outline-link q)
    (define current? (equal? (page-key q) (page-key p)))
    (define class (case (car (page-key q))
                    [(phase) "cat-phase"] [(stage) "cat-stage"] [(procedure) "cat-procedure"] [else #f]))
    (tag 'a (list (cons 'href (href q)) (cons 'class class) (cons 'aria-current (and current? "page")))
         (if (eq? (car (page-key q)) 'procedure) (tag 'code '() (esc (page-title q))) (esc (page-title q)))))
  (define (outline-node node)
    (define name (get node 'name))
    (if (equal? (get node 'kind) "phase")
        (tag 'li '()
             (outline-link (hash-ref page-by-key (cons 'phase name)))
             (tag 'ul '() (apply string-append (map outline-node (get node 'children)))))
        (let ([ps (if procedure-pages? (stage-procedures doc (find-named (get doc 'stages) name)) '())])
          (tag 'li '()
               (outline-link (hash-ref page-by-key (cons 'stage name)))
               (if (null? ps) ""
                   (tag 'ul '()
                        (apply string-append
                               (for/list ([pr (in-list ps)])
                                 (tag 'li '() (outline-link (hash-ref page-by-key (cons 'procedure (get pr 'name)))))))))))))
  (define outline
    (tag 'nav '((class . "outline") (aria-label . "Method outline"))
         (tag 'ul '()
              (tag 'li '()
                   (outline-link (hash-ref page-by-key '(overview)))
                   (tag 'ul '()
                        (apply string-append (map outline-node (get doc 'outline)))
                        (let ([shared (if procedure-pages? (shared-procedures doc) '())])
                          (if (null? shared) ""
                              (tag 'li '() (tag 'span '() "Shared procedures")
                                   (tag 'ul '()
                                        (apply string-append
                                               (for/list ([pr (in-list shared)])
                                                 (tag 'li '() (outline-link (hash-ref page-by-key (cons 'procedure (get pr 'name)))))))))))
                        (let ([r (hash-ref page-by-key '(reference) #f)])
                          (if r (tag 'li '() (outline-link r)) "")))))))
  (define crumbs
    (if (null? (page-crumbs p))
        ""
        (tag 'nav '((class . "breadcrumbs") (aria-label . "Breadcrumbs"))
             (tag 'ol '()
                  (apply string-append
                         (for/list ([k (in-list (page-crumbs p))])
                           (define q (hash-ref page-by-key k #f))
                           (tag 'li '() (if q (tag 'a (list (cons 'href (href q))) (esc (page-title q)))
                                            "Shared procedures"))))
                  (tag 'li '((aria-current . "page")) (esc (page-title p)))))))
  (define seq
    (tag 'nav '((class . "sequence") (aria-label . "Reading order"))
         (cond
           [previous
            (tag 'a (list (cons 'href (href previous)) (cons 'rel "prev"))
                 (tag 'span '((class . "direction")) "Previous") (esc (page-title previous)))]
           ;; Said once, on the overview, where there is no previous page:
           ;; the language the method is written in.
           [(equal? (page-key p) '(overview))
            (tag 'p '((class . "language-note"))
                 (tag 'img (list (cons 'src (string-append root "assets/sciencelogo.png"))
                                 (cons 'alt "")))
                 (tag 'span '()
                      "This method is written in "
                      (tag 'a (list (cons 'href "https://sciencelogo.org/")) "ScienceLogo")
                      "."))]
           [else ""])
         (if next
             (tag 'a (list (cons 'href (href next)) (cons 'rel "next") (cons 'class "next"))
                  (tag 'span '((class . "direction")) "Next") (esc (page-title next)))
             "")))
  (define heading
    (case (car (page-key p))
      [(phase) (tag 'span '((class . "cat-phase")) (esc (page-title p)))]
      [(stage) (tag 'span '((class . "cat-stage")) (esc (page-title p)))]
      [(procedure) (tag 'code '((class . "cat-procedure")) (esc (page-title p)))]
      [else (esc (page-title p))]))
  (string-append
   "<!doctype html>\n"
   (tag 'html '((lang . "en"))
        (tag 'head '()
             (tag 'meta '((charset . "utf-8")))
             (tag 'meta '((name . "viewport") (content . "width=device-width, initial-scale=1")))
             (tag 'title '() (esc (if (equal? (page-key p) '(overview)) title
                                      (format "~a – ~a" (page-title p) title))))
             (tag 'link (list (cons 'rel "icon") (cons 'href (string-append root favicon-url))
                              (cons 'type (and (regexp-match? #rx"[.]svg$" favicon-url) "image/svg+xml"))))
             (tag 'link (list (cons 'rel "stylesheet") (cons 'href (string-append root "assets/site.css"))))
             (tag 'script (list (cons 'defer "") (cons 'src (string-append root "assets/search-index.js"))))
             (tag 'script (list (cons 'defer "") (cons 'src (string-append root "assets/site.js")))))
        (tag 'body (list (cons 'data-root root))
             (tag 'a '((class . "skip") (href . "#main")) "Skip to content")
             (tag 'header '((class . "site-header"))
                  (tag 'a (list (cons 'class "site-title") (cons 'href (string-append root "index.html")))
                       (if logo-url (tag 'img (list (cons 'src (string-append root logo-url)) (cons 'alt ""))) "")
                       (esc title))
                  (tag 'div '((class . "tools")) "")
                  (tag 'a (list (cons 'class "booklet-link") (cons 'href (string-append root "booklet.pdf")))
                       "Booklet (PDF)"))
             (tag 'div '((class . "layout"))
                  outline
                  (tag 'main '((id . "main"))
                       (tag 'p '((class . "kind")) (esc (page-kind p)))
                       (tag 'h1 '() heading)
                       crumbs
                       body
                       seq))))))

;; ---------------------------------------------------------------------------
;; Style and search

(define (site-css settings base)
  (define colours (or (get settings 'colours) (hasheq)))
  (define (block mode)
    (define c (or (get colours mode) (hasheq)))
    (define cats (or (get (or (get colours 'categories) (hasheq)) mode) (hasheq)))
    (string-append
     (apply string-append
            (for/list ([(k v) (in-hash c)])
              (format "  --~a: ~a;\n" (string-replace (symbol->string k) "_" "-") v)))
     (apply string-append
            (for/list ([(k v) (in-hash cats)])
              (format "  --cat-~a: ~a;\n" (string-replace (symbol->string k) "_" "-") v)))))
  (define fonts (or (get settings 'fonts) (hasheq)))
  (define faces
    (apply string-append
           (for/list ([f (in-list (or (get fonts 'faces) '()))])
             (format "@font-face { font-family: \"~a\"; src: url(\"../~a\"); font-weight: ~a; font-style: ~a; font-display: swap; }\n"
                     (get f 'family) (get f 'url) (or (get f 'weight) 400) (or (get f 'style) "normal")))))
  (string-append
   faces
   ":root {\n"
   (format "  --font-text: \"~a\", \"Atkinson Hyperlegible Next\", system-ui, sans-serif;\n"
           (or (get fonts 'text) "Atkinson Hyperlegible Next"))
   (format "  --font-code: \"~a\", \"Atkinson Hyperlegible Mono\", ui-monospace, monospace;\n"
           (or (get fonts 'code) "Atkinson Hyperlegible Mono"))
   (block 'light)
   "}\n"
   "@media (prefers-color-scheme: dark) {\n:root {\n" (block 'dark) "}\n}\n"
   base))

(define (search-index doc sequence target)
  (define (entry title kind url about text)
    (hasheq 't title 'k kind 'u url 'a (if about (about->plain about) "") 'x (or text "")))
  (define entries
    (append
     (for/list ([p (in-list sequence)])
       (define key (page-key p))
       (define text
         (case (car key)
           [(phase) (get (find-named (get doc 'phases) (cdr key)) 'verbose)]
           [(stage) (get (find-named (get doc 'stages) (cdr key)) 'verbose)]
           [(procedure) (get (find-named (get doc 'procedures) (cdr key)) 'verbose)]
           [else ""]))
       (entry (page-title p) (page-kind p) (page-url p) (page-about p) text))
     (for/list ([p (in-list (get doc 'performers))])
       (entry (get p 'name) "Performer" (target 'performer (get p 'name)) #f (get p 'verbose)))
     (for/list ([p (in-list (get doc 'propositions))])
       (entry (get p 'name) (string-titlecase (get p 'kind))
              (format "index.html#~a-~a" (get p 'kind) (slugify* (get p 'name)))
              (get p 'text) (get p 'verbose)))
     (for/list ([r (in-list (get doc 'record_types))])
       (entry (get r 'name) "Record type" (target 'record (get r 'name)) #f (get r 'verbose)))))
  (string-append "window.SL_SEARCH = " (jsexpr->string entries) ";\n"))
