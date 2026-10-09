(require :asdf)
(asdf:load-system "elmtui-workbench")
(elmtui.workbench.app:run-workbench
 :platform :terminal
 :platform-options '(:use-alternate-screen t :signal-keys-as-input t)
 :argv nil)
