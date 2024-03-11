// ==UserScript==
// @name        Job Code Report
// @namespace   Violentmonkey Scripts
// @match       https://tastk.trinoor.com/pls/apex/f*
// @grant       none
// @version     1.0
// @author      -
// @description 1/29/2024, 2:25:29 PM
// ==/UserScript==

var days = [];
var entries = {};

const DEBUG = true;
const DEBUG_NAME = "tastk-jobcode-report";
function debug(...args) {
  if (DEBUG) {
    const timestamp = new Date().toISOString().replace("T", " ").replace(/\..*/, "")
    console.debug(`%c[${DEBUG_NAME} | ${timestamp}]`, "color: green; font-weight: bold;", ...args);
  }
}

class DayDetails {
    constructor(url) {
        debug("DayDetails constructor: " + url);
        if (url === undefined) {
            // If a URL is not provided, use the current page
            url = window.location.href;
        }
        this.url = url;
        this._date = null;
        this._title = null;
        this._document = null;
        this._isReleased = null;
        this._rawEntries = []; // [ ["JobCode", hours] ]
    }

    async fetch() {
        await fetch(this.url)
            .then(response => response.text())
            .then(text => {
                this._document = new DOMParser().parseFromString(
                    text,
                    "text/html"
                );
            })
            .catch(error => console.error(error));
        return this._document;
    }

    /*
     * Converts a string in the format "HH:MM" to
     * hours as a decimal
     */
    _timeStringToHours(timeString) {
        debug("timeStringToHours: " + timeString)
        if (timeString === "" || timeString === null || timeString === undefined) {
            return 0;
        }
        const [hours, minutes] = timeString.split(":");
        return parseInt(hours) + parseInt(minutes) / 60;
    }

    _extractText(querySelector) {
        let innerTexts = [];
        const els = this.document.querySelectorAll(querySelector);
        debug(`querySelector: "${querySelector}" / els:`, els);
        for (const el of els) {
            debug(`processing el:`, el);
            let innerText = (
                el.innerText.trim()
                || el.textContent.trim()
                || el.value.trim()
                || el.title.trim()
            );
            debug(`innerText: "${innerText}"`)
            innerTexts.push(innerText);
        }
        return innerTexts;
    }

    _extractHours() {
        let jobCodes = [];
        let hours = [];

        // Collect the job codes
        let jobCodesQuery = "";
        if (this.isReleased) {
            jobCodesQuery = "td[headers=JOB_CODE_ID]";
        } else {
            jobCodesQuery = "td[headers=JOB_CODE_ID] > select > option[selected=selected]:not([value=''])";
        }
        jobCodes = this._extractText(jobCodesQuery);
        debug(`jobCodesQuery: "${jobCodesQuery}" / jobCodes:`, jobCodes);

        // Collect the hours
        let hoursQuery = "";
        if (this.isReleased) {
            hoursQuery = "td[headers=HOURS_WORKED]";
        } else {
            hoursQuery = "td[headers=HOURS_WORKED] > input:not([value=''])";
        }
        hours = this._extractText(hoursQuery);
        debug(`hoursQuery: "${hoursQuery}" / hours:`, hours);

        // Combine the job codes and hours into an array of arrays
        for (let i = 0; i < jobCodes.length; i++) {
            // Convert the hours to a decimal
            debug(`${this.date} -- jobCodes[${i}]: ` + jobCodes[i], ` / hours[${i}]: ` + hours[i])
            hours[i] = this._timeStringToHours(hours[i]);
            this._rawEntries.push([jobCodes[i], hours[i]]);
        }
    }

    _extractDate() {
        if (this._date === null) {
            const dateLabel = this.document.querySelector("span[id*=_TIME_ENTRY_DATE_DISPLAY]");
            if (dateLabel === null) {
                throw new Error("Could not find date label for " + this.title);
            }
            this._date = new Date(dateLabel.innerText);
        }
        return this._date;
    }

    /*
     * Returns an associative array with the job codes as keys and their
     * cumulative hours as values.
     */
    get entries() {
        let _entries = {};

        for (const entry of this._rawEntries) {
            const [jobCode, hours] = entry;
            if (jobCode in _entries) {
                _entries[jobCode] += hours;
            } else {
                _entries[jobCode] = hours;
            }
        }

        return _entries;
    }

    get isReleased() {
        if (this._isReleased === null && this.document !== null) {
            const releaseLabels = this.document.querySelectorAll(
                "label[id*=_RELEASE_LABEL]"
            );
            this._isReleased = releaseLabels.length === 0;
        }
        return this._isReleased;
    }

    get title() {
        if (this._title === null && this.document !== null) {
            this._title = this.document.title;
        }
        return this._title;
    }

