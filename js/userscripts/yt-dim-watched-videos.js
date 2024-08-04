// ==UserScript==
// @name         Dim Watched YouTube Videos
// @namespace    http://tampermonkey.net/
// @version      0.2
// @description  Dim the thumbnails of watched videos on YouTube
// @author       Shaun Mitchell <shaun@shitchell.com>
// @match        https://www.youtube.com/*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=youtube.com
// @require      https://openuserjs.org/src/libs/sizzle/GM_config.js
// @grant        GM_registerMenuCommand
// @grant        GM.getValue
// @grant        GM.setValue
// @license      WTFPL
// @downloadURL  https://update.greasyfork.org/scripts/502576/Dim%20Watched%20YouTube%20Videos.user.js
// @updateURL    https://update.greasyfork.org/scripts/502576/Dim%20Watched%20YouTube%20Videos.meta.js
// ==/UserScript==

/** Dim Watched YouTube Videos *************************************************

# What it does

This script will dim the thumbnails of watched videos on YouTube.

# Why?

This makes it easier to identify videos that you haven't watched yet. Especially
on a channel that you watch frequently, it can be hard to parse through all the
videos to find the ones you haven't watched yet. This makes those unwatched
videos stand out while the watched videos fade into the background.

# Settings

This script uses GM_config to manage settings. You can access the settings by
clicking the "Open Settings" button in the Userscript manager. The following
settings are available:

## thumbnail_opacity (default: 0.3)

This is the opacity of the thumbnail when the video has been watched. Values
must be a decimal between 0-1. Lower values result in more transparent/faded
thumbnails. If relative opacity is enabled, the opacity of a video will be
determined by this value + the percentage of the video watched. i.e.: fully
watched videos will be set to this opacity, but partially watched videos will be
less transparent. e.g.:

- if relative_opacity == true && thumbnail_opacity == 0.5:
    - 100% watched = 0.5 opacity (the full value of thumbnail_opacity)
    - 75% watched = 0.625 opacity
    - 50% watched = 0.75 opacity
    - 25% watched = 0.875 opacity
    - 0% watched = 1.0 opacity (fully visible)
- if relative_opacity == false && thumbnail_opacity == 0.5:
    - 100% watched = 0.5 opacity
    - 75% watched = 0.5 opacity
    - 50% watched = 0.5 opacity
    - 25% watched = 0.5 opacity
    - 0% watched = 0.5 opacity

## use_relative_opacity (default: true)

If true, enables relative opacity, and thumbnail opacity will be determined
relative to the video watch time. If false, the thumbnail opacity will be set
to a fixed value for all watched videos, regardless of how much of the video
has been watched.

## min_watched (default: 0)

The minimum percentage of the video that must be watched for the thumbnail to
be dimmed. If the video has been watched less than this percentage, the
thumbnail will be set to full opacity. e.g.:

- if min_watched == 50:
    - 100% watched = dimmed
    - 75% watched = dimmed
    - 50% watched = dimmed
    - 25% watched = not dimmed
    - 0% watched = not dimmed
*******************************************************************************/


/*******************************************************************************
 Global variables and default configuration
*******************************************************************************/

var DEFAULT_CONFIG = {
    use_relative_opacity: true,
    thumbnail_opacity: 0.3,
    min_watched: 0,
    debug: false
}
var seenQuerySelectors = [
    "ytd-thumbnail-overlay-resume-playback-renderer > div#progress"
];
var parentThumbnailSelectors = [
    "ytd-thumbnail",
    "div#thumbnail.ytd-rich-grid-media"
]


/*******************************************************************************
 Configuration management
*******************************************************************************/

/** GM_config setup
*******************************************************************************/

GM_config.init({
    id: 'MyScriptConfig',
    fields: {
        use_relative_opacity: {
            label: 'Use relative opacity',
            type: 'checkbox',
            default: DEFAULT_CONFIG.use_relative_opacity
        },
        thumbnail_opacity: {
            label: 'Thumnbail opacity',
            type: 'float',
            default: DEFAULT_CONFIG.thumbnail_opacity
        },
        min_watched: {
            label: 'Minimum percentage watched',
            type: 'int',
            default: DEFAULT_CONFIG.min_watched
        },
        debug: {
            label: 'Debug mode',
            type: 'checkbox',
            default: DEFAULT_CONFIG.debug
        }
    },
    events: {
        save: function() {
            // handle saving the values
        }
    }
});

// To open the settings panel, navigate to the browser's Userscript manager
GM_registerMenuCommand('Open Settings', () => GM_config.open(), 'o');

/** GM_config helper function for async/init
*******************************************************************************/

/**
 * Retrieve a config value
 *
 * This function will retrieve a configuration value from the GM_config object
 * or the default config list if GM_config is not yet initialized. Yay async.
 *
 * @param {String} key  The key of the configuration value to retrieve
 * @returns {any}       The value of the configuration key
 */
function getConfig(key) {
    let source;
    let value;
    if (GM_config.isInit) {
        value = GM_config.get(key);
        source = "GM_config";
    } else {
        value = DEFAULT_CONFIG[key];
        source = "default"
    }
    debug(`retrieved ${source} config {${key}: ${value}}`);
    return value;
}


/*******************************************************************************
 Utility functions
*******************************************************************************/

/**
 * Log a message to the console if debug mode is enabled
 *
 * This function will log a message to the console if debug mode is enabled in
 * the configuration. If debug mode is disabled, the message will not be logged.
 *
 * @param {String} mode  Console method to use (e.g. "log", "warn", "error")
 * @param {any[]} args   Arguments to log to the console
 * @returns {void}
 */
