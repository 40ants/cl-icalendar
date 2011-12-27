;; types.lisp ---
;;
;;     This file implements the iCalendar data types described in the
;;     RFC5545 and provide a plataform in order to add new data types.
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

;;; This file contains code which implements the values that iCalendar
;;; properties can take. We provide a data type specifier,
;;; constructor, accessors, and utilities functions for each one of
;;; them. Indeed, we provide 3 common functions in order to turn these
;;; objects to strings and vice versa.

(deftype ical-value ()
  '(or boolean integer float text binary uri geo cal-address utc-offset
    date time datetime duration period recur x-ical-value))

;;; Like `check-type' but it signals an error with %parse-error.
(defmacro check-ical-type (place type)
  (with-gensyms (vplace)
    `(let ((,vplace ,place))
       (unless (typep ,vplace ',type)
         (%parse-error "The ~a is not a ~a type." ',place ',type)))))

;;; Generic functions
(defgeneric format-value (value type &optional params))
(defgeneric parse-value (value type &optional params))

;;; Multiple-value versions

(defun parse-values (string type &optional params)
  (declare (symbol type))
  (labels (;; Find the position of the separator character (,) from
           ;; the character at START position.
           (position-separator (start)
             (let ((position (position #\, string :start start)))
               (if (and (integerp position)
                        (< 0 position)
                        (char= #\\ (char string (1- position))))
                   (position-separator (1+ position))
                   position))))
    ;; Collect values
    (loop for start = 0 then (1+ end)
          for end = (position-separator start)
          for sub = (subseq string start end)
          collect (parse-value sub type params)
          while end)))

(defun format-values (objects type &optional params)
  (flet ((format-value* (x) (format-value x params)))
    (join-strings (map1 #'format-value* type objects) #\,)))


;;; Wrapper for both standard as user-defined format-value and
;;; parse-value methods. The :around methods are used to implement
;;; global parameters.

;;; I am not sure if it is allowed by the iCalendar specification to
;;; use the encoding parameter on all types. I assume it is
;;; so. Otherwise it should be a method for BINARY data type.
;;; -- DVP

(defmethod format-value :around (object type &optional params)
  (let ((encoding (or (parameter :encoding params) "8BIT")))
    (cond
      ((string-ci= encoding "BASE64")
       (base64:string-to-base64-string (call-next-method)))
      ((string-ci= encoding "8BIT")
       (call-next-method))
      (t (error "Unkown encoding.")))))

(defmethod parse-value :around (string type &optional params)
  (let ((encoding (or (parameter :encoding params) "8BIT")))
    (cond
      ((string-ci= encoding "BASE64")
       (apply #'call-next-method (base64:base64-string-to-string string) type params))
      ((string-ci= encoding "8BIT")
       (call-next-method))
      (t (error "Unkown encoding.")))))


;;; Register a iCalendar data type in the standard vendor.
(defmacro register-ical-value (symbol &key (name (string symbol)) (specializer symbol))
  (check-type symbol symbol)
  (check-type name string)
  `(progn
     (setf (translate ,name :type) ',symbol)
     (defmethod value-typeof ((data ,specializer))
       ,name)))

;;;; Boolean

(register-ical-value boolean :specializer (eql 't))
(register-ical-value boolean :specializer (eql 'nil))
(define-predicate-type boolean)

(defmethod format-value (value (type (eql 'boolean)) &optional params)
  (declare (ignore params))
  (if value "TRUE" "FALSE"))

(defmethod parse-value (string (type (eql 'boolean)) &optional params)
  (declare (ignore params))
  (cond
    ((string-ci= string "TRUE")  t)
    ((string-ci= string "FALSE") nil)
    (t (%parse-error "~a is not a boolean data type." string))))


;;;; Integer

(register-ical-value integer)

(defmethod format-value (n (type (eql 'integer)) &optional params)
  (declare (ignore params))
  (format nil "~d" n))

(defmethod parse-value (string (type (eql 'integer)) &optional params)
  (declare (ignore params))
  (values (parse-integer string)))


;;;; Float

(register-ical-value float)

(defmethod format-value (value (type (eql 'float)) &optional params)
  (declare (ignore params))
  (format nil "~f" value))

(defmethod parse-value (string (type (eql 'float)) &optional params)
  (declare (ignore params))
  (let ((sign 1)                        ; the sign
        (x 0)                           ; integer part
        (y 0))                          ; fractional part
    (with-input-from-string (in string)
      ;; Read sign
      (case (peek-char nil in)
        (#\+
         (read-char in))
        (#\-
         (setf sign -1)
         (read-char in)))
      ;; Read integer part
      (let ((istring (read-until in (complement #'digit-char-p) nil nil)))
        (setf x (parse-integer istring)))
      ;; Read fractinal part (if any)
      (let ((dot (read-char in nil)))
        (unless (null dot)
          (unless (char= dot #\.)
            (%parse-error "Bad formed float."))
          (let ((fstring (read-until in (complement #'digit-char-p) nil nil)))
            (setf y (/ (float (parse-integer fstring))
                       (expt 10 (length fstring))))))))
    (* sign (+ x y))))


;;;; URI

(deftype uri () 'string)

(register-ical-value uri :specializer (eql 'uri))

(defmethod format-value (value (type (eql 'uri)) &optional params)
  (declare (ignore params))
  value)

(defmethod parse-value (string (type (eql 'uri)) &optional params)
  (declare (ignore params))
  string)


;;;; Geo

(defclass geo ()
  ((latitude
    :type float
    :initarg :latitude
    :reader latitude)
   (longitude
    :type float
    :initarg :longitude
    :reader longitude)))

(register-ical-value geo)
(define-predicate-type geo)

(defun make-geo (latitude longitude)
  (make-instance 'geo :latitude latitude :longitude longitude))

(defprinter (x geo)
  (format t "~d;~d" (latitude x) (longitude x)))

(defmethod format-value ((x geo) (type (eql 'geo)) &optional params)
  (declare (ignore params))
  (format nil "~d;~d" (latitude x) (longitude x)))

(defmethod parse-value (string (type (eql 'geo)) &optional params)
  (declare (ignore params))
  (let* ((parts (split-string string #\;))
         (length (length parts)))
    (unless (= 2 length)
      (%parse-error "Bad formed geo. 2 parts expected ~d found." length))
    (make-geo (parse-value (first parts) 'float)
              (parse-value (second parts) 'float))))

;;;; Cal-address

(deftype cal-address ()
  'string)

(register-ical-value cal-address :specializer (eql 'cal-address))

(defmethod format-value (string (type (eql 'cal-address)) &optional params)
  (declare (ignore params))
  string)

(defmethod parse-value (string (type (eql 'cal-address)) &optional params)
  (declare (ignore params))
  string)



;;; Unknown type. This is a pseudo-type. This is used to keep the
;;; value of non-defined property' values.

(defmethod format-value (string (type (eql 'nil-value)) &optional params)
  (declare (ignore params))
  string)

(defmethod parse-value (string (type (eql 'nil)) &optional params)
  (declare (ignore params))
  string)

;; User-defined iCalendar data types
(defclass x-ical-value ()
  nil)


;;; types.lisp ends here
