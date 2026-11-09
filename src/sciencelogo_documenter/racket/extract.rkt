#lang racket/base
;; Builds the documentation model of a workflow with the reference reader.
;; The model describes the method and holds no file paths.

(require racket/list racket/match racket/path racket/string
         sciencelogo/workflow-model
         (only-in sciencelogo/private/reader
                  parse-sciencelogo-tree-file node-kind node-value node-at node-children node->datum
                  token? token-source token-position)
         "markers.rkt"
         "values.rkt"
         "verbose.rkt")

(provide extract-documentation
         slugify)

;; Top-level forms that start a new item. Other forms are commands, which
;; belong to the simple stage before them.
(define declaration-kinds
  '(about performer resource interface proposition phase must-stage-order must-call
    included-file include import implements implement to stage state-stage library))

;; slugify : string -> string
(define (slugify name)
  (define s (string-downcase (regexp-replace* #rx"[^A-Za-z0-9]+" name "-")))
  (define trimmed (string-trim s "-"))
  (if (string=? trimmed "") "item" trimmed))

(define (unique-slugs names)
  (define used (make-hash))
  (for/list ([name (in-list names)])
    (define base (slugify name))
    (let loop ([n 1])
      (define candidate (if (= n 1) base (format "~a-~a" base n)))
      (if (hash-ref used candidate #f)
          (loop (add1 n))
          (begin (hash-set! used candidate #t) candidate)))))

(define (description-text d)
  (and d (normalize-about (description-model-text d))))

;; About texts keep their paragraphs; line breaks and indentation inside a
;; paragraph come from the source layout and are removed.
(define (normalize-about text)
  (define paragraphs (regexp-split #rx"\n[ \t]*\n" text))
  (string-join (for/list ([p (in-list paragraphs)])
                 (string-normalize-spaces p))
               "\n\n"))

(define (input-name id)
  (match (regexp-match #rx"/input:([^/]*)$" id)
    [(list _ name) name]
    [_ id]))

;; extract-documentation : path-string -> jsexpr
(define (extract-documentation entry)
  (define source (path->string (path->complete-path entry)))
  (define model (read-workflow-model source))
  (define tree (parse-sciencelogo-tree-file source))
  (define cut (make-verbose-cutter))

  ;; Start positions of the items in each file.
  (define boundaries (make-hash))
  (for ([form (in-list (node-children* tree))])
    (define at (node-at form))
    (when (and (token? at) (memq (node-kind form) declaration-kinds))
      (hash-update! boundaries (format "~a" (token-source at))
                    (lambda (l) (cons (token-position at) l)) '())))
  ;; The verbose text of an item. The model gives the end of stages, phases
  ;; and procedures; other items end where the next item starts.
  (define (verbose-at ref [end-ref #f])
    (cond
      [(not ref) ""]
      [else
       (define file (source-ref-source ref))
       (define start (source-ref-position ref))
       (define later (filter (lambda (p) (> p start)) (hash-ref boundaries file '())))
       (define end
         (if (and end-ref (equal? (source-ref-source end-ref) file))
             (source-ref-position end-ref)
             (and (pair? later) (apply min later))))
       ;; Items read from an imported library have no local file.
       (if (file-exists? file)
           (cut file start end)
           "")]))

  ;; Imported libraries, with the documentation markers of their entry files.
  (define warnings '())
  (define imports
    (filter (lambda (i) (not (regexp-match? #rx"[.]" (format "~a" (import-model-alias i)))))
            (workflow-model-imports model)))
  (define library-info
    (for/list ([i (in-list imports)])
      (define name (format "~a" (or (import-model-library-name i) (import-model-alias i))))
      (define-values (markers marker-warnings)
        (library-doc-markers (import-model-url i) (format "~a" (import-model-commit i))))
      (set! warnings (append warnings (map (lambda (w) (format "library ~a: ~a" name w)) marker-warnings)))
      (hasheq 'alias (format "~a" (import-model-alias i))
              'name name
              'version (format "~a" (or (import-model-requested-revision i) ""))
              'language (let ([l (import-model-language i)]) (if l (format "~a" l) 'null))
              'url (hash-ref markers "url" #f))))
  (define (library-of name)
    (for/first ([l (in-list library-info)]
                #:when (string-prefix? name (string-append (hash-ref l 'alias) ".")))
      l))

  ;; Stages and procedures.
  (define stages (workflow-model-stages model))
  (define procedures (workflow-model-procedures model))
  (define stage-by-id (for/hash ([s (in-list stages)]) (values (stage-model-id s) s)))
  (define procedure-by-id (for/hash ([p (in-list procedures)]) (values (procedure-model-id p) p)))
  (define stage-slugs (unique-slugs (map stage-model-name stages)))
  (define procedure-slugs (unique-slugs (map (lambda (p) (format "~a" (procedure-model-name p))) procedures)))
  (define stage-slug (for/hash ([s stages] [slug stage-slugs]) (values (stage-model-name s) slug)))
  (define procedure-slug
    (for/hash ([p procedures] [slug procedure-slugs]) (values (format "~a" (procedure-model-name p)) slug)))

  ;; Calls: each call names the procedure, the caller and its details.
  (define calls
    (for/list ([a (in-list (workflow-model-activities model))]
               #:when (memq (activity-model-kind a) '(state-call call))
               #:when (activity-model-name a))
      a))
  (define (caller-of a)
    (define parent (activity-model-parent a))
    (cond
      [(hash-ref stage-by-id parent #f) => (lambda (s) (cons 'stage (stage-model-name s)))]
      [(hash-ref procedure-by-id parent #f)
       => (lambda (p) (cons 'procedure (format "~a" (procedure-model-name p))))]
      [else #f]))
  (define (call->display a stage-performer)
    (define name (format "~a" (activity-model-name a)))
    (match (activity-model-details a)
      [(list inputs into performer _ ...)
       (hasheq 'procedure name
               'performer (if performer (format "~a" performer) (or stage-performer 'null))
               'inputs (for/list ([i (in-list inputs)])
                         (hasheq 'name (format "~a" (car i)) 'location (path->display (cadr i))))
               'into (if (list? into) (path->display into) 'null))]
      [_ (hasheq 'procedure name 'performer (or stage-performer 'null) 'inputs '() 'into 'null)]))

  (define called-by (make-hash))
  (define calls-from (make-hash))
  (for ([a (in-list calls)])
    (define callee (format "~a" (activity-model-name a)))
    (define caller (caller-of a))
    (when caller
      (hash-update! called-by callee (lambda (l) (if (member caller l) l (append l (list caller)))) '())
      (when (eq? (car caller) 'procedure)
        (hash-update! calls-from (cdr caller)
                      (lambda (l) (if (member callee l) l (append l (list callee)))) '()))))

  (define (stage-owner procedure-name)
    (define callers (hash-ref called-by procedure-name '()))
    (define stage-callers (remove-duplicates (filter (lambda (c) (eq? (car c) 'stage)) callers)))
    (and (not (library-of procedure-name))
         (= 1 (length stage-callers))
         (= (length callers) 1)
         (cdr (car stage-callers))))

  ;; Phases group stages and smaller phases. Their members are named by id.
  (define phases (workflow-model-phases model))
  (define phase-by-id (for/hash ([p (in-list phases)]) (values (phase-model-id p) p)))
  (define phase-by-name (for/hash ([p (in-list phases)]) (values (format "~a" (phase-model-name p)) p)))
  (define (member-of id)
    (cond
      [(hash-ref stage-by-id id #f) => (lambda (s) (cons 'stage (stage-model-name s)))]
      [(hash-ref phase-by-id id #f) => (lambda (p) (cons 'phase (format "~a" (phase-model-name p))))]
      [(hash-ref phase-by-name (format "~a" id) #f) => (lambda (p) (cons 'phase (format "~a" (phase-model-name p))))]
      [(findf (lambda (s) (equal? (stage-model-name s) (format "~a" id))) stages)
       => (lambda (s) (cons 'stage (stage-model-name s)))]
      [else #f]))
  (define phase-members
    (for/hash ([p (in-list phases)])
      (values (format "~a" (phase-model-name p)) (filter values (map member-of (phase-model-members p))))))
  (define phase-of
    (for*/hash ([(phase members) (in-hash phase-members)] [m (in-list members)])
      (values m phase)))
  (define phase-slugs (unique-slugs (map (lambda (p) (format "~a" (phase-model-name p))) phases)))
  (define phase-records
    (for/list ([p (in-list phases)] [slug (in-list phase-slugs)])
      (define name (format "~a" (phase-model-name p)))
      (hasheq 'name name
              'slug slug
              'about (or (description-text (phase-model-description p)) 'null)
              'members (for/list ([m (in-list (hash-ref phase-members name))])
                         (hasheq 'kind (symbol->string (car m)) 'name (cdr m)))
              'phase (or (hash-ref phase-of (cons 'phase name) #f) 'null)
              'verbose (verbose-at (phase-model-source p) (phase-model-end p)))))
  ;; The method as an outline: top-level phases and stages, in stage order.
  (define (outline-node m)
    (if (eq? (car m) 'stage)
        (hasheq 'kind "stage" 'name (cdr m) 'children '())
        (hasheq 'kind "phase" 'name (cdr m)
                'children (map outline-node (hash-ref phase-members (cdr m))))))
  (define (top-of m)
    (define parent (hash-ref phase-of m #f))
    (if parent (top-of (cons 'phase parent)) m))
  (define method-outline
    (let loop ([ss stages] [seen '()] [acc '()])
      (cond
        [(null? ss) (reverse acc)]
        [else
         (define top (top-of (cons 'stage (stage-model-name (car ss)))))
         (if (member top seen)
             (loop (cdr ss) seen acc)
             (loop (cdr ss) (cons top seen) (cons (outline-node top) acc)))])))

  (define stage-records
    (for/list ([s (in-list stages)])
      (define name (stage-model-name s))
      (define performer (and (stage-model-performer s) (format "~a" (stage-model-performer s))))
      (define own-calls
        (for/list ([a (in-list calls)] #:when (equal? (activity-model-parent a) (stage-model-id s)))
          (call->display a performer)))
      (hasheq 'name name
              'slug (hash-ref stage-slug name)
              'about (or (description-text (stage-model-description s)) 'null)
              'performer (or performer 'null)
              'paired (and (stage-model-entry s) #t)
              'entry (if (stage-model-entry s) (value->display (stage-model-entry s)) 'null)
              'exit (if (stage-model-exit s) (value->display (stage-model-exit s)) 'null)
              'calls own-calls
              'procedures (for/list ([p (in-list procedures)]
                                     #:when (equal? (stage-owner (format "~a" (procedure-model-name p))) name))
                            (format "~a" (procedure-model-name p)))
              'phase (or (hash-ref phase-of (cons 'stage name) #f) 'null)
              'verbose (verbose-at (stage-model-source s) (stage-model-end s)))))

  (define procedure-records
    (for/list ([p (in-list procedures)])
      (define name (format "~a" (procedure-model-name p)))
      (define library (library-of name))
      (hasheq 'name name
              'library (if library (hash-ref library 'name) 'null)
              'library_version (if library (hash-ref library 'version) 'null)
              'library_url (or (and library (hash-ref library 'url)) 'null)
              'slug (hash-ref procedure-slug name)
              'about (or (description-text (procedure-model-description p)) 'null)
              'inputs (map input-name (procedure-model-inputs p))
              'called_by (for/list ([c (in-list (hash-ref called-by name '()))])
                           (hasheq 'kind (symbol->string (car c)) 'name (cdr c)))
              'calls (hash-ref calls-from name '())
              'stage (or (stage-owner name) 'null)
              'verbose (verbose-at (procedure-model-source p) (procedure-model-end p)))))

  ;; Performers, propositions, requirements, record types and libraries.
  (define performer-records
    (for/list ([p (in-list (workflow-model-performers model))])
      (define name (format "~a" (performer-model-name p)))
      (hasheq 'name name
              'fields (match (value->display (performer-model-fields p))
                        [(hash-table ('kind "record") ('fields fs)) fs]
                        [_ '()])
              'stages (for/list ([s (in-list stage-records)]
                                 #:when (or (equal? (hash-ref s 'performer) name)
                                            (for/or ([c (in-list (hash-ref s 'calls))])
                                              (equal? (hash-ref c 'performer) name))))
                        (hash-ref s 'name))
              'verbose (verbose-at (performer-model-source p)))))

  (define proposition-records
    (for/list ([p (in-list (workflow-model-propositions model))])
      (define fields (value->display (proposition-model-fields p)))
      (define text
        (for/first ([f (in-list (if (equal? (hash-ref fields 'kind) "record") (hash-ref fields 'fields) '()))]
                    #:when (equal? (hash-ref f 'name) "text"))
          (display->plain* (hash-ref f 'value))))
      (hasheq 'kind (format "~a" (proposition-model-type p))
              'name (format "~a" (proposition-model-name p))
              'text (or text 'null)
              'verbose (verbose-at (proposition-model-source p)))))

  (define requirement-records
    (for/list ([c (in-list (workflow-model-conditions model))])
      (define target (condition-model-target c))
      (hasheq 'kind (format "~a" (condition-model-kind c))
              'targets (map (lambda (t) (format "~a" t)) (if (list? target) target (list target)))
              'verbose (verbose-at (condition-model-source c)))))

  (define record-types
    (for/list ([form (in-list (node-children* tree))]
               #:when (eq? (node-kind form) 'interface)
               #:when (let ([at (node-at form)])
                        (and (token? at) (file-exists? (format "~a" (token-source at))))))
      (define at (node-at form))
      (define ref (and (token? at)
                       (source-ref (format "~a" (token-source at)) #f #f (token-position at))))
      (interface->record (node->datum form) (verbose-at ref))))

  ;; Only libraries with a documentation URL are mapped and documented.
  (define libraries
    (for/list ([l (in-list library-info)] #:when (hash-ref l 'url))
      (hasheq 'name (hash-ref l 'name)
              'version (hash-ref l 'version)
              'language (hash-ref l 'language)
              'url (hash-ref l 'url))))

  (hasheq 'title (or (workflow-model-title model) 'null)
          'about (or (description-text (workflow-model-description model)) 'null)
          'outline method-outline
          'phases phase-records
          'stages stage-records
          'procedures procedure-records
          'performers performer-records
          'propositions proposition-records
          'requirements requirement-records
          'record_types record-types
          'libraries libraries
          'warnings warnings))

(define (display->plain* v)
  (if (equal? (hash-ref v 'kind) "text") (hash-ref v 'text) (display->plain v)))

(define node-children* node-children)

;; interface->record : datum string -> jsexpr
(define (interface->record datum verbose)
  (match datum
    [`(interface ,name ,entries)
     (define version
       (for/first ([e (in-list entries)] #:when (and (pair? e) (eq? (car e) 'version))) (cadr e)))
     (define fields
       (append*
        (for/list ([e (in-list entries)])
          (match e
            [`(interface-field ,field ,default ,required ,_ ...)
             (list (hasheq 'name (format "~a" field)
                           'required (and required #t)
                           'type 'null
                           'default (if default (display->plain (value->display default)) 'null)))]
            [`(interface-requirement (kind-test ,type ((result ,field))))
             (list (hasheq 'name (format "~a" field)
                           'required #t
                           'type (format "~a" type)
                           'default 'null))]
            [_ '()]))))
     (hasheq 'name (format "~a" name)
             'slug (slugify (format "~a" name))
             'version (or version 'null)
             'fields fields
             'verbose verbose)]
    [_ (hasheq 'name (format "~a" datum) 'slug "record" 'version 'null 'fields '() 'verbose verbose)]))