function log(mode, ...args) {
    let debugEnabled = (GM_config.isInit && GM_config.get("debug") === true);
    // If the first argument is not a console log method, default to "log" and
    // add "mode" to the arguments list
    if (!["log", "info", "warn", "error"].includes(mode)) {
        args.unshift(mode);
        mode = "log";
    }
    if (debugEnabled) {
        console[mode](
            `%c[${GM_info.script.name} | ${mode}]`,
            "color: #CF9FFF; font-weight: bold;",
            "",
            ...args);
    }
}
function debug(...args) { log("debug", ...args); }
function info(...args) { log("info", ...args); }
function warn(...args) { log("warn", ...args); }
function error(...args) { log("error", ...args); }

/**
 * Given a starting node, search for a parent element
 *
 * This function will search for a parent element that matches a given CSS
 * selector starting from a given node. The search will continue up the DOM tree
 * until a matching parent element is found or the maximum distance is reached.
 *
 * @param {HTMLHtmlElement} node  Starting node to search from
 * @param {String} selector       CSS selector to match parent elements against
 * @param {Number} maxDistance    Maximum number of elements before giving up
 * @return {HTMLHtmlElement}      Matching parent element or null if not found
 */
function findParent(node, selector, maxDistance = Infinity) {
    let currentElement = node.parentElement;
    let distance = 0;

    while (currentElement && distance < maxDistance) {
        if (currentElement.matches(selector)) {
            return currentElement; // Return the matching parent element
        }
        // Move up to the next parent
        currentElement = currentElement.parentElement;
        // Increment the distance counter
        distance++;
    }

    // Return null if no match is found within the max distance
    return null;
}

/**
 * Wait for an element to be available in the DOM
 *
 * This function will wait for an element to be available in the DOM before
 * resolving the promise. If the element is already available, the promise will
 * resolve immediately.
 *
 * @link               https://stackoverflow.com/a/61511955
 * @param {String}     A CSS selector to match elements against selector
 * @returns {Promise}  A promise that resolves when the element is found
 */
function waitForElement(selector) {
    return new Promise(resolve => {
        if (document.querySelector(selector)) {
            return resolve(document.querySelector(selector));
        }

        const observer = new MutationObserver(mutations => {
            if (document.querySelector(selector)) {
                observer.disconnect();
                resolve(document.querySelector(selector));
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    });
}


/*******************************************************************************
 Core functions
*******************************************************************************/

/**
 * Dim the thumbnails of watched videos
 *
 * This function will search for watched progress bars on YouTube, attempt to
 * find their associated thumbnail, and dim the thumbnail if the video has been
 * watched. The following configuration options are available:
 * - use_relative_opacity: If true, the thumbnail opacity will be calculated
 *   relative to the percentage watched. If false, the thumbnail opacity will be
 *   set to a fixed value.
 * - thumbnail_opacity: The opacity of the thumbnail when the video has been
 *   watched. This value is used as a lower bound when use_relative_opacity is
 *   true.
 * - min_watched: The minimum percentage of the video that must be watched for
 *   the thumbnail to be dimmed. If the video has been watched less than this
 *   percentage, the thumbnail will be set to full opacity.
 *
 * @returns {void}
 */
function dimWatchedThumbnails(
    minWatched,
    thumbnailOpacity,
    useRelativeOpacity
) {
    if (minWatched === undefined)
        minWatched = getConfig("min_watched");
    if (thumbnailOpacity === undefined)
        thumbnailOpacity = getConfig("thumbnail_opacity");
    if (useRelativeOpacity === undefined)
        useRelativeOpacity = getConfig("use_relative_opacity");

    // Collect all of the watched progress bars
    let watchedProgressBars = document.querySelectorAll(
        seenQuerySelectors.join(", ")
    );

    // Create the combined parent selector
    let parentSelector = parentThumbnailSelectors.join(", ");

    debug(
        `Found ${watchedProgressBars.length} watched videos:`,
        watchedProgressBars
    );
    // Loop over them and try to get their associated thumbnail, dimming it out
    for (let watchedProgressBar of watchedProgressBars) {
        let watchedPercentage = parseInt(watchedProgressBar.style.width);

        debug(
            `Searching for parent of progress bar at ${watchedPercentage}%`,
            watchedProgressBar
        );
        let thumbnail = findParent(watchedProgressBar, parentSelector, 6);
        if (thumbnail === null) {
            error("Could not find parent thumbnail for", watchedProgressBar);
        }
        if (thumbnail) {
            let watchedOpacity;
            if (watchedPercentage < minWatched) {
                debug(
                    `Progress bar ${watchedPercentage} < ${minWatched},`,
                    "setting opacity to 1.0",
                    watchedProgressBar
                );
                watchedOpacity = "";
            } else if (useRelativeOpacity) {
                watchedOpacity = (
                    (
                        thumbnailOpacity * (100 - watchedPercentage) / 100
                    ) + thumbnailOpacity
                );
            } else {
                watchedOpacity = thumbnailOpacity
            }
            debug(
                `${thumbnailOpacity} * (100 - ${watchedPercentage})`,
                `/ 100) + ${thumbnailOpacity} = ${watchedOpacity}`,
                thumbnail
            );
            thumbnail.style.opacity = watchedOpacity;
        }
    }
}


/*******************************************************************************
 Main script
*******************************************************************************/

(function() {
    'use strict';

    // Wait for the primary element to become available
    debug("waiting for #primary...");
    waitForElement("#primary").then(el => {
        debug("#primary loaded!");

        // Dim the progress bars
        dimWatchedThumbnails();

        // Dim them again anytime the primary section changes
        let content = document.getElementById("primary");
        let observer = new MutationObserver( observer => {
            dimWatchedThumbnails()
        });
        info("Watching for new thumbnails in", content);
        observer.observe(
            content, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['style']
            }
        );
    });
})();
