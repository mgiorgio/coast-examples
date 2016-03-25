#lang racket/base

(require
  Island/include/base
  Island/baseline
  Island/transport/gate
  Island/transport/gates/whitelist)

(define CERTIFICATE/PUBLIC "./certificates/public/")
(define CERTIFICATE/SECRET "./certificates/secret/")
(define ALICE/SECRET/PATH (string-append CERTIFICATE/SECRET "alice_secret"))
(define BOB/SECRET/PATH   (string-append CERTIFICATE/SECRET "bob_secret"))
(define CAROL/SECRET/PATH (string-append CERTIFICATE/SECRET "carol_secret"))

;; Alice's, Bob's and Carol's public keys.
(define ALICE/KP/BASE64 #"wdvbN1svfhEAewhM76oSVPKj-4kzfbDhaiTFW61VdUc")
(define BOB/KP/BASE64   #"49u_B0VEdFFS3WCPMMX5T5MFQ3SaSHjM8fM63I4L338")
(define CAROL/KP/BASE64 #"rqM_XCwrsziuhIEsG1d0yMA05mivoewXhUmzKUzhb0s")

;; Create a Keystore to store the public certificates of other islands.
(define KEYSTORE (keystore/new))
;; Download all of the predefined public certificates.
(keystore/load KEYSTORE CERTIFICATE/PUBLIC)

(define ALICE/CURVE/SECRET (path-to-curve ALICE/SECRET/PATH))
(define BOB/CURVE/SECRET   (path-to-curve BOB/SECRET/PATH))
(define CAROL/CURVE/SECRET (path-to-curve CAROL/SECRET/PATH))

;; The textual representation of the CURL for Alice's echo service.
(define/curl/inline ALICE/CURL/ECHO
  #<<!!
SIGNATURE = #"Nxm6zGGiZDiao5vc8aYfdEeOIME104GEeOt4_K3ys2xDP673elLrwWa56SKAWp7gR2RI25QKZW0NvB2i23NJCg"
CURL
    id = 2eac24e1-f4fb-440d-a771-b3b60266a982
    origin = #"wdvbN1svfhEAewhM76oSVPKj-4kzfbDhaiTFW61VdUc"
    path = (echo)
    access/id = access:send:echo
    created = "2014-05-17T16:17:17Z"
    metadata = #f

!!
  )

;; Echo Service Client bootstrap function.
;; alice/curl is the CURL for Alice's service.
(define (client/boot alice/curl)
  ; Wait until the client sees Alice.
  (island/enter/wait ALICE/KP/BASE64)
  
  ; Create a CURL that the Echo Server (Alice) will use to send the response.
  (let ([p (promise/new)])
    ; Send a pair with the message and the CURL to receive it back.
    (send alice/curl (cons (promise/resolver p) (format "Hi, this is ~a!" (island/nickname (this/island)))))
    ; Wait for the response.
    (let* ([m (promise/block p)]
           [message (murmur/payload m)])
      ; Show the response.
      (display message))))

;; Bootstrap function for Alice who offers an Echo Service.
(define (alice/boot)
  ; Define a (service/echo) function.
  (define (service/echo)
    ; Create a duplet to receive messages via Alice's CURL.
    ; Notice the use of (islet/curl/known/new). We use this function because it is a known CURL, we are not creating a brand new CURL.
    ; '(echo) is the service path (it must be the same as the one in the textual representation)
    ; 'access:send:echo is the access id (it must be the same as the one in the textual representation)
    ; The (gate/whitelist/island) function creates a gate that only lets pass messages coming from a specific set of islands.
    (let ([server/duplet (islet/curl/known/new '(echo) 'access:send:echo (gate/whitelist/island BOB/KP/BASE64) environ/null)])
      ; Wait for messages.
      (let loop ([m (duplet/block server/duplet)])
        ; Get the murmur's payload.
        (let ([payload (murmur/payload m)])
          ; Verify that what the server received is well-formed.
          (when (and
                 ; It is a pair.
                 (pair? payload)
                 ; Left element is a CURL.
                 (curl? (car payload))
                 ; Right element is a string.
                 (string? (cdr payload)))
            ; Send it back.
            (send (car payload) (cdr payload))))
        (loop (duplet/block server/duplet)))))
  
  (service/echo))

;; Create an in-memory CURL from the textual representation.
(define alice/curl/echo (curl/zpl/safe-to-curl ALICE/CURL/ECHO KEYSTORE))

;; Instantiate Alice and Bob.
(define alice (island/new 'alice ALICE/CURVE/SECRET alice/boot))
(define bob (island/new 'bob BOB/CURVE/SECRET (lambda () (client/boot alice/curl/echo))))
(define carol (island/new 'carol CAROL/CURVE/SECRET (lambda () (client/boot alice/curl/echo))))

;; Set Alice's, Bob's, and Carol's keystore. Since both islands are in the same address space, they can share the keystore.
(island/keystore/set alice KEYSTORE)
(island/keystore/set bob   KEYSTORE)
(island/keystore/set carol   KEYSTORE)

(define (example/halt)
  (island/destroy alice)(island/destroy bob)(island/destroy carol))

(island/log/level/set 'warning)