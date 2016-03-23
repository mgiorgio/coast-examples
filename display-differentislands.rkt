#lang racket/base

(require
  Island/include/base
  Island/baseline
  Island/transport/gate)

(define CERTIFICATE/PUBLIC "./certificates/public/")
(define CERTIFICATE/SECRET "./certificates/secret/")
(define ALICE/SECRET/PATH (string-append CERTIFICATE/SECRET "alice_secret"))
(define BOB/SECRET/PATH   (string-append CERTIFICATE/SECRET "bob_secret"))

(define ALICE/CURVE/SECRET (path-to-curve ALICE/SECRET/PATH))
(define BOB/CURVE/SECRET   (path-to-curve BOB/SECRET/PATH))

;; Alice's public key.
(define ALICE/KP/BASE64 #"wdvbN1svfhEAewhM76oSVPKj-4kzfbDhaiTFW61VdUc")

;; Create a Keystore to store the public certificates of other islands.
(define KEYSTORE (keystore/new))
;; Download all of the predefined public certificates.
(keystore/load KEYSTORE CERTIFICATE/PUBLIC)

;; The textual representation of the CURL for Alice's display service.
(define/curl/inline ALICE/CURL/DISPLAY
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

;; Bob's bootstrap function.
;; alice/curl is the CURL for Alice's service.
(define (bob/boot alice/curl)
  ; Wait until Bob sees Alice.
  (island/enter/wait ALICE/KP/BASE64)
  ; Send message.
  (send alice/curl "Hi, this is Bob!"))

;; Bootstrap function for Alice who offers a display service.
(define (alice/boot)
  ; Define a (service/display) function.
  (define (service/display)
    ; Create a duplet to receive messages via Alice's CURL.
    ; Notice the use of (islet/curl/known/new). We use this function because it is a known CURL, we are not creating a brand new CURL.
    ; '(echo) is the service path (it must be the same as the one in the textual representation)
    ; 'access:send:echo is the access id (it must be the same as the one in the textual representation)
    (let ([server/duplet (islet/curl/known/new '(echo) 'access:send:echo GATE/ALWAYS environ/null)])
      (let loop ([m (duplet/block server/duplet)])
        (let ([payload (murmur/payload m)])
          (display payload)))))
          
  (service/display))

;; Create an in-memory CURL from the textual representation.
(define alice/curl/display (curl/zpl/safe-to-curl ALICE/CURL/DISPLAY KEYSTORE))

;; Instantiate Alice and Bob.
(define alice (island/new 'alice ALICE/CURVE/SECRET alice/boot))
(define bob (island/new 'bob BOB/CURVE/SECRET (lambda () (bob/boot alice/curl/display))))

(island/log/level/set 'warning)