#lang racket/base
;; Converts value terms of the workflow model into display records.
;; A display record is a hash: kind = number, text, boolean, unknown, record,
;; uncertain or expression. Numbers keep an optional unit.

(require racket/list racket/match racket/string)

(provide value->display
         number->display
         display->plain
         path->display)

;; number->display : real -> string
;; Writes exact numbers in decimal form when they have one.
(define (number->display n)
  (cond
    [(and (exact? n) (integer? n)) (number->string n)]
    [(and (exact? n) (rational? n))
     (define d (denominator n))
     (define (strip k f) (if (zero? (modulo k f)) (strip (quotient k f) f) k))
     (if (= 1 (strip (strip d 2) 5))
         (let loop ([digits 1])
           (define scaled (* n (expt 10 digits)))
           (if (integer? scaled)
               (let* ([sign (if (negative? n) "-" "")]
                      [s (number->string (abs scaled))]
                      [s (if (<= (string-length s) digits)
                             (string-append (make-string (- (add1 digits) (string-length s)) #\0) s)
                             s)]
                      [cut (- (string-length s) digits)])
                 (string-append sign (substring s 0 cut) "." (substring s cut)))
               (loop (add1 digits))))
         (let ([s (real->decimal-string* (exact->inexact n))]) s))]
    [else (real->decimal-string* n)]))

(define (real->decimal-string* x)
  (define s (number->string x))
  (if (regexp-match? #rx"e" s) s (string-trim (string-trim s "0" #:left? #f) "." #:left? #f)))

;; path->display : (listof symbol) -> string
(define (path->display parts)
  (string-join (map (lambda (p) (format "~a" p)) parts) "."))

;; value->display : term -> hash
(define (value->display term)
  (match term
    [`(literal ,v) (literal->display v)]
    [`(fields ,entries) (record->display entries)]
    [`(uncertain ,v ,description)
     (hasheq 'kind "uncertain"
             'value (value->display v)
             'declared (sources description 'declared)
             'omitted (sources description 'omitted))]
    [_ (hasheq 'kind "expression" 'text (format "~a" term))]))

(define (literal->display v)
  (cond
    [(eq? v 'unknown) (hasheq 'kind "unknown" 'text "unknown")]
    [(boolean? v) (hasheq 'kind "boolean" 'text (if v "true" "false"))]
    [(real? v) (hasheq 'kind "number" 'text (number->display v))]
    [(string? v) (hasheq 'kind "text" 'text v)]
    [else (hasheq 'kind "expression" 'text (format "~a" v))]))

;; A record whose fields are one number and a text `unit` shows the number
;; with its unit, as in "1 m".
(define (record->display entries)
  (define fields
    (for/list ([entry (in-list entries)])
      (hasheq 'name (format "~a" (car entry)) 'value (value->display (cadr entry)))))
  (hasheq 'kind "record" 'fields (attach-unit fields)))

(define (numeric? v)
  (or (equal? (hash-ref v 'kind) "number")
      (and (equal? (hash-ref v 'kind) "uncertain")
           (equal? (hash-ref (hash-ref v 'value) 'kind) "number"))))

(define (attach-unit fields)
  (define unit-field
    (findf (lambda (f) (and (equal? (hash-ref f 'name) "unit")
                            (equal? (hash-ref (hash-ref f 'value) 'kind) "text")))
           fields))
  (define numbers (filter (lambda (f) (numeric? (hash-ref f 'value))) fields))
  (cond
    [(and unit-field (= 1 (length numbers)))
     (define unit (hash-ref (hash-ref unit-field 'value) 'text))
     (for/list ([f (in-list fields)] #:unless (eq? f unit-field))
       (if (eq? f (car numbers))
           (hash-set f 'value (with-unit (hash-ref f 'value) unit))
           f))]
    [else fields]))

(define (with-unit v unit)
  (if (equal? (hash-ref v 'kind) "uncertain")
      (hash-set v 'value (hash-set (hash-ref v 'value) 'unit unit))
      (hash-set v 'unit unit)))

(define (sources description which)
  (match description
    [`(fields ,entries)
     (match (assq which entries)
       [`(,_ (fields ,named))
        (for/list ([source (in-list named)])
          (define body (value->display (cadr source)))
          (hasheq 'name (format "~a" (car source))
                  'fields (if (equal? (hash-ref body 'kind) "record") (hash-ref body 'fields) '())))]
       [_ '()])]
    [_ '()]))

;; display->plain : hash -> string
;; A one-line plain text rendering, used for search and the booklet.
(define (display->plain v)
  (case (hash-ref v 'kind)
    [("number") (if (hash-has-key? v 'unit)
                    (string-append (hash-ref v 'text) " " (hash-ref v 'unit))
                    (hash-ref v 'text))]
    [("text") (format "\"~a\"" (hash-ref v 'text))]
    [("record")
     (string-append
      "["
      (string-join (for/list ([f (in-list (hash-ref v 'fields))])
                     (format "~a: ~a" (hash-ref f 'name) (display->plain (hash-ref f 'value))))
                   ", ")
      "]")]
    [("uncertain")
     (string-append (display->plain (hash-ref v 'value))
                    " ± "
                    (string-join (map (lambda (s) (hash-ref s 'name))
                                      (append (hash-ref v 'declared) (hash-ref v 'omitted)))
                                 ", "))]
    [else (hash-ref v 'text)]))
