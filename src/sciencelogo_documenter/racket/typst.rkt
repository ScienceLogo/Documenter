#lang racket/base
;; Writes the Typst source of the booklet. Typst lays it out and resolves the
;; page numbers of the table of contents, the page references and the index.

(require racket/list racket/string
         "code.rkt" "diagram.rkt" "markup.rkt" "structure.rkt" "values.rkt")

(provide write-booklet)

;; A Typst string literal.
(define (ts s)
  (string-append
   "\""
   (let* ([s (string-replace s "\\" "\\\\")]
          [s (string-replace s "\"" "\\\"")]
          [s (string-replace s "\n" "\\n")]
          [s (string-replace s "\r" "")])
     s)
   "\""))

;; Content made from plain text.
(define (tc s) (string-append "[#" (ts s) "]"))

(define (tarray items) (string-append "(" (string-join items ", ") (if (= 1 (length items)) "," "") ")"))

(define (slug s)
  (let* ([s (string-downcase (regexp-replace* #rx"[^A-Za-z0-9]+" s "-"))]
         [s (string-trim s "-")])
    (if (string=? s "") "item" s)))

(define (paragraphs text)
  (if text
      (tarray (for/list ([p (in-list (regexp-split #rx"\n\n" text))]
                         #:unless (string=? (string-trim p) ""))
                (ts (about->plain p))))
      "()"))

;; write-booklet : doc settings output-port -> void
(define (write-booklet doc settings out [work-dir #f])
  (define booklet (or (get settings 'booklet) (hasheq)))
  (define fonts (or (get settings 'fonts) (hasheq)))
  (define colours (or (get settings 'colours) (hasheq)))
  (define categories (or (get (or (get colours 'categories) (hasheq)) 'light) (hasheq)))
  (define index-kinds
    (or (get (or (get settings 'index) (hasheq)) 'kinds)
        '("Phases" "Stages" "Procedures" "Performers" "Record types" "Requirements")))
  (define title (or (get settings 'title) (get doc 'title) "Workflow"))
  (define (emit . parts) (for ([p (in-list parts)]) (write-string p out)) (newline out))

  ;; Labels exist only for items the booklet describes.
  (define labels (make-hash))
  (for ([ph (in-list (get doc 'phases))]) (hash-set! labels (cons 'phase (get ph 'name)) (format "phase-~a" (get ph 'slug))))
  (for ([s (in-list (get doc 'stages))]) (hash-set! labels (cons 'stage (get s 'name)) (format "stage-~a" (get s 'slug))))
  (for ([p (in-list (get doc 'procedures))] #:unless (get p 'library))
    (hash-set! labels (cons 'procedure (get p 'name)) (format "procedure-~a" (get p 'slug))))
  (for ([p (in-list (get doc 'performers))]) (hash-set! labels (cons 'performer (get p 'name)) (format "performer-~a" (slug (get p 'name)))))
  (for ([r (in-list (get doc 'record_types))]) (hash-set! labels (cons 'record (get r 'name)) (format "record-~a" (get r 'slug))))
  (define kind-name (hasheq 'phase "Phases" 'stage "Stages" 'procedure "Procedures" 'performer "Performers" 'record "Record types"))
  (define (ref kind name)
    (define l (hash-ref labels (cons kind name) #f))
    (if l
        (format "item-ref(~a, ~a, ~a)" (ts l) (ts (hash-ref kind-name kind)) (ts name))
        (format "styled(~a, ~a)" (ts (hash-ref kind-name kind)) (ts name))))
  (define (code s) (format "raw(~a)" (ts s)))
  (define (join-content items sep)
    (if (null? items) "[]" (string-append "[" (string-join (map (lambda (i) (string-append "#" i)) items) sep) "]")))

  (define (value-text v)
    (case (get v 'kind)
      [("uncertain")
       (string-append (value-text (get v 'value)) " ± "
                      (string-join
                       (append
                        (for/list ([s (in-list (get v 'declared))]) (string-append "declared " (source-text s)))
                        (for/list ([s (in-list (get v 'omitted))]) (string-append "omitted " (source-text s))))
                       "; "))]
      [("text") (format "“~a”" (get v 'text))]
      [else (display->plain v)]))
  (define (source-text s)
    (string-append (get s 'name)
                   (if (null? (get s 'fields)) ""
                       (string-append " ("
                                      (string-join (for/list ([f (in-list (get s 'fields))])
                                                     (string-append (get f 'name) " "
                                                                    (let ([v (get f 'value)])
                                                                      (if (equal? (get v 'kind) "text") (get v 'text) (display->plain v)))))
                                                   ", ")
                                      ")"))))
  (define (state-lines v [level 0])
    (append*
     (for/list ([f (in-list (if (and v (equal? (get v 'kind) "record")) (get v 'fields) '()))])
       (define fv (get f 'value))
       (cond
         [(and (equal? (get fv 'kind) "record") (pair? (get fv 'fields)))
          (cons (format "(~a, ~a)" level (tc (string-append (get f 'name) ":"))) (state-lines fv (add1 level)))]
         [(equal? (get fv 'kind) "uncertain")
          (list (format "(~a, [#~a #uncertainty(~a)])" level
                        (ts (string-append (get f 'name) ": " (value-text (get fv 'value))))
                        (ts (string-append "± " (cadr (regexp-match #rx"± (.*)$" (value-text fv)))))))]
         [else (list (format "(~a, ~a)" level (tc (string-append (get f 'name) ": " (value-text fv)))))]))))
  (define (state-block v)
    (format "[#state-lines(~a)]" (tarray (state-lines v))))

  (define (call-content c)
    (string-append
     "["
     "#" (ref 'procedure (get c 'procedure))
     (if (get c 'performer) (string-append " by #" (ref 'performer (get c 'performer))) "")
     (if (null? (get c 'inputs)) ""
         (string-append ", with "
                        (string-join (for/list ([i (in-list (get c 'inputs))])
                                       (format "#raw(~a) from #raw(~a)" (ts (get i 'name)) (ts (get i 'location))))
                                     ", ")))
     (if (get c 'into) (format ", into #raw(~a)" (ts (get c 'into))) "")
     "]"))

  (define names (code-names doc))
  ;; Diagrams are written next to booklet.typ, and placed after each summary.
  (define diagrams? (and work-dir (hash-ref (or (get settings 'layout) (hasheq)) 'diagrams #t)))
  (define (emit-diagram kind item file)
    (define d (and diagrams? (page-diagram doc kind item)))
    (when d
      (call-with-output-file (build-path work-dir file) #:exists 'replace
        (lambda (o) (write-string (diagram-svg d 'print (lambda _ #f) "" settings) o)))
      (emit (format "#diagram(~a, ~a)" (ts file) (ts (diagram-caption d))))))
  (define (method-code text)
    (format "#method-code(~a)"
            (tarray (for/list ([line (in-list (code-lines text names))])
                      (tarray (for/list ([tok (in-list line)])
                                (format "(~a, ~a)"
                                        (if (car tok) (ts (symbol->string (car tok))) "none")
                                        (ts (cdr tok)))))))))

  (define (facts rows)
    (define kept (filter cdr rows))
    (format "#facts(~a)" (tarray (for/list ([r (in-list kept)]) (format "(~a, ~a)" (tc (car r)) (cdr r))))))

  (define (procedure-section p level)
    (emit (format "#heading(level: ~a)[#~a] <~a>" level (ts (get p 'name)) (hash-ref labels (cons 'procedure (get p 'name)))))
    (emit (format "#idx(\"Procedures\", ~a, def: true)" (ts (get p 'name))))
    (emit (format "#about-text(~a)" (paragraphs (get p 'about))))
    (emit-diagram 'procedure p (format "diagram-procedure-~a.svg" (get p 'slug)))
    (emit (facts
           (list
            (cons "Inputs" (and (pair? (get p 'inputs)) (join-content (map code (get p 'inputs)) ", ")))
            (cons "Called by" (and (pair? (get p 'called_by))
                                   (join-content (for/list ([c (in-list (get p 'called_by))])
                                                   (ref (string->symbol (get c 'kind)) (get c 'name)))
                                                 ", ")))
            (cons "Calls" (and (pair? (get p 'calls)) (join-content (map (lambda (n) (ref 'procedure n)) (get p 'calls)) ", "))))))
    (unless (string=? (get p 'verbose) "")
      (emit (method-code (get p 'verbose)))))

  ;; Preamble
  (emit "#import \"template.typ\": *")
  (emit (format "#show: booklet.with(title: ~a, paper: ~a, body-size: ~a, text-font: ~a, code-font: ~a, colours: (~a))"
                (ts title)
                (ts (or (get booklet 'paper) "a4"))
                (or (get booklet 'body_size) "10.5pt")
                (ts (or (get fonts 'text) "Atkinson Hyperlegible Next"))
                (ts (or (get fonts 'code) "Atkinson Hyperlegible Mono"))
                (if (zero? (hash-count categories)) ":"
                    (string-join (for/list ([(k v) (in-hash categories)]) (format "~a: rgb(~a)" k (ts v))) ", "))))
  (emit (format "#title-page(title: ~a, about: ~a, logo: ~a)"
                (ts title) (paragraphs (get doc 'about))
                (let ([logo (get booklet 'logo_file)]) (if logo (ts logo) "none"))))
  (emit "#contents()")

  ;; Overview
  (emit "#pagebreak(weak: true)")
  (emit "#heading(level: 1)[Overview] <overview>")
  (emit (format "#about-text(~a)" (paragraphs (get doc 'about))))
  (emit-diagram 'overview doc "diagram-overview.svg")
  (emit "#heading(level: 2)[Method]")
  (let outline ([nodes (get doc 'outline)] [indent ""])
    (for ([node (in-list nodes)])
      (define name (get node 'name))
      (cond
        [(equal? (get node 'kind) "phase")
         (emit indent "- #" (ref 'phase name))
         (outline (get node 'children) (string-append indent "  "))]
        [else
         (define st (find-named (get doc 'stages) name))
         (emit indent "- #" (ref 'stage name)
               (if (get st 'performer) (string-append ", by #" (ref 'performer (get st 'performer))) ""))
         (for ([p (in-list (stage-procedures doc st))])
           (emit indent "  - #" (ref 'procedure (get p 'name))))])))
  (unless (null? (get doc 'performers))
    (emit "#heading(level: 2)[Performers]")
    (for ([p (in-list (get doc 'performers))])
      (emit (format "#anchor(~a)" (ts (hash-ref labels (cons 'performer (get p 'name))))))
      (emit (format "#idx(\"Performers\", ~a, def: true)" (ts (get p 'name))))
      (emit (format "#block[#performer-name(~a): #~a~a]"
                    (ts (get p 'name))
                    (ts (string-join (for/list ([f (in-list (get p 'fields))])
                                       (format "~a: ~a" (get f 'name) (let ([v (get f 'value)]) (if (equal? (get v 'kind) "text") (get v 'text) (display->plain v)))))
                                     "; "))
                    (if (null? (get p 'stages)) ""
                        (string-append ". Stages: " (string-join (map (lambda (n) (string-append "#" (ref 'stage n))) (get p 'stages)) ", "))))))
    (emit ""))
  (for ([kind (in-list '("hypothesis" "assumption" "conclusion"))]
        [heading (in-list '("Hypotheses" "Assumptions" "Conclusions"))])
    (define items (filter (lambda (p) (equal? (get p 'kind) kind)) (get doc 'propositions)))
    (unless (null? items)
      (emit (format "#heading(level: 2)[~a]" heading))
      (for ([p (in-list items)])
        (emit (format "/ #~a: #~a" (ts (get p 'name)) (ts (or (get p 'text) "")))))))
  (unless (null? (get doc 'requirements))
    (emit "#heading(level: 2)[Requirements]")
    (for ([r (in-list (get doc 'requirements))])
      (case (get r 'kind)
        [("stage-order")
         (emit "#idx(\"Requirements\", \"Stage order\", def: true)")
         (emit "- Stages run in this order: "
               (string-join (map (lambda (n) (string-append "#" (ref 'stage n))) (get r 'targets)) " → ") ".")]
        [else
         (emit (format "#idx(\"Requirements\", ~a, def: true)" (ts (get r 'kind))))
         (emit "- #" (ts (string-append (get r 'kind) ": " (string-join (get r 'targets) ", "))))])))
  (unless (null? (get doc 'libraries))
    (emit "#heading(level: 2)[Libraries]")
    (for ([l (in-list (get doc 'libraries))])
      (emit "- #" (ts (string-append (get l 'name)
                                     (if (string=? (get l 'version) "") "" (string-append ", version " (get l 'version)))
                                     (if (get l 'language) (string-append ", for ScienceLogo " (get l 'language)) "")
                                     (if (get l 'url) (string-append ": " (get l 'url)) ""))))))

  ;; The method, following its outline: a top-level phase or stage is a
  ;; chapter, and each stage is followed by the procedures only it uses.
  (define (heading-start level kind)
    (when (= level 1) (emit "#pagebreak(weak: true)"))
    (emit (format "#kind-label(~a)" (ts kind))))
  (define (phase-section ph level)
    (heading-start level "Phase")
    (emit (format "#heading(level: ~a)[#phase-name(~a)] <~a>" level (ts (get ph 'name))
                  (hash-ref labels (cons 'phase (get ph 'name)))))
    (emit (format "#idx(\"Phases\", ~a, def: true)" (ts (get ph 'name))))
    (emit (format "#about-text(~a)" (paragraphs (get ph 'about))))
    (emit-diagram 'phase ph (format "diagram-phase-~a.svg" (get ph 'slug)))
    (emit (facts (list (cons "Contains"
                             (join-content (for/list ([m (in-list (get ph 'members))])
                                             (ref (string->symbol (get m 'kind)) (get m 'name)))
                                           ", ")))))
    (unless (string=? (get ph 'verbose) "")
      (emit (method-code (get ph 'verbose)))))
  (define (stage-section s level)
    (define changes
      (if (get s 'paired)
          (let ([before (for/hash ([x (in-list (flat (get s 'entry)))]) (values (car x) (cdr x)))])
            (for/list ([x (in-list (flat (get s 'exit)))]
                       #:unless (equal? (hash-ref before (car x) #f) (cdr x)))
              (format "~a ~a" (car x) (if (hash-has-key? before (car x)) "changed" "added"))))
          '()))
    (heading-start level "Stage")
    (emit (format "#heading(level: ~a)[#stage-name(~a)] <~a>" level (ts (get s 'name)) (hash-ref labels (cons 'stage (get s 'name)))))
    (emit (format "#idx(\"Stages\", ~a, def: true)" (ts (get s 'name))))
    (emit (format "#about-text(~a)" (paragraphs (get s 'about))))
    (emit-diagram 'stage s (format "diagram-stage-~a.svg" (get s 'slug)))
    (emit (facts
           (list
            (cons "Performer" (and (get s 'performer) (string-append "[#" (ref 'performer (get s 'performer)) "]")))
            (cons "Starts with" (and (get s 'entry) (state-block (get s 'entry))))
            (cons "Steps" (and (pair? (get s 'calls))
                               (format "[#enum(~a)]" (string-join (map call-content (get s 'calls)) ", "))))
            (cons "Changes" (and (pair? changes) (format "[#list(~a)]" (string-join (map tc changes) ", "))))
            (cons "Ends with" (and (get s 'exit) (state-block (get s 'exit)))))))
    (unless (string=? (get s 'verbose) "")
      (emit (method-code (get s 'verbose))))
    (for ([p (in-list (stage-procedures doc s))])
      (procedure-section p (add1 level))))
  (let walk ([nodes (get doc 'outline)] [level 1])
    (for ([node (in-list nodes)])
      (define name (get node 'name))
      (if (equal? (get node 'kind) "phase")
          (begin (phase-section (find-named (get doc 'phases) name) level)
                 (walk (get node 'children) (add1 level)))
          (stage-section (find-named (get doc 'stages) name) level))))

  (define shared (shared-procedures doc))
  (unless (null? shared)
    (emit "#pagebreak(weak: true)")
    (emit "#heading(level: 1)[Shared procedures]")
    (for ([p (in-list shared)]) (procedure-section p 2)))

  (unless (null? (get doc 'record_types))
    (emit "#pagebreak(weak: true)")
    (emit "#heading(level: 1)[Reference]")
    (for ([r (in-list (get doc 'record_types))])
      (emit (format "#heading(level: 2)[#strong(~a)] <~a>" (ts (get r 'name)) (hash-ref labels (cons 'record (get r 'name)))))
      (emit (format "#idx(\"Record types\", ~a, def: true, sub: ~a)" (ts (get r 'name))
                    (tarray (map (lambda (f) (ts (get f 'name))) (get r 'fields)))))
      (when (get r 'version) (emit (format "Version #~a." (ts (get r 'version)))))
      (unless (null? (get r 'fields))
        (emit (format "#table(columns: 4, stroke: none, table.header([*Field*], [*Kind*], [*Default*], [*Required*]), ~a)"
                      (string-join (for/list ([f (in-list (get r 'fields))])
                                     (format "raw(~a), ~a, ~a, ~a" (ts (get f 'name))
                                             (tc (or (get f 'type) "")) (tc (or (get f 'default) ""))
                                             (tc (if (get f 'required) "yes" "no"))))
                                   ", "))))
      (unless (string=? (get r 'verbose) "")
        (emit (method-code (get r 'verbose))))))

  (emit (format "#analytical-index(~a)" (tarray (map ts index-kinds)))))

(define (flat v [prefix '()])
  (if (and v (equal? (get v 'kind) "record"))
      (append* (for/list ([f (in-list (get v 'fields))])
                 (flat (get f 'value) (append prefix (list (get f 'name))))))
      (list (cons (string-join prefix ".") (if v (display->plain v) "")))))
