#!/usr/bin/guile-2.0 \
-e main -s
!#

(use-modules (ice-9 rdelim))
(use-modules (ice-9 popen))
(use-modules (ice-9 match))
(use-modules (ice-9 threads))
(use-modules (srfi srfi-1))
(use-modules (srfi srfi-26))

(define debug-messages #f)

(define (debug . args)
  (and debug-messages
       (apply format (current-error-port) args)))

(define config
  (let* ((home (passwd:dir (getpw (getuid))))
         (sep file-name-separator-string)
         (config-file (string-append home sep ".remote-manager.conf")))
    (with-input-from-file config-file read)))


(define* (run-command command . args)
  (define (read-all port)
    (let lp ((new-data (read-line port 'concat)) (concatenated-output ""))
      (if (eof-object? new-data)
        concatenated-output
        (lp (read-line port 'concat)
            (string-append new-data concatenated-output)))))

  (debug "Running command: ~A\n" (cons command args))
  (let* ((port (open-input-pipe (string-join (cons command args))))
         (output (read-all port))
         (return-value (status:exit-val (close-pipe port))))
    (cons return-value output)))

(define* (ssh-impl host command #:key (user #f))
 (run-command "ssh"
              (if user (format #f "~A@~A" user host) host)
              command))

(define* (ssh host command #:key (user #f))
 (match (ssh-impl host command #:user user)
  ((return-value . output)
    (or (eqv? return-value 0)
        (begin
          (format #t "Warning: command failed (~A): ~A"
                  return-value output)
          #f)))))

(define (get-default config key)
  (let ((defaults (or (assq-ref config 'default)
                      (error "bad config: no defaults"))))
    (assq-ref defaults key)))

(define (config-host-key config host-id key)
  (let* ((hosts (or (assq-ref config 'hosts) (error "bad config: no hosts")))
         (host-entry (or (assoc-ref hosts host-id)
                         (error "bad config: no entry for" host-id))))
    (or (assq-ref host-entry key)
        (get-default config key)
        (error "bad config: could not find key " key "for host" host-id))))

(define (config-proxy config)
  (or (assq-ref config 'proxy) (error "no proxy")))

(define (wake-up-impl proxy mac-address)
  (ssh proxy (format #f "wakeonlan ~A" mac-address)))

(define (wake-up config host-id)
 (ensure-connected config)
 (wake-up-impl
   (config-proxy config)
   (config-host-key config host-id 'mac)))

(define (halt config host-id)
  (define (get-val key) (config-host-key config host-id key))

  (ensure-connected config)
  (ssh (get-val 'hostname) (get-val 'halt-command) #:user "root"))

(define (suspend config host-id)
  (define (get-val key) (config-host-key config host-id key))

  (ensure-connected config)
  (ssh (get-val 'hostname) (get-val 'suspend-command)))


(define (ping config host-id)
 (ensure-connected config)
 (match (run-command "ping -c 1"
                     (config-host-key config host-id 'hostname))
        ((retval . _)
         (eqv? retval 0))))

(define (for-each-host config proc)
  (let ((hosts (or (assq-ref config 'hosts) (error "no hosts in config"))))
    (par-for-each (lambda (host-entry) (proc config (car host-entry))) hosts)))

(define (nm-check-connection connection-name)
  (match (run-command "nmcli -t -f name connection status")
         ((0 . output)
          (and (find (cut equal? connection-name <>)
                     (string-split output #\newline))
               #t))
         ((ret . output)
          (error "Something happened when running nmcli:" ret output))))

(define (nm-connect connection-name)
  (match (run-command "nmcli connection up id " connection-name)
         ((0 . _) *unspecified*)
         ((ret . output)
          (error "Could not connect to connection"
                 connection-name ret output))))

(define (ensure-connected config)
  (let ((connection-name (get-default config 'need-connection)))
   (and connection-name
        (not (nm-check-connection connection-name))
        (nm-connect connection-name))))

(define (main args)
  (define (ping-action config host-id)
   (debug "Checking the availability of ~A...\n" host-id)
   (format #t "~A is ~A\n"
           host-id
           (if (ping config host-id) "up" "down")))

  (match args
         ((_ "ping" host-id)
          (ping-action config host-id))
         ((_ "ping-all")
          (for-each-host config ping-action))
         ((_ "start" host-id)
          (format #t "Attempting to wake up ~A...\n" host-id)
          (wake-up config host-id))
         ((_ "stop" host-id)
          (format #t "Attempting to stop ~A...\n" host-id)
          (halt config host-id))
         ((_ "suspend" host-id)
          (format #t "Attempting to suspend ~A...\n" host-id)
          (suspend config host-id))
         ((cl . _)
          (let (( e (current-error-port)))
           (format e "Usage: ~A command arg...\n" cl)
           (format e "Available commands:\n")
           (format e "  ping host-id\n")
           (format e "  ping-all\n")
           (format e "  start host-id\n")
           (format e "  stop host-id\n")
           (format e "  suspend host-id\n")))))
