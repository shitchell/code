// ==UserScript==
// @name         Fix YT Comments
// @namespace    http://tampermonkey.net/
// @version      2024-07-28
// @description  try to take over the world!
// @author       You
// @match        https://www.youtube.com/watch?*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=youtube.com
// @grant        unsafeWindow
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    unsafeWindow.yt.config_.EXPERIMENT_FLAGS.kevlar_watch_grid=false
    unsafeWindow.yt.config_.EXPERIMENT_FLAGS.kevlar_watch_max_player_width=1280
})();