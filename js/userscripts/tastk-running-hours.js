// ==UserScript==
// @name        Running Hours
// @namespace   Violentmonkey Scripts
// @match       https://tastk.trinoor.com/pls/apex/f
// @grant       none
// @version     1.0
// @author      Shaun Mitchell
// @description 11/1/2023, 10:39:05 AM
// ==/UserScript==

var DEBUG = true;
var runningHoursArray = [];
var weeklyHoursArray = [];
var runningHoursTotal = 0
const MINIMUM_HOURS_FOR_A_COUNTABLE_DAY = 5;

function debug(...args) {
  if (DEBUG) {
    const timestamp = new Date().toISOString().replace("T", " ").replace(/\..*/, "")
    console.debug(`%c[ts running hours | ${timestamp}]`, "color: green; font-weight: bold;", ...args);
  }
}

// Get all calendar cells based on class
const calendarCells = document.querySelectorAll('td.Day, td.WeekendDay, td.NonDay, td.Today');
// const calendarCells = document.querySelectorAll('td.Day, td.WeekendDay, td.Today');
debug("Checking calendar cells:", calendarCells);

// Loop over each cell
let cellNum = 0;
let countableDays = 0; // Number of days that have hours greater than MINIMUM_HOURS_FOR_A_COUNTABLE_DAY
let weeklyCountableDays = 0; // Number of countable days for each week
for (const calendarCell of calendarCells) {
  // If this is a "NonDay" (a day from the previous/next month), then skip it
  if (calendarCell.classList.contains("NonDay")) {
      debug("skipping NonDay", calendarCell);
      cellNum++;
      continue;
  }

  // Fix the Hrs. Entered cell style because whoever set it up missed a semicolon
  const hrsEnteredP = calendarCell.querySelector('a + span > p > span:nth-of-type(1)');
  if (hrsEnteredP && hrsEnteredP.innerText.includes("Hrs. Entered")) {
    // We have a match, so update its style
    hrsEnteredP.style = "font-weight: bold; font-size: 10px; color: black;";
  }

  // Try to find the hours entered
  let match = calendarCell.innerText.match(/Hrs\. Entered: ([\d\.]+)/);

  // Get the text container for any text updates we might have to perform
  let textContainer = calendarCell.querySelector('a + span > p');
  if (! textContainer) {
    debug("no textContainer for cell", calendarCell);
    // create a text container
    textContainerWrapperSPAN = document.createElement("span");
    textContainer = document.createElement("p");
    textContainer.setAttribute("align", "left");
    textContainerWrapperSPAN.appendChild(textContainer);
    calendarCell.appendChild(document.createElement("br"));
    calendarCell.appendChild(textContainerWrapperSPAN);
  }

  if (match && match.length >= 2) {
    let hours = match[1];
    debug("matched cell:", match);

    try {
      hours = Number.parseFloat(hours);
    } catch (e) {
      debug(`could not parse hours '${hours}' as float, skipping`);
      continue;
    }

    runningHoursTotal += hours;
    runningHoursArray.push(hours);
    weeklyHoursArray.push(hours);

    // Set up the countable days
    if (hours > MINIMUM_HOURS_FOR_A_COUNTABLE_DAY) {
      countableDays += 1;
      weeklyCountableDays += 1;
    }

    // Add the running hours to the cell
    const runningHoursSPAN = document.createElement("span");
    runningHoursSPAN.setAttribute("style", "display: block; font-size: 10px; font-style: italic;");
    runningHoursSPAN.innerText = `Running Hrs.: ${runningHoursTotal}`;
    textContainer.appendChild(runningHoursSPAN);
    textContainer.appendChild(document.createElement("br"));
  }

  // If this is the last cell in a row, add the weekly total and daily average
  if (calendarCell.nextElementSibling === null) {
    debug("setting weekly average for cell", calendarCell);

    // Calculate the weekly total and average
    let weeklyHoursTotal = weeklyHoursArray.reduce((a, b) => {return a + b}, 0);
    let weeklyAverage = 0;
    let averageDays = weeklyHoursArray.length;
    if (weeklyCountableDays > 0) {
      averageDays = weeklyCountableDays;
    }
    weeklyAverage = weeklyHoursTotal / averageDays;

    if (weeklyHoursArray.length > 0) {
      // Add the average daily hours for the week to the cell
      const weeklyAverageSPAN = document.createElement("span");
      weeklyAverageSPAN.setAttribute("style", "display: block; font-size: 10px; font-style: italic;");
      weeklyAverageSPAN.innerText = `Avg. Hrs. Entered: ${weeklyAverage.toFixed(2)}`;
      textContainer.appendChild(weeklyAverageSPAN);

      // Add the total weekly hours to the cell
      const weeklyTotalSPAN = document.createElement("span");
      weeklyTotalSPAN.setAttribute("style", "display: block; font-size: 10px; font-style: italic;");
      weeklyTotalSPAN.innerText = `Weekly Total Hrs.: ${weeklyHoursTotal.toFixed(2)}`;
      textContainer.appendChild(weeklyTotalSPAN);

      // Reset the weekly hours and days
      weeklyHoursArray = [];
      weeklyCountableDays = 0;
    }
  }
  cellNum++;
}

// Add a summary to the month title
const averageDailyHours = (runningHoursTotal / countableDays) || 0;
const monthTitleEl = document.querySelector(".MonthTitle");
debug("updating", monthTitleEl, "with hours", runningHoursTotal);
const hoursPlurality = runningHoursTotal == 1 ? "" : "s";
const entriesPlurality = runningHoursArray.length == 1 ? "y" : "ies";
monthTitleEl.innerHTML = `${monthTitleEl.innerText} <i>(${runningHoursTotal.toFixed(2)} hour${hoursPlurality} | avg: ${averageDailyHours.toFixed(2)} | ${runningHoursArray.length} entr${entriesPlurality})</i>`;

