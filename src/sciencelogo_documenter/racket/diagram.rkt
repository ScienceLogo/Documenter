#lang racket/base
;; Diagrams of the method: a subset of UML activity diagrams, one per page.
;;
;; A diagram shows one level of the method inside an activity frame. Its
;; steps run from left to right between a start node and an end node. On a
;; stage or procedure page, what the unit reads enters through parameter
;; boxes on the frame's left border, and what it writes leaves through
;; parameter boxes on the right border; the object flows run above and below
;; the steps, so they do not cross.
;;
;; The same geometry is drawn for the website, styled by the site's CSS so
;; that it follows the font switch and dark mode, and for the booklet, with
;; explicit fonts and colours.

(require json racket/list racket/math racket/runtime-path racket/string
         "markup.rkt" "structure.rkt")

(provide page-diagram
         diagram-svg
         diagram-caption)

(define-runtime-path widths-file "../static/glyph-widths.json")
(define widths (call-with-input-file widths-file read-json))

;; text-width : string symbol real -> real
;; The width of `s` at `size`, for the widest of the fonts the reader can choose.
(define (text-width s style size)
  (define table (hash-ref widths (case style [(bold) 'text-bold] [(code) 'code] [else 'text])))
  (define fallback (apply max (hash-values table)))
  (* size 1/1000
     (for/sum ([c (in-string s)])
       (hash-ref table (string->symbol (string c)) fallback))))

;; ---------------------------------------------------------------------------
;; Model

;; A step in the diagram. kind: 'stage, 'phase, 'procedure or 'action.
(struct step (kind label performer call? inputs output) #:transparent)
;; A diagram: the unit's kind and name, its steps, and the names of what
;; enters and leaves. Each flow names a parameter and a step's pin.
(struct diagram (kind title steps ins outs in-flows out-flows) #:transparent)

(define (location-label loc)
  (regexp-replace #rx"^information[.]" loc ""))

;; page-diagram : doc symbol hash -> (or/c diagram #f)
;; The diagram of a page, or #f when the page has no steps to show.
(define (page-diagram doc kind item)
  (define d
    (case kind
      [(overview)
       (diagram 'workflow (or (get item 'title) "Workflow")
                (for/list ([n (in-list (get doc 'outline))]) (outline-step doc n)) '() '() '() '())]
      [(phase)
       (diagram 'phase (get item 'name)
                (for/list ([m (in-list (get item 'members))])
                  (outline-step doc (hasheq 'kind (get m 'kind) 'name (get m 'name))))
                '() '() '() '())]
      [(stage) (stage-diagram item)]
      [(procedure) (procedure-diagram doc item)]
      [else #f]))
  (and d (pair? (diagram-steps d)) d))

(define (outline-step doc node)
  (define name (get node 'name))
  (if (equal? (get node 'kind) "phase")
      (step 'phase name #f #t '() #f)
      (let ([s (find-named (get doc 'stages) name)])
        (step 'stage name (and s (get s 'performer)) #t '() #f))))

(define (stage-diagram s)
  (define calls (get s 'calls))
  (define steps
    (for/list ([c (in-list calls)])
      (step 'procedure (get c 'procedure) (get c 'performer) #t
            (map (lambda (i) (get i 'name)) (get c 'inputs))
            (and (get c 'into) (last (string-split (get c 'into) "."))))))
  (define ins (remove-duplicates (append* (for/list ([c (in-list calls)])
                                            (map (lambda (i) (location-label (get i 'location))) (get c 'inputs))))))
  (define outs (remove-duplicates (filter values (for/list ([c (in-list calls)])
                                                   (and (get c 'into) (location-label (get c 'into)))))))
  (define in-flows
    (append* (for/list ([c (in-list calls)] [k (in-naturals)])
               (for/list ([i (in-list (get c 'inputs))] [p (in-naturals)])
                 (list (index-of ins (location-label (get i 'location))) k p)))))
  (define out-flows
    (for/list ([c (in-list calls)] [k (in-naturals)] #:when (get c 'into))
      (list (index-of outs (location-label (get c 'into))) k)))
  (diagram 'stage (get s 'name) steps ins outs in-flows out-flows))

(define (procedure-diagram doc p)
  (define calls (for/list ([n (in-list (get p 'calls))]) (step 'procedure n #f #t '() #f)))
  (define output (get p 'output))
  (define ins (get p 'inputs))
  (define final
    (if output (list (step 'action output #f #f ins "result")) '()))
  (define steps (append calls final))
  (define k (sub1 (length steps)))
  (diagram 'procedure (get p 'name) steps ins (if output '("result") '())
           (if output (for/list ([i (in-list ins)] [n (in-naturals)]) (list n k n)) '())
           (if output (list (list 0 k)) '())))

;; ---------------------------------------------------------------------------
;; Geometry

(define font 14)        ; labels in the steps
(define small 12)       ; pins, parameters and performers
(define track 22)       ; distance between object-flow tracks
(define gap 44)         ; length of a control-flow arrow
(define pad 12)

(struct placed (step x y w h pins-in pin-out) #:transparent)

(define (label-style k) (if (memq k '(procedure action)) 'code 'bold))
(define (label-text st)
  (if (eq? (step-kind st) 'phase) (string-upcase (step-label st)) (step-label st)))

;; Pins sit on the top edge, each followed by its label.
(define (pin-offsets inputs)
  (let loop ([ins inputs] [x 14] [acc '()])
    (if (null? ins)
        (reverse acc)
        (loop (cdr ins) (+ x (text-width (car ins) 'code small) 24) (cons x acc)))))
(define (pins-width inputs)
  (+ 14 (for/sum ([i (in-list inputs)]) (+ (text-width i 'code small) 24))))

(define (step-size st)
  (define name-w (text-width (label-text st) (label-style (step-kind st)) font))
  (define perf-w (if (step-performer st) (text-width (format "(~a)" (step-performer st)) 'text small) 0))
  (define w (max (+ (* 2 pad) (max name-w perf-w) (if (step-call? st) 16 0))
                 (pins-width (step-inputs st))))
  (define h (if (step-performer st) 50 36))
  (values (max w 64) h))

;; layout : diagram -> hash of positions
(define (layout d)
  (define steps (diagram-steps d))
  (define n-in (length (diagram-ins d)))
  (define n-out (length (diagram-outs d)))
  (define param-w (lambda (s) (+ 12 (text-width s 'code small))))
  (define left-w (apply max 0 (map param-w (diagram-ins d))))
  (define right-w (apply max 0 (map param-w (diagram-outs d))))
  (define tab-h 26)
  (define pin-label 16)
  (define top (+ tab-h 14 (* n-in track) (if (zero? n-in) 0 pin-label)))
  (define sizes (for/list ([st (in-list steps)]) (call-with-values (lambda () (step-size st)) cons)))
  (define row-h (apply max (map cdr sizes)))
  (define row-y top)
  (define frame-x (+ 4 (/ left-w 2)))
  (define start-x (+ frame-x 28 (if (zero? n-in) 0 (/ left-w 2))))
  (define-values (placed-steps end-x)
    (for/fold ([acc '()] [x (+ start-x 8 gap)]) ([st (in-list steps)] [sz (in-list sizes)])
      (define w (car sz))
      (define h (cdr sz))
      (define y (+ row-y (/ (- row-h h) 2)))
      (define ins (step-inputs st))
      (define pins (for/list ([o (in-list (pin-offsets ins))]) (+ x o)))
      (values (cons (placed st x y w h pins (and (step-output st) (+ x (/ w 2)))) acc)
              (+ x w gap))))
  (define ps (reverse placed-steps))
  (define final-x (+ end-x -8))
  (define frame-right (+ final-x 28 (if (zero? n-out) 0 (/ right-w 2))))
  (define bottom (+ row-y row-h (if (zero? n-out) 0 pin-label) (* n-out track) 18))
  ;; Input tracks: the farthest pin gets the highest track, so flows do not cross.
  (define in-order
    (sort (range n-in) >
          #:key (lambda (i) (apply max (for/list ([f (in-list (diagram-in-flows d))] #:when (= (car f) i))
                                         (list-ref (placed-pins-in (list-ref ps (cadr f))) (caddr f)))))))
  (define in-y (for/hash ([i (in-list in-order)] [t (in-naturals)]) (values i (+ tab-h 18 (* t track)))))
  ;; Output tracks: the leftmost pin gets the lowest track.
  (define out-order
    (sort (range n-out) <
          #:key (lambda (o) (apply min (for/list ([f (in-list (diagram-out-flows d))] #:when (= (car f) o))
                                         (placed-pin-out (list-ref ps (cadr f))))))))
  (define out-y (for/hash ([o (in-list out-order)] [t (in-naturals)])
                  (values o (- bottom 18 (* t track)))))
  (hasheq 'steps ps 'row-y row-y 'row-h row-h 'start-x start-x 'final-x final-x
          'frame-x frame-x 'frame-right frame-right 'bottom bottom 'tab-h tab-h
          'in-y in-y 'out-y out-y 'left-w left-w 'right-w right-w
          'width (+ frame-right (/ right-w 2) 4) 'height (+ bottom 4)))

;; ---------------------------------------------------------------------------
;; Drawing

(define (num x) (real->decimal-string (exact->inexact x) 1))

;; diagram-svg : diagram symbol (symbol string -> (or/c string #f)) string hash -> string
;; mode is 'web (styled by the site's CSS) or 'print (explicit fonts and colours).
(define (diagram-svg d mode target root settings [id "diagram"])
  (define g (layout d))
  (define web? (eq? mode 'web))
  (define cats (or (get (or (get (or (get settings 'colours) (hasheq)) 'categories) (hasheq)) 'light) (hasheq)))
  (define (cat k) (or (get cats k) (hash-ref #hasheq((stage . "#0072B2") (procedure . "#009E73") (performer . "#E69F00")) k)))
  (define ink (if web? "currentColor" "#1a1a1a"))
  (define paper (if web? " style=\"fill:var(--background)\"" " fill=\"#ffffff\""))
  (define fonts (or (get settings 'fonts) (hasheq)))
  (define (font-list chosen standard)
    (if (and chosen (not (equal? chosen standard))) (format "~a, ~a" chosen standard) standard))
  (define text-font (font-list (get fonts 'text) "Atkinson Hyperlegible Next"))
  (define code-font (font-list (get fonts 'code) "Atkinson Hyperlegible Mono"))
  ;; On the web the fonts come from the page, so the font switch applies.
  (define (font-attr style)
    (if web?
        (format " class=\"~a\"" (if (eq? style 'code) "dg-code" "dg-text"))
        (format " font-family=\"~a\"" (esc (if (eq? style 'code) code-font text-font)))))
  (define (text x y s #:style [style 'text] #:size [size font] #:anchor [anchor "middle"])
    (format "<text x=\"~a\" y=\"~a\" text-anchor=\"~a\" font-size=\"~a\"~a~a~a>~a</text>"
            (num x) (num y) anchor size
            (font-attr style)
            (if (eq? style 'bold) " font-weight=\"700\"" "")
            (if (eq? style 'italic) " font-style=\"italic\"" "")
            (esc s)))
  (define (line x1 y1 x2 y2 #:arrow [arrow #t] #:dash [dash #f])
    (format "<path d=\"M~a ~aL~a ~a\" fill=\"none\" stroke=\"~a\" stroke-width=\"1.3\"~a~a/>"
            (num x1) (num y1) (num x2) (num y2) ink
            (if dash " stroke-dasharray=\"4 3\"" "")
            (if arrow (format " marker-end=\"url(#~a-arrow)\"" id) "")))
  (define (polyline pts)
    (format "<path d=\"M~a\" fill=\"none\" stroke=\"~a\" stroke-width=\"1.3\" marker-end=\"url(#~a-arrow)\"/>"
            (string-join (for/list ([p (in-list pts)]) (format "~a ~a" (num (car p)) (num (cdr p)))) "L")
            ink id))
  (define ps (hash-ref g 'steps))
  (define row-y (hash-ref g 'row-y))
  (define row-h (hash-ref g 'row-h))
  (define mid (+ row-y (/ row-h 2)))
  (define fx (hash-ref g 'frame-x))
  (define fr (hash-ref g 'frame-right))
  (define bottom (hash-ref g 'bottom))
  (define tab-h (hash-ref g 'tab-h))
  (define heading (format "~a ~a" (diagram-kind d) (diagram-title d)))
  (define tab-w (+ 24 (text-width heading 'bold small)))

  (define frame
    (string-append
     (format "<rect x=\"~a\" y=\"2\" width=\"~a\" height=\"~a\" rx=\"10\" fill=\"none\" stroke=\"~a\" stroke-width=\"1.3\"/>"
             (num fx) (num (- fr fx)) (num (- bottom 2)) ink)
     ;; The frame's heading, in a tab with a cut corner, as UML draws it.
     (format "<path d=\"M~a 2H~aV~aL~a ~aH~a\" fill=\"none\" stroke=\"~a\" stroke-width=\"1.3\"/>"
             (num fx) (num (+ fx tab-w)) (num (- tab-h 8)) (num (- (+ fx tab-w) 8)) (num tab-h) (num fx) ink)
     (text (+ fx 10) (- tab-h 9) heading #:style 'bold #:size small #:anchor "start")))

  (define start
    (format "<circle cx=\"~a\" cy=\"~a\" r=\"7\" fill=\"~a\"/>" (num (hash-ref g 'start-x)) (num mid) ink))
  (define final
    (format "<circle cx=\"~a\" cy=\"~a\" r=\"9\" fill=\"none\" stroke=\"~a\" stroke-width=\"1.3\"/><circle cx=\"~a\" cy=\"~a\" r=\"5\" fill=\"~a\"/>"
            (num (hash-ref g 'final-x)) (num mid) ink (num (hash-ref g 'final-x)) (num mid) ink))

  (define control
    (let* ([xs (append (list (+ (hash-ref g 'start-x) 7))
                       (append* (for/list ([p (in-list ps)]) (list (placed-x p) (+ (placed-x p) (placed-w p)))))
                       (list (- (hash-ref g 'final-x) 9)))])
      (apply string-append
             (for/list ([a (in-list xs)] [b (in-list (cdr xs))] [k (in-naturals)] #:when (even? k))
               (line a mid b mid)))))

  (define steps-svg
    (apply string-append
           (for/list ([p (in-list ps)])
             (define st (placed-step p))
             (define x (placed-x p))
             (define y (placed-y p))
             (define w (placed-w p))
             (define h (placed-h p))
             (define k (step-kind st))
             (define marker (case k [(stage) (cat 'stage)] [(procedure) (cat 'procedure)] [else #f]))
             (define body
               (string-append
                (format "<rect x=\"~a\" y=\"~a\" width=\"~a\" height=\"~a\" rx=\"9\"~a stroke=\"~a\" stroke-width=\"1.3\"/>"
                        (num x) (num y) (num w) (num h) paper ink)
                (if marker
                    (format "<path d=\"M~a ~aH~a\" stroke=\"~a\" stroke-width=\"3\"~a/>"
                            (num (+ x 9)) (num (- (+ y h) 4)) (num (- (+ x w) 9)) marker
                            (if web? (format " class=\"dg-~a\"" k) ""))
                    "")
                (if (step-performer st)
                    (text (+ x (/ w 2)) (+ y 17) (format "(~a)" (step-performer st)) #:style 'italic #:size small)
                    "")
                (text (+ x (/ w 2)) (+ y (if (step-performer st) 36 23)) (label-text st)
                      #:style (label-style k))
                ;; The rake: this step calls an activity drawn on its own page.
                (if (step-call? st)
                    (let ([rx (- (+ x w) 11)] [ry (- (+ y h) 17)])
                      (format "<path d=\"M~a ~aV~aM~a ~aH~aM~a ~aV~aM~a ~aV~a\" fill=\"none\" stroke=\"~a\" stroke-width=\"1.2\"/>"
                              (num rx) (num ry) (num (+ ry 5)) (num (- rx 4)) (num (+ ry 5)) (num (+ rx 4))
                              (num (- rx 4)) (num (+ ry 5)) (num (+ ry 9)) (num (+ rx 4)) (num (+ ry 5)) (num (+ ry 9)) ink))
                    "")))
             (define url (and web? (memq k '(stage phase procedure)) (target k (step-label st))))
             (string-append
              (if url
                  (format "<a href=\"~a\">~a</a>"
                          (esc (if (regexp-match? #rx"^https?://" url) url (string-append root url))) body)
                  body)
              ;; Input pins on the top edge, the output pin on the bottom edge.
              (apply string-append
                     (for/list ([px (in-list (placed-pins-in p))] [name (in-list (step-inputs st))])
                       (string-append
                        (format "<rect x=\"~a\" y=\"~a\" width=\"8\" height=\"8\"~a stroke=\"~a\" stroke-width=\"1.2\"/>"
                                (num (- px 4)) (num (- y 4)) paper ink)
                        (text (+ px 6) (- y 8) name #:style 'code #:size small #:anchor "start"))))
              (if (placed-pin-out p)
                  (string-append
                   (format "<rect x=\"~a\" y=\"~a\" width=\"8\" height=\"8\"~a stroke=\"~a\" stroke-width=\"1.2\"/>"
                           (num (- (placed-pin-out p) 4)) (num (- (+ y h) 4)) paper ink)
                   (text (+ (placed-pin-out p) 7) (+ y h 15) (step-output st) #:style 'code #:size small #:anchor "start"))
                  "")))))

  (define (param x y s)
    (define w (+ 12 (text-width s 'code small)))
    (string-append
     (format "<rect x=\"~a\" y=\"~a\" width=\"~a\" height=\"18\"~a stroke=\"~a\" stroke-width=\"1.3\"/>"
             (num (- x (/ w 2))) (num (- y 9)) (num w) paper ink)
     (text x (+ y 4) s #:style 'code #:size small)))

  (define flows
    (string-append
     (apply string-append
            (for/list ([f (in-list (diagram-in-flows d))])
              (define y (hash-ref (hash-ref g 'in-y) (car f)))
              (define p (list-ref ps (cadr f)))
              (define px (list-ref (placed-pins-in p) (caddr f)))
              (polyline (list (cons (+ fx (/ (hash-ref g 'left-w) 2)) y) (cons px y) (cons px (- (placed-y p) 5))))))
     (apply string-append
            (for/list ([f (in-list (diagram-out-flows d))])
              (define y (hash-ref (hash-ref g 'out-y) (car f)))
              (define p (list-ref ps (cadr f)))
              (define px (placed-pin-out p))
              (polyline (list (cons px (+ (placed-y p) (placed-h p) 4)) (cons px y)
                              (cons (- fr (/ (hash-ref g 'right-w) 2)) y)))))))

  (define params
    (string-append
     (apply string-append
            (for/list ([s (in-list (diagram-ins d))] [i (in-naturals)])
              (param fx (hash-ref (hash-ref g 'in-y) i) s)))
     (apply string-append
            (for/list ([s (in-list (diagram-outs d))] [o (in-naturals)])
              (param fr (hash-ref (hash-ref g 'out-y) o) s)))))

  (define width (hash-ref g 'width))
  (define height (hash-ref g 'height))
  (string-append
   (format "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 ~a ~a\" width=\"~a\" height=\"~a\"~a aria-labelledby=\"~a-title ~a-desc\">"
           (num width) (num height) (num width) (num height)
           (if web? " class=\"diagram\"" "") id id)
   (format "<title id=\"~a-title\">~a</title><desc id=\"~a-desc\">~a</desc>"
           id (esc (diagram-caption d)) id (esc (diagram-description d)))
   (format "<defs><marker id=\"~a-arrow\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto-start-reverse\"><path d=\"M0 0L10 5L0 10z\" fill=\"~a\"/></marker></defs>"
           id ink)
   frame flows control start final steps-svg params
   "</svg>"))

;; diagram-caption : diagram -> string
(define (diagram-caption d)
  (format "Diagram of the ~a ~a" (diagram-kind d) (diagram-title d)))

(define (diagram-description d)
  (define steps (diagram-steps d))
  (string-append
   (format "~a: " (diagram-title d))
   (string-join (map (lambda (st) (format "~a ~a" (step-kind st) (step-label st))) steps) ", then ")
   "."
   (if (null? (diagram-ins d)) "" (format " It reads ~a." (string-join (diagram-ins d) ", ")))
   (if (null? (diagram-outs d)) "" (format " It writes ~a." (string-join (diagram-outs d) ", ")))))