    get date() {
        if (this._date === null && this.document !== null) {
            this._extractDate()
        }
        return this._date;
    }

    get document() {
        return this._document;
    }
}
// let day = new DayDetails();
// debug(day.entries);

/*
    * Accepts a NodeList of calendar cells and returns a list of Promises which
    * resolve to DayDetails objects.
    */
function collectDayDetails(calendarCells) {
    let dayDetailsPromises = [];
    for (const calendarCell of calendarCells) {
        const anchor = calendarCell.querySelector("td > a");
        if (anchor !== null) {
            let day = new DayDetails(anchor.href);
            dayDetailsPromises.push(day.fetch().then(() => {
                day._extractHours();
                day._extractDate();
                debug("Processing day: " + day._date);
                return day;
            }));
        }
    }
    return dayDetailsPromises;
}

/*
 * Accepts an entries report and adds it to the page
 */
function addReport(entries) {
    // Find the element to append the report to
    let reportParent = document.querySelector(".tbl-body td.tbl-main .regionlayout > tbody:nth-child(1) > tr:nth-child(1) > td:nth-child(3)");
    if (reportParent === null) {
        throw new Error("Could not find report parent element");
    }
    debug("reportParent: ", reportParent);

    let reportDiv = document.createElement("div");
    reportDiv.setAttribute("id", "jobcode-report");
    reportDiv.setAttribute("aria-live", "polite");
    reportDiv.setAttribute("style", "position: static; width: 370px");
    reportDiv.classList.add("rounded-corner-region");

    let innerHTML = `
        <div class="rc-blue-top">
            <div class="rc-blue-top-r">
                <div class="rc-title">Job Code Report</div>
            </div>
        </div>

        <div class="rc-body">
            <div class="rc-body-r">
                <div class="rc-content-main">
                    <table>
                        <thead style="text-align: left">
                            <tr>
                                <th>Job Code</th>
                                <th>Hours</th>
                            </tr>
                        </thead>
                        <tbody>
    `;
    for (const [jobCode, hours] of Object.entries(entries)) {
        innerHTML += `
            <tr style="padding-top: 1em">
                <td style="padding-right: 1em">${jobCode}</td>
                <td style="font-family: Consolas; monospace; text-align: right">${hours.toFixed(2)}</td>
            </tr>
        `;
    }
    innerHTML += `
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div class="rc-bottom">
            <div class="rc-bottom-r"></div>
        </div>
    `;

    reportDiv.innerHTML = innerHTML;
    debug("reportDiv: ", reportDiv);
    reportParent.appendChild(reportDiv);
}

/* Main
 ********************/

// Collect all of the day cells in the calendar on the current page
//const calendarCells = document.querySelectorAll('td.Day, td.WeekendDay, td.NonDay, td.Today')
const calendarCells = document.querySelectorAll('td.Day, td.WeekendDay, td.Today')

// Collect the day details
let dayDetailsPromises = collectDayDetails(calendarCells);

// Wait for all of the day details to be collected
Promise.all(dayDetailsPromises).then((days) => {
    for (const day of days) {
        for (const [jobCode, hours] of Object.entries(day.entries)) {
            if (jobCode in entries) {
                entries[jobCode] += hours;
            } else {
                entries[jobCode] = hours;
            }
        }
    }
    console.log("entries: ", entries);
    console.log("days: ", days);
    unsafeWindow.entries = entries;
    unsafeWindow.days = days;

    // Add the report to the page
    debug("Adding report to page");
    addReport(entries);
});

// // Create 2 global variables for storing the days and entries
// unsafeWindow.days = [];
// unsafeWindow.entries = {};

// for (const calendarCell of calendarCells) {
//     const anchor = calendarCell.querySelector("td > a")
//     // Add the day to the days array using a promise to ensure that the
//     // day's details are collected before the global entries object is
//     // generated
//     let day = new DayDetails(anchor.href);
//     Promise.resolve(day.fetch()).then(() => {
//         day._extractHours();
//         day._extractDate();
//         // unsafeWindow.days.push(day);
//         days.push(day)
//         console.log("Processing day: " + day._date);

//         // Add the day's entries to the global entries object
//         for (const [jobCode, hours] of Object.entries(day.entries)) {
//             if (jobCode in unsafeWindow.entries) {
//                 // unsafeWindow.entries[jobCode] += hours;
//                 entries[jobCode] += hours;
//             } else {
//                 // unsafeWindow.entries[jobCode] = hours;
//                 entries[jobCode] = hours;
//             }
//         }
//     });

//     // let day = new DayDetails(anchor.href);
//     // days.push(day);
// }
