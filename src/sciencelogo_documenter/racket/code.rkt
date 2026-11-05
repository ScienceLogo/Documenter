#lang racket/base
;; Marks the structure of verbose ScienceLogo text, for the website and the
;; booklet: structure words, inputs, outputs, and the names of stages,
;; procedures and performers. Strings and comments are left as they are.

(require racket/list racket/string)

(provide code-lines)

;; Words that open, close or connect the parts of a method.
(define structure-words
  '("start" "end" "stage" "from" "state" "do" "with" "into" "output" "about" "by"
    "workflow" "performer" "resource" "interface" "hypothesis" "assumption" "conclusion"
    "must" "import" "include" "library" "repeat" "while" "for" "each" "if" "else" "until"))

(define token-rx #px"\"(?:[^\"\\\\]|\\\\.)*\"|;[^\n]*|[^\\s\\[\\]()\"]+|\n|[ \t]+|.")

(define (word? t) (regexp-match? #px"^[^\\s\\[\\]()\";]" t))

;; code-lines : string (hash/c string symbol) -> (listof (listof (cons (or/c symbol #f) string)))
;; Splits `text` into lines of classified tokens. `names` maps the names of
;; stages, procedures and performers to 'stage, 'procedure or 'performer.
;; The other classes are 'keyword, 'input and 'output.
(define (code-lines text names)
  (define tokens (regexp-match* token-rx text))
  (define vec (list->vector tokens))
  (define n (vector-length vec))
  ;; The next word after position i on the same line, if any.
  (define (next-word i)
    (let loop ([j (add1 i)])
      (cond
        [(>= j n) #f]
        [(equal? (vector-ref vec j) "\n") #f]
        [(word? (vector-ref vec j)) (vector-ref vec j)]
        [(regexp-match? #px"^[ \t]+$" (vector-ref vec j)) (loop (add1 j))]
        [else #f])))
  (define-values (lines current _line-start? _mode)
    (for/fold ([lines '()] [current '()] [line-start? #t] [mode #f])
              ([t (in-vector vec)] [i (in-naturals)])
      (cond
        [(equal? t "\n") (values (cons (reverse current) lines) '() #t #f)]
        [(regexp-match? #px"^[ \t]+$" t) (values lines (cons (cons #f t) current) line-start? mode)]
        [(not (word? t))
         ;; Strings, comments and brackets. A bracket ends an output location.
         (values lines (cons (cons (and (eq? mode 'output) (regexp-match? #rx"^\"" t) 'output) t) current)
                 #f (if (member t '("[" "]")) #f mode))]
        [else
         (define class
           (cond
             [(hash-ref names t #f)]
             [(and (equal? t "to") line-start?) 'keyword]
             [(member t structure-words) 'keyword]
             [(eq? mode 'output) 'output]
             [(regexp-match? #rx"^:" t) 'input]
             [(equal? (next-word i) "at") 'input]
             [else #f]))
         (define next-mode
           (cond
             [(member t '("into" "output")) 'output]
             [else mode]))
         (values lines (cons (cons class t) current) #f next-mode)])))
  (reverse (if (null? current) lines (cons (reverse current) lines))))
