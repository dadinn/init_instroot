#!/usr/bin/guile \
-e main -s
!#

(use-modules
 (ice-9 getopt-long)
 (ice-9 regex)
 (ice-9 rdelim)
 (ice-9 popen))

(define (create-keyfile f)
  (let ((fname (basename f)))
    (if (file-exists? fname)
	(throw 'file-already-exists fname)
	(system* "dd" "if=/dev/random" (string-append "of=" fname) "bs=1024" "count=4"))))

(define (partuuid path n)
  (if (eq? 'block-special (stat:type (stat path)))
      (let* ((opt (string-join (list "sgdisk" "-i" (number->string n) path) " "))
	     (in (open-input-pipe opt))
	     (text (read-string in))
	     (match (string-match "Partition unique GUID: ([0-9A-F-]+).*$" text)))
	(close in)
	(match:substring match 1))
      (error (string-append "Not a block device: " path))))

(define deps-base
  (list "sgdisk" "partprobe" "cryptsetup" "pv" "pvcreate" "vgcreate" "lvcreate"))

(define (which acc args)
  (if (not (null? args))
      (let ((curr (car args)))
	(if (zero? (system* "which" curr))
	    (which acc (cdr args))
	    (which (cons curr acc) (cdr args))))
      acc))

(define (install-deps-base)
  (let ((missing (which #nil deps-base)))
    (if (not (null? missing))
	(if (file-exists? "/etc/debian_version")
	    (begin
	      (display "Installing necessary packages...")
	      (system "apt update")
	      (system "apt install -y gdisk parted cryptsetup pv lvm2"))
	    (error "Necessary binaries are missing" missing)))))

(define* (usage #:rest args)
  (display "Here is some help!")
  (newline))

(define options-spec
  `((target ; default "/mnt/instroot"
     (single-char #\t)
     (value #t))
    (label ; default "crypt_root"
     (single-char #\l)
     (value #t))
    (keyfile
     (single-char #\k)
     (predicate
      ,(lambda (s) (file-exists? s)))
     (value #t))
    (genkey
     (single-char #\K)
     (value #t))
    (zpool
     (single-char #\z)
     (value #t))
    (initdeps
     (single-char #\Z)
     (value #f))
    (rootfs ; default "system"
     (single-char #\r)
     (value #t))
    (dirlst ; default "home,var,gnu"
     (single-char #\d)
     (value #t))
    (devlst
     (single-char #\c)
     (value #t))
    (swapsize
     (single-char #\s)
     (predicate
      ,(lambda (s) (string-match "^[0-9]+[KMGT]?$" s)))
     (value #t))
    (swapfiles
     ;; default 0
     (single-char #\S)
     (value #t))
    (help
     (single-char #\h)
     (value #f))))

(define (main args)
  (let ((options (getopt-long args options-spec)))
    (let ((target (option-ref options 'target "/mnt/instroot"))
	  (label (option-ref options 'label "crypt_root"))
	  (keyfile (option-ref options 'keyfile #f))
	  (new-keyfile (option-ref options 'genkey #f))
	  (zpool (option-ref options 'zpool #f))
	  (initdeps? (option-ref options 'initdeps #f))
	  (rootfs (option-ref options 'rootfs "system"))
	  (dirlst (option-ref options 'dirlst "home,var,gnu"))
	  (devlst (option-ref options 'devlst '()))
	  (swapsize (option-ref options 'swapsize #f))
	  (swapfiles (option-ref options 'swapfiles 0))
	  (help? (option-ref options 'help #f)))
      (cond
       (help?
	(usage))
       (new-keyfile
	(if (not (file-exists? new-keyfile))
	    (create-keyfile new-keyfile)
	    (error "File already exists:" new-keyfile)))))))
