// ==UserScript==
// @name         Autodraw Undo
// @namespace    http://tampermonkey.net/
// @version      2024-03-30
// @description  try to take over the world!
// @author       You
// @match        https://www.autodraw.com/
// @icon         https://www.google.com/s2/favicons?sz=64&domain=autodraw.com
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    document.addEventListener('keydown', function(event) {
        if (event.ctrlKey && event.key === 'z') {
            console.log('Undo!');
            document.querySelector("div.tool.undo").click()
        }
    });
})();