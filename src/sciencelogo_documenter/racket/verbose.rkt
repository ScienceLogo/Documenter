#lang racket/base
;; The verbose text of each top-level item, cut from the reference translator's
;; output by the source positions that the translator reports for each character.

(require racket/file racket/string sciencelogo/normalize)

(provide make-verbose-cutter)

;; make-verbose-cutter : -> (string natural (or/c natural #f) -> string)
;; The returned procedure takes a source file, the start position of an item and
;; the start position of the next item in that file (or #f), and returns the
;; verbose text of the item. Each file is translated once.
(define (make-verbose-cutter)
  (define translations (make-hash))
  (define (translation file)
    (hash-ref! translations file
               (lambda ()
                 (define result (translate-source (file->string file) #:to 'verbose
                                                  #:source (string->path file)))
                 (define text (normalized-source-text result))
                 ;; Origins are one-based: character i has origin i + 1.
                 (define positions
                   (for/vector #:length (string-length text) ([i (in-range (string-length text))])
                     (define origin (normalized-source-origin result (add1 i)))
                     (and origin
                          (equal? (format "~a" (source-origin-source origin)) file)
                          (source-origin-position origin))))
                 (cons text positions))))
  (lambda (file start end)
    (define t (translation file))
    (define text (car t))
    (define positions (cdr t))
    (define (inside? i)
      (define p (vector-ref positions i))
      (and p (>= p start) (or (not end) (< p end))))
    (define first (for/first ([i (in-range (string-length text))] #:when (inside? i)) i))
    (define last (for/last ([i (in-range (string-length text))] #:when (inside? i)) i))
    (if first
        (string-trim (substring text first (add1 last)) #:left? #f)
        "")))
