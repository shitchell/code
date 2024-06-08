// ==UserScript==
// @name        Timesheet Validator
// @namespace   Violentmonkey Scripts
// @match       https://tastk.trinoor.com/pls/apex/f
// @grant       none
// @version     1.0
// @author      -
// @description 12/30/2022, 2:08:02 PM
// ==/UserScript==

var DEBUG = true;
const validMinutes = ["00", "15", "30", "45"];
const invalidEntryClass = 'invalid-entry';

function debug(...args) {
  if (DEBUG) {
    const timestamp = new Date().toISOString().replace("T", " ").replace(/\..*/, "")
    console.debug(`%c[ts validator | ${timestamp}]`, "color: green; font-weight: bold;", ...args);
  }
}

function validateTimeInput(input) {
  let validTime = false;

  // Extract the text from the input box
  let minutes = input.value.split(":")[1];

  // Ensure the time is in the correct format
  if (minutes) {
    if (input.value.match(/^\d?\d:\d\d$/)) {
      // Valid format, so check the minutes
      if (validMinutes.includes(minutes)) {
        // minutes match one of: 00, 15, 30, or 45
        validTime = true;
      }
    }
  }

  if (validTime) {
    input.classList.remove(invalidEntryClass);
  } else {
    input.classList.add(invalidEntryClass);
  }
}

// Add the invalid-entry class to the page
const style = document.createElement('style');
style.innerHTML = `.${invalidEntryClass} { background-color: #ffff00 !important; font-weight: bold; }`;
document.head.appendChild(style);

//
// --- Check the Calendar view cells ---
//

// Get all calendar cells based on class
const calendarCells = document.querySelectorAll('td.Day, td.WeekendDay, td.NonDay, td.Today');
debug("Checking calendar cells:", calendarCells);

// Loop over each cell
for (const cell of calendarCells) {
  // Check if the cell contains the text "Hrs. Entered"
  if (cell.innerHTML.includes('Hrs. Entered')) {
    // Get the hours entered value
    const hoursEnteredMatch = cell.innerHTML.match(/Hrs\. Entered:  ((\d+)?(\.\d+)?)/);
    debug("found cell with hours:", hoursEnteredMatch);
    if (hoursEnteredMatch) {
      const hoursEntered = parseFloat(hoursEnteredMatch[1]);
      debug("parsed hours:", hoursEntered);

      // Check if the hours entered are divisible by 0.25
      if (hoursEntered % 0.25 !== 0) {
        debug("hours not divisible by 0.25, setting parent <td> to invalid");
        // Add the invalid-entry class to the cell's class list
        cell.classList.add(invalidEntryClass);
      }
    }
  }
}

//
// --- Check the time entry input boxes ---
//

// Fetch all of the hours input boxes
const timeInputs = document.querySelectorAll("input[id^=f05_]");
debug("Checking input cells:", timeInputs);

// Loop over each time input
for (const input of timeInputs) {
  // Check each one once when the page initially loads
  validateTimeInput(input);

  // Set up an event listener to revalidate each input whenever they're modified
  input.addEventListener("change", function() {
    validateTimeInput(input)
  });
}

