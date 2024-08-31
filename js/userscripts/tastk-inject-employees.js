// ==UserScript==
// @name         Update Employee Select
// @namespace    Violentmonkey Scripts
// @match        https://tastk.trinoor.com/pls/apex/f*
// @version      0.1
// @description  Inject employees in the Employee select drop down
// @author       Shaun Mitchell <shaun.mitchell@trinoor.com>
// @match        https://tastk.trinoor.com/pls/apex/f*
// @icon         view-source:https://tastk.trinoor.com/pls/apex/r/tas/103/files/static/v302Y/favi-tastk.ico
// @require      https://update.greasyfork.org/scripts/502146/1435298/dev-stuff.js
// @run-at       document-end
// @grant        GM_unsafeWindow
// @license      WTFPL
// ==/UserScript==

var employeeIdUrl = "https://tastk.trinoor.com/pls/apex/f?p=103:20100:5502639048320:::::";
var employeeFieldSelector = "select[name$='_EMP_ID']";
var employeeMap = null;
var employeeMapFetched = false;
var useCache = true;

/**
 * This function will validate that we are on the correct page
 *
 * Validate that we are on the correct page by searching for an empty Employee
 * select drop down.
 *
 * @returns {boolean} True if we are on the correct page, false otherwise
 */
function validatePage() {
    let valid = false;
    let employeeSelectEl = document.querySelector(employeeFieldSelector);
    if (employeeSelectEl === null) {
        debug("Employee select drop down not found");
    } else if (employeeSelectEl.options.length <= 1) {
        // We allow for 1 option because the Employee select drop down should
        // always have a "Please Select" option
        debug("Employee select drop down is empty");
        valid = true;
    } else {
        debug("Employee select drop down has options");
    }
    debug("validatePage() returning", valid);
    return valid;
}

/**
 * This function will fetch the Employee IDs from the Job Code Report Details
 *
 * Fetch the Employee IDs from the Job Code Report Details page and return them
 * as a Promise.
 *
 * @returns {Promise} A Promise that resolves with the Employee IDs
 */
function fetchEmployeeSelect() {
    // The Job Code Report page does *not* include Employee IDs in the select
    // drop down if you are not an admin. The Job Code Report Details *does*
    // include Employee IDs in the select drop down. This function will fetch
    // the Employee IDs from the Job Code Report Details page and inject them
    // into the Employee select drop down on the Job Code Report page.
    return new Promise((resolve, reject) => {
        info("Fetching Employee IDs from Job Code Report Details page");
        // Check if we can use the cache
        if (useCache) {
            let employeeMapStr = localStorage.getItem("employeeMap");
            if (employeeMapStr !== null) {
                employeeMap = JSON.parse(employeeMapStr);
                info(`Using ${Object.keys(employeeMap).length} cached IDs`);
                debug(employeeMap);
                employeeMapFetched = true;
                resolve(employeeMap);
                return;
            }
        }
        // Not using the cache, fetch the Employee IDs
        /*
        let xhr = new XMLHttpRequest();
        xhr.open("GET", employeeIdUrl, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState == 4 && xhr.status == 200) {
                let parser = new DOMParser();
                let doc = parser.parseFromString(xhr.responseText, "text/html");
                let employeesOptionEls = doc.querySelectorAll(employeeFieldSelector + " option");
                employeesOptionEls.forEach((optionEl) => {
                    employeeMap[optionEl.value] = optionEl.text;
                });
                info(`Fetched ${Object.keys(employeeMap).length} Employee IDs`);
                debug(employeeMap);
                // Save the employeeMap to localStorage for future use
                localStorage.setItem("employeeMap", JSON.stringify(employeeMap));
                employeeMapFetched = true;
                resolve();
            }
        };
        xhr.send();
        */
        fetch(employeeIdUrl)
            .then((response) => {
                return response.text();
            })
            .then((text) => {
                let parser = new DOMParser();
                let doc = parser.parseFromString(text, "text/html");
                let employeeSelectEl = doc.querySelector(
                    employeeFieldSelector
                );
                // employeesOptionEls.forEach((optionEl) => {
                //     employeeMap[optionEl.value] = optionEl.text;
                // });
                employeeMap = {};
                for (const optionEl of employeeSelectEl.options) {
                    // If this is the "Select" option, skip it
                    if (optionEl.value === "") {
                        continue;
                    }
                    // Use text (the name) as the keys for alphabetical sorting
                    employeeMap[optionEl.text] = optionEl.value;
                }
                info(`Fetched ${Object.keys(employeeMap).length} Employee IDs`);
                debug(employeeMap);
                // Save the employeeMap to localStorage for future use
                debug("Saving Employee IDs to localStorage");
                localStorage.setItem(
                    "employeeMap", JSON.stringify(employeeMap)
                );
                employeeMapFetched = true;
                unsafeWindow.employeeMap = employeeMap;
                window.employeeMap = employeeMap;
                debug(
                    "Employee IDs fetched and saved to localStorage, resolving"
                );
                resolve(employeeMap);
            })
            .catch((error) => {
                Debugger.error("Error fetching Employee IDs", error);
                reject();
            });
    });
}

/**
 * This function will inject the Employee IDs into the Employee select drop down
 *
 * Inject the Employee IDs into the Employee select drop down on the Job Code
 * Report page.
 */
function injectEmployeeSelect(employeeMap) {
    // First, check if the Employee select drop down exists on the page
    let employeeSelectEl = document.querySelector(employeeFieldSelector);
    if (employeeSelectEl === null) {
        // The Employee select drop down does not exist on the page
        return;
    }

    // Next, ensure the employeeMap is fetched and populated
    //// if the employeeMap is not passed in, use the global employeeMap
    if (employeeMap === undefined || employeeMap === null) {
        // Try to use the global employeeMap there is no employeeMap passed in
        debug("Using global employeeMap");
        employeeMap = window.employeeMap;
    }
    //// both the passed in employeeMap and the global employeeMap are missing
    if (employeeMap === undefined || employeeMap === null) {
        // The employee map hasn't been fetched yet
        if (!employeeMapFetched) {
            // Fetch the Employee IDs from the Job Code Report Details page
            debug("employeeMap is not fetched, fetching now");
            fetchEmployeeSelect().then((employeeMap) => {
                injectEmployeeSelect(employeeMap);
            });
        } else {
            // The employeeMap has been fetched, but it's empty
            error("Employee IDs is empty after fetching");
        }
    }
    //// Validate that we actually populated the employeeMap
    if (
        typeof employeeMapFetched === "object"
        && Object.keys(employeeMap).length === 0
    ) {
        // The employeeMap is empty, even after fetching
        error("Employee IDs is empty after fetching");
        return;
    }

    // Finally, inject the Employee IDs into the Employee select drop down
    for (let employeeName in employeeMap) {
        const employeeId = employeeMap[employeeName];
        debug(`Injecting ID: ${employeeName} (${employeeId})`);
        let optionEl = document.createElement("option");
        optionEl.value = employeeId;
        optionEl.text = employeeName;
        employeeSelectEl.appendChild(optionEl);
    }
}

function main() {
    if (validatePage()) {
        // Inject the Employee IDs into the Employee select drop down
        debug("DOM Loaded, starting");
        injectEmployeeSelect(employeeMap);
    } else {
        debug("Invalid page, exiting");
    }
}
(function() {
    'use strict';

    // Add event listener if the DOM has not yet loaded
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", main);
    } else {
        main();
    }
})();
