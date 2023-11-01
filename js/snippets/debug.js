const DEBUG = true;
const DEBUG_NAME = "some title";
function debug(...args) {
  if (DEBUG) {
    const timestamp = new Date().toISOString().replace("T", " ").replace(/\..*/, "")
    console.debug(`%c[${DEBUG_NAME} | ${timestamp}]`, "color: green; font-weight: bold;", ...args);
  }
}
