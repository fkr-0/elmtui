(require "asdf")
(load "elmtui.asd")
(asdf:load-system "elmtui")
(elmtui.examples.runner:main (uiop:command-line-arguments))
