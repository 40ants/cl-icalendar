;; types-text.lisp ---
;;
;; Copyrigth (C) 2009, 2010 Mario Castelán Castro <marioxcc>
;; Copyrigth (C) 2009, 2010 David Vázquez
;;
;; This file is part of cl-icalendar.
;;
;; cl-icalendar is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; cl-icalendar is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with cl-icalendar.  If not, see <http://www.gnu.org/licenses/>.

(in-package :cl-icalendar)

(defclass text* ()
  ((language
    :initarg :language
    :initform nil
    :reader text-language)
   (string
    :initarg :text
    :reader text)))

(deftype text ()
  '(or string text*))

(define-predicate-type text)

(defmethod print-object ((x text*) stream)
  (print-unreadable-object (x stream)
    (format stream "TEXT :LANG ~a ~w"
            (text-language x)
            (text x))))

(defmethod text ((x string))
  x)

(defmethod text-language ((x string))
  nil)

(defun make-text (string &optional language)
  (if language
      (make-instance 'text* :text string :language language)
      string))

(defmethod format-value ((text string) &rest params &key &allow-other-keys)
  (declare (ignore params))
  (with-input-from-string (in text)
    (with-output-to-string (out)
      (loop for ch = (read-char in nil)
            while ch
            do
         (cond
           ((char= ch #\newline)
            (write-char #\\ out)
            (write-char #\n out))
           ((char= ch #\\)
            (write-char #\\ out)
            (write-char #\\ out))
           ((char= ch #\,)
            (write-char #\\ out)
            (write-char #\, out))
           ((char= ch #\;)
            (write-char #\\ out)
            (write-char #\; out))
           (t
            (write-char ch out)))))))


(defmethod format-value ((text text*) &rest params &key &allow-other-keys)
  (declare (ignore params))
  (format-value (text text)))


(defmethod parse-value (text (type (eql 'text)) &rest params &key &allow-other-keys)
  (declare (ignore params))
  (let ((string (text text)))
    (with-input-from-string (in string)
      (with-output-to-string (out)
        (loop for ch = (read-char in nil)
              while ch
              do
           (write-char (if (char/= ch #\\)
                           ch
                           (ecase (read-char in nil)
                             (#\\ #\\)
                             (#\; #\;)
                             (#\, #\,)
                             (#\N #\newline)
                             (#\n #\newline)))
                 out))))))

;;; types-text.lisp ends here