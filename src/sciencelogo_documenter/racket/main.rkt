#lang racket/base
;; Entry point of the bundled Racket program. The Python launcher runs it.
;;
;;   main.rkt extract <entry>
;;     prints the documentation model as JSON.
;;   main.rkt build <entry> <settings.json> <site-dir> <work-dir>
;;     writes the website to <site-dir>, and booklet.typ with its template
;;     to <work-dir>, ready for Typst.

(require racket/file racket/path racket/port racket/runtime-path racket/string json
         "extract.rkt" "html.rkt" "typst.rkt")

(provide run)

(define-runtime-path package-dir "..")

(define usage
  "usage: main.rkt extract <entry> | build <entry> <settings.json> <site-dir> <work-dir>")

;; The model must hold no file paths: the documentation describes the method.
(define (check-no-paths doc entry)
  (define text (jsexpr->string doc))
  (define dir (path->string (path-only (path->complete-path entry))))
  (define trimmed (string-trim dir "/" #:left? #f))
  (when (and (> (string-length trimmed) 1) (string-contains? text trimmed))
    (error 'sciencelogo-documenter "internal error: a file path reached the documentation model")))

(define (extract entry)
  (define doc (extract-documentation entry))
  (for ([w (in-list (hash-ref doc 'warnings '()))])
    (eprintf "warning: ~a\n" w))
  (define clean (hash-remove doc 'warnings))
  (check-no-paths clean entry)
  clean)

(define (build entry settings-file site-dir work-dir)
  (define settings (call-with-input-file settings-file read-json))
  (define doc (extract entry))
  (make-directory* work-dir)
  (render-site doc settings site-dir
               (build-path package-dir "static")
               (build-path package-dir "fonts"))
  (copy-file (build-path package-dir "static" "template.typ") (build-path work-dir "template.typ") #t)
  (call-with-output-file (build-path work-dir "booklet.typ") #:exists 'replace
    (lambda (out) (write-booklet doc settings out)))
  (call-with-output-file (build-path work-dir "model.json") #:exists 'replace
    (lambda (out) (write-json doc out))))

;; run : (listof string) -> exact-nonnegative-integer
;; Runs one command and returns the process exit code.
(define (run args)
  (with-handlers ([exn:fail? (lambda (e)
                               (eprintf "~a\n" (exn-message e))
                               1)])
    (cond
      [(and (= (length args) 2) (equal? (car args) "extract"))
       (write-json (extract (cadr args)))
       (newline)
       0]
      [(and (= (length args) 5) (equal? (car args) "build"))
       (apply build (cdr args))
       0]
      [(null? args)
       (eprintf "~a\n" usage)
       2]
      [else
       (eprintf "unknown command: ~a\n~a\n" (car args) usage)
       2])))

(module+ main
  (exit (run (vector->list (current-command-line-arguments)))))
