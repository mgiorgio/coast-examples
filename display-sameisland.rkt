#lang racket/base

(require
  Island/include/base
  Island/baseline
  Island/transport/gate)

(define CERTIFICATE/SECRET "./certificates/secret/")
(define ALICE/SECRET/PATH (string-append CERTIFICATE/SECRET "alice_secret"))

(define ALICE/CURVE/SECRET (path-to-curve ALICE/SECRET/PATH))

;; Create a box with a dummy value inside.
(define curl-box (box #f))

;; Define the bootstrap computation for Alice
(define (alice/boot)
  
  ;; This is the function for the Display Service at Alice. It creates a duplet containing the CURL used to communicate.
  (define (server/listen)
    ;; Create a duplet (containing a CURL). A couple of points about this:
    ;; 1) '(echo alice) is the service path.
    ;; 2) GATE/ALWAYS means that there are no constraints to use this CURL.
    ;; 3) #f means that no metadata is attached to the CURL.
    ;; 4) 'INTRA means that the CURL can only be used within Alice (it is intra-Island).
    (let ([display/duplet (islet/curl/new '(echo alice) GATE/ALWAYS #f 'INTRA)])
      
      ;; Put the CURL into the box (duplet/resolver extracts a CURL from a duplet)
      (set-box! curl-box (duplet/resolver display/duplet))
      
      ;; Listen for messages coming through the CURL. It blocks on the duplet's CURL until a message arrives, then it blocks back.
      (let loop ([m (duplet/block display/duplet)])
        ;; Extract the actual message (i.e. the murmur's payload)
        (let ([message (murmur/payload m)])
          ;; Show the message.
          (display message))
        (loop (duplet/block display/duplet)))))
  
  ;; This is a function that uses the sender to send its message through the boxed CURL.
  (define (sender/send)
    (send (unbox curl-box) (format "Hi, I am ~a, and I also run in Alice!" (islet/nickname (this/islet)))))
  
  ;; This function creates and executes the sender.
  (define (spawn/sender)
    ;; (islet/new) creates a new islet in the current island:
    ;; 1) (this/island) returns the current island.
    ;; 2) 'message.sender is the nickname of the new islet.
    ;; 3) TRUST/MODERATE defines the level of trust granted to the new islet.
    ;; 4) BASELINE/SPAWN is the Execution Site global binding environment.
    ;; 5) environ/null is an islet-specific binding environment.
    (let ([x (islet/new (this/island) 'message.sender TRUST/MODERATE BASELINE/SPAWN environ/null)])
      ;; Launch the new islet with the sender/send function.
      (islet/jumpstart x sender/send)))
  
  ;; This function creates an executes the Display Server.
  (define (spawn/server)
    ;; Similar to the previous function but uses 'echo.server as the nickname.
    (let ([x (islet/new (this/island) 'echo.server TRUST/MODERATE BASELINE/SPAWN environ/null)])
      (islet/jumpstart x server/listen)))
  
  ;; Call the functions defined above.
  (spawn/server)
  (sleep 1.0)
  (spawn/sender))

(define alice (island/new 'alice ALICE/CURVE/SECRET alice/boot))