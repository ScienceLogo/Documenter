#lang racket/base
;; Small HTML helpers and the Markdown subset used in `about` texts:
;; paragraphs, `code`, *emphasis*, **strong** and [links](url).

(require racket/string)

(provide esc
         tag
         about->html
         about->plain)

;; esc : string -> string
(define (esc s)
  (let* ([s (string-replace s "&" "&amp;")]
         [s (string-replace s "<" "&lt;")]
         [s (string-replace s ">" "&gt;")]
         [s (string-replace s "\"" "&quot;")])
    s))

;; tag : symbol (listof (cons symbol string)) string ... -> string
;; Attribute values are escaped; children are already HTML.
(define (tag name attrs . children)
  (string-append
   "<" (symbol->string name)
   (apply string-append
          (for/list ([a (in-list attrs)] #:when (cdr a))
            (format " ~a=\"~a\"" (car a) (esc (cdr a)))))
   ">"
   (apply string-append children)
   (if (memq name '(meta link input br img)) "" (format "</~a>" name))))

(define (inline s)
  (let* ([s (esc s)]
         [s (regexp-replace* #rx"`([^`]+)`" s "<code>\\1</code>")]
         [s (regexp-replace* #rx"\\*\\*([^*]+)\\*\\*" s "<strong>\\1</strong>")]
         [s (regexp-replace* #rx"\\*([^*]+)\\*" s "<em>\\1</em>")]
         [s (regexp-replace* #rx"\\[([^]]+)\\]\\((https?://[^) ]+)\\)" s "<a href=\"\\2\">\\1</a>")])
    s))

;; about->html : string -> string
(define (about->html text)
  (apply string-append
         (for/list ([p (in-list (regexp-split #rx"\n\n" text))]
                    #:unless (string=? (string-trim p) ""))
           (tag 'p '() (inline (string-trim p))))))

;; about->plain : string -> string
(define (about->plain text)
  (let* ([s (regexp-replace* #rx"`([^`]+)`" text "\\1")]
         [s (regexp-replace* #rx"\\*\\*([^*]+)\\*\\*" s "\\1")]
         [s (regexp-replace* #rx"\\*([^*]+)\\*" s "\\1")]
         [s (regexp-replace* #rx"\\[([^]]+)\\]\\([^)]*\\)" s "\\1")])
    (string-normalize-spaces s)))
