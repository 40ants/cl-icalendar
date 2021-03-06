;; test-types.lisp
;;
;; Copyrigth (C) 2010 David Vázquez
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

(in-package :cl-icalendar-tests)

(in-suite icalendar-types)

;;; Boolean data type

(test parse-value-boolean-001
  "Parse some boolean values."
  (is (parse-value "true" 'boolean))
  (is (parse-value "TRUE" 'boolean))
  (is (parse-value "tRUE" 'boolean))
  (is (not (parse-value "false" 'boolean)))
  (is (not (parse-value "FALSE" 'boolean)))
  (is (not (parse-value "fAlse" 'boolean))))

(test parse-value-boolean-002
  "Parse some non-boolean values."
  (signals error (parse-value "23" 'boolean))
  (signals error (parse-value "t" 'boolean))
  (signals error (parse-value "true2" 'boolean))
  (signals error (parse-value "falses" 'boolean)))

(test format-value-boolean-001
  "Format some boolean values."
  (is (string= (format-value t 'boolean)   "TRUE"))
  (is (string= (format-value nil 'boolean) "FALSE")))


;;; Integer data type

(test parse-value-integer-001
  "Parse some integer values."
  (is (= 23   (parse-value "23" 'integer)))
  (is (= -123 (parse-value "-123" 'integer)))
  (is (= 0    (parse-value "0" 'integer))))

(test parse-value-integer-002
  "Parse some non-integer values."
  (signals error (parse-value "23.1" 'integer))
  (signals error (parse-value "2x" 'integer))
  (signals error (parse-value "++3" 'integer))
  (signals error (parse-value "--2" 'integer)))

(test format-value-integer-001
  "Format some integer values."
  (is (string= (format-value 2 'integer)  "2"))
  (is (string= (format-value 3 'integer)  "3"))
  (is (string= (format-value -3 'integer) "-3"))
  (is (string= (format-value 0 'integer)  "0")))


;;; Float data type

(test parse-value-float-001
  "Parse some float values."
  (is (= 23     (parse-value "23" 'float)))
  (is (= 3.1415 (parse-value "3.1415" 'float)))
  (is (= -0.001 (parse-value "-0.001" 'float))))

(test parse-value-float-002
  "Parse some non-integer values."
  (signals error (parse-value "23." 'float))
  (signals error (parse-value ".1"  'float))
  (signals error (parse-value "-.1" 'float)))

(test format-value-float-001
  "Format some integer values."
  (is (string= (format-value 2.0 'float) "2.0"))
  (is (string= (format-value 3.1 'float) "3.1"))
  (is (string= (format-value -3  'float) "-3.0")))

;;; Binary data type

(test read-binary-from-stream-001
  "Read somes binary from a stream."
  (finishes (read-binary-from-file "tests/test-types.001")))

(test parse-value-binary-001
  "Parse binary values."
  (is (= 446 (length (parse-value "TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2ljaW5nIGVsaXQsIHNlZCBkbyBlaXVzbW9kIHRlbXBvciBpbmNpZGlkdW50IHV0IGxhYm9yZSBldCBkb2xvcmUgbWFnbmEgYWxpcXVhLiBVdCBlbmltIGFkIG1pbmltIHZlbmlhbSwgcXVpcyBub3N0cnVkIGV4ZXJjaXRhdGlvbiB1bGxhbWNvIGxhYm9yaXMgbmlzaSB1dCBhbGlxdWlwIGV4IGVhIGNvbW1vZG8gY29uc2VxdWF0LiBEdWlzIGF1dGUgaXJ1cmUgZG9sb3IgaW4gcmVwcmVoZW5kZXJpdCBpbiB2b2x1cHRhdGUgdmVsaXQgZXNzZSBjaWxsdW0gZG9sb3JlIGV1IGZ1Z2lhdCBudWxsYSBwYXJpYXR1ci4gRXhjZXB0ZXVyIHNpbnQgb2NjYWVjYXQgY3VwaWRhdGF0IG5vbiBwcm9pZGVudCwgc3VudCBpbiBjdWxwYSBxdWkgb2ZmaWNpYSBkZXNlcnVudCBtb2xsaXQgYW5pbSBpZCBlc3QgbGFib3J1bS4=" 'binary)))))

(test format-value-binary-001
  "Format binary values."
  (is (string= (format-value (read-binary-from-file "tests/test-types.001") 'binary)
               "TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2ljaW5nIGVsaXQsIHNlZCBkbyBlaXVzbW9kIHRlbXBvciBpbmNpZGlkdW50IHV0IGxhYm9yZSBldCBkb2xvcmUgbWFnbmEgYWxpcXVhLiBVdCBlbmltIGFkIG1pbmltIHZlbmlhbSwgcXVpcyBub3N0cnVkIGV4ZXJjaXRhdGlvbiB1bGxhbWNvIGxhYm9yaXMgbmlzaSB1dCBhbGlxdWlwIGV4IGVhIGNvbW1vZG8gY29uc2VxdWF0LiBEdWlzIGF1dGUgaXJ1cmUgZG9sb3IgaW4gcmVwcmVoZW5kZXJpdCBpbiB2b2x1cHRhdGUgdmVsaXQgZXNzZSBjaWxsdW0gZG9sb3JlIGV1IGZ1Z2lhdCBudWxsYSBwYXJpYXR1ci4gRXhjZXB0ZXVyIHNpbnQgb2NjYWVjYXQgY3VwaWRhdGF0IG5vbiBwcm9pZGVudCwgc3VudCBpbiBjdWxwYSBxdWkgb2ZmaWNpYSBkZXNlcnVudCBtb2xsaXQgYW5pbSBpZCBlc3QgbGFib3J1bS4=")))

;;; Period type

(test parse-value-period-001
  (is (periodp (parse-value "19970101T180000Z/PT5H30M" 'period))))

(test parse-value-period-002
  (is (periodp (parse-value "19970101T180000Z/19970102T070000Z" 'period))))


;;; UTC Offset

(test parse-utc-offset-001
  ;; Positive
  (is (= (parse-value "+0530" 'utc-offset)  19800))
  (is (= (parse-value "-0530" 'utc-offset) -19800))
  (is (= (parse-value "-000001" 'utc-offset) -1))
  (is (= (parse-value "+0000" 'utc-offset) 0))
  (is (= (parse-value "+000000" 'utc-offset) 0))
  ;; Negative tests
  (signals error (parse-value "+0" 'utc-offset))
  (signals error (parse-value "-0" 'utc-offset))
  (signals error (parse-value "-0000" 'utc-offset))
  (signals error (parse-value "+05301" 'utc-offset))
  (signals error (parse-value "+053" 'utc-offset))
  (signals error (parse-value "5030" 'utc-offset)))

(test format-utc-offset-001
  ;; Positive
  (is (string= (format-value 19800 'utc-offset) "+0530"))
  (is (string= (format-value -19800 'utc-offset) "-0530"))
  (is (string= (format-value -1 'utc-offset) "-000001"))
  (is (string= (format-value 0 'utc-offset) "+0000"))
  ;; Negative tests
  (signals error (format-value -1000000 'utc-offset)))

;;; test-types.lisp ends here

