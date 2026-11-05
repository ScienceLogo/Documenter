#lang racket/base
;; Documentation markers in the comments at the top of a library's entry file:
;;
;;   ; @doc url: https://example.org/my-library/
;;
;; A marker is `@doc <key>: <value>`. For each key the first marker wins, and
;; later ones are reported. Only `url` is used for now. A library without a
;; `url` marker is neither mapped nor documented.

(require racket/file racket/port racket/string racket/system)

(provide read-doc-markers
         library-doc-markers)

;; top-comments : string -> (listof string)
;; The text of the comments before the first form, after the #lang line.
(define (top-comments text)
  (define in (open-input-string text))
  (read-line in 'any)
  (let loop ([acc '()])
    (define c (peek-char in))
    (cond
      [(eof-object? c) (reverse acc)]
      [(char-whitespace? c) (read-char in) (loop acc)]
      [(char=? c #\;)
       (define line (read-line in 'any))
       (loop (cons (string-trim (if (eof-object? line) "" line) #rx";+" #:right? #f) acc))]
      [(equal? (peek-string 2 0 in) "#|")
       (read-string 2 in)
       (define body (read-block-comment in))
       (loop (append (reverse (string-split body "\n" #:trim? #f)) acc))]
      [else (reverse acc)])))

;; Reads a block comment after its opening #|, with nesting.
(define (read-block-comment in)
  (define out (open-output-string))
  (let loop ([depth 1])
    (define c (read-char in))
    (cond
      [(eof-object? c) (void)]
      [(and (char=? c #\|) (eqv? (peek-char in) #\#))
       (read-char in)
       (unless (= depth 1)
         (write-string "|#" out)
         (loop (sub1 depth)))]
      [(and (char=? c #\#) (eqv? (peek-char in) #\|))
       (read-char in)
       (write-string "#|" out)
       (loop (add1 depth))]
      [else (write-char c out) (loop depth)]))
  (get-output-string out))

(define marker-rx #px"@doc\\s+([A-Za-z][A-Za-z0-9_-]*)\\s*:\\s*(\\S(?:.*\\S)?)\\s*$")

;; read-doc-markers : string -> (values (hash/c string string) (listof string))
;; Returns the markers found in the top comments, and warnings.
(define (read-doc-markers text)
  (define markers (make-hash))
  (define warnings '())
  (for ([line (in-list (top-comments text))])
    (define m (regexp-match marker-rx line))
    (when m
      (define key (cadr m))
      (define value (caddr m))
      (cond
        [(hash-has-key? markers key)
         (set! warnings (cons (format "more than one @doc ~a marker; the first one is used" key) warnings))]
        [(and (equal? key "url") (not (regexp-match? #rx"^https?://[^ ]+$" value)))
         (set! warnings (cons (format "@doc url marker is not an http(s) URL: ~a" value) warnings))]
        [else (hash-set! markers key value)])))
  (values markers (reverse warnings)))

;; library-doc-markers : string string -> (values hash (listof string))
;; Reads library.rkt of the library at `url`, at `commit`, the way the
;; reference reader does, and returns its markers and warnings.
(define (library-doc-markers url commit)
  (define git (find-executable-path "git"))
  (define checkout (make-temporary-file "sciencelogo-documenter-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define (git-run . args)
        (define out (open-output-string))
        (define ok?
          (parameterize ([current-output-port out]
                         [current-error-port (open-output-nowhere)])
            (and git (apply system* git args))))
        (and ok? (get-output-string out)))
      (define text
        (and (git-run "clone" "--quiet" "--no-checkout" url (path->string checkout))
             (git-run "-C" (path->string checkout) "show" (string-append commit ":library.rkt"))))
      (if text
          (read-doc-markers text)
          (values (make-hash) (list (format "could not read the library at ~a" url)))))
    (lambda () (delete-directory/files checkout #:must-exist? #f))))
