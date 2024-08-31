/*
 * IdleMouse.java
 * 
 * Detects when the mouse is idle and jiggle it by 1 pixel.
*/
import java.awt.event.*;
import java.awt.AWTException;
import java.awt.MouseInfo;
import java.awt.PointerInfo;
import java.awt.Robot;

// Adding support for parsing time strings and converting them to a duration
// in seconds
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

// Add support for better durationString parsing
import java.util.regex.Pattern;
import java.util.regex.Matcher;

public class IdleMouse
{
    int idleTime = 5;                 // Default idle time in seconds
    int xOffset = 1;                  // Default x offset for jiggling the mouse
    int yOffset = 1;                  // Default y offset for jiggling the mouse
    static final int sleepTime = 250; // Default sleep time for delays
    Robot robot;
    private static boolean DEBUG = false;
    private static String[] timePatterns = {
        "HH[:mm[:ss]]",
        "h[h][:mm[:ss]][ ]a",
        "HHmm"
    };

    public IdleMouse(int idleTime, int xOffset, int yOffset) throws AWTException
    {
        this.robot = new Robot();
        this.idleTime = idleTime;
        this.xOffset = xOffset;
        this.yOffset = yOffset;
    }

    public IdleMouse(int idleTime, int offset) throws AWTException
    {
        this(idleTime, offset, offset);
    }

    public IdleMouse(int idleTime) throws AWTException
    {
        this(idleTime, 1);
    }

    public IdleMouse() throws AWTException
    {
        this(5);
    }

    public static void main(String[] args) throws AWTException
    {
        // Set up default values
        int idleTime = 10;
        int xOffset = 1;
        int yOffset = 1;
        int loopDuration = -1;
        boolean runForever = true;
        int remainingTime = 0;
        String remainingTimeStr = "";
        long startTime = System.currentTimeMillis();
        PointerInfo pointerInfo = null;
        PointerInfo lastPointerInfo = null;
        IdleMouse idleMouse;
        String scriptName = "IdleMouse";
        boolean useAnsiColors = false;
        String S_RESET = "";
        String S_BOLD = "";
        String S_DIM = "";
        String C_RED = "";
        String C_GREEN = "";
        String C_YELLOW = "";
        String C_BLUE = "";
        String C_PURPLE = "";
        String C_CYAN = "";
        String C_KEY = "";
        String C_VALUE = "";
        String C_MOVE = "";
        String C_IDLE = "";
        String C_COORDS = "";

        // Check if we're in a pipe or should enable ANSI colors
        if (System.console() != null)
        // if (true)
        {
            useAnsiColors = true;
            S_RESET = "\u001B[0m";
            S_BOLD = "\u001B[1m";
            S_DIM = "\u001B[2m";
            C_RED = "\u001B[31m";
            C_GREEN = "\u001B[32m";
            C_YELLOW = "\u001B[33m";
            C_BLUE = "\u001B[34m";
            C_PURPLE = "\u001B[35m";
            C_CYAN = "\u001B[36m";
            C_KEY = S_BOLD;
            C_VALUE = C_CYAN;
            C_MOVE = C_PURPLE;
            C_IDLE = C_YELLOW;
            C_COORDS = C_GREEN;
        }

        // Get the script name
        scriptName = System.getProperty("sun.java.command");
        if (scriptName != null)
        {
            int spaceIndex = scriptName.indexOf(' ');
            if (spaceIndex != -1)
            {
                scriptName = scriptName.substring(0, spaceIndex);
            }
        }

        debug(
            String.format(
                "scriptName: %s, idleTime: %d, xOffset: %d, yOffset: %d, loopDuration: %d%n",
                scriptName, idleTime, xOffset, yOffset, loopDuration
            )
        );

        // Parse command line arguments
        String arg;
        String value;
        for (int i = 0; i < args.length; i++)
        {
            arg = args[i];
            if (arg.equals("-h") || arg.equals("--help"))
            {
                System.out.println("usage: java IdleMouse [options]");
                System.out.println("");
                System.out.println("Options:");
                System.out.println("  -h/--help           Print this help message");
                System.out.println("  -i/--idle <n>       Jiggle the mouse after <n> seconds (default: 5)");
                System.out.println("  -x/--x-offset <n>   Set the x offset for jiggling the mouse (default: 1)");
                System.out.println("  -y/--y-offset <n>   Set the y offset for jiggling the mouse (default: 1)");
                System.out.println("  -d/--duration <n>   Stop checking after <n> seconds (default: -1, forever)");
                System.out.println("  -u/--until <time>   Stop checking after <time>");
                System.exit(0);
            }
            else if (arg.equals("--debug"))
            {
                IdleMouse.DEBUG = true;
            }
            else if (arg.equals("-i") || arg.equals("--idle"))
            {
                value = args[++i];
                try {
                    idleTime = Integer.parseInt(value);
                } catch (NumberFormatException e) {
                    // Try to parse as a time string
                    try {
                        idleTime = durationStringToSeconds(value);
                    } catch (NumberFormatException e2) {
                        System.err.printf("%s: error: invalid number: %s%n", scriptName, value);
                        System.exit(1);
                    }
                }

                // Validate that we have a positive number
                if (idleTime < 0)
                {
                    System.err.printf("%s: error: idle time must be a positive integer: %s%n", scriptName, value);
                    System.exit(1);
                }
            }
            else if (arg.equals("-x") || arg.equals("--x-offset"))
            {
                value = args[++i];
                try {
                    xOffset = Integer.parseInt(value);
                } catch (NumberFormatException e) {
                    System.err.printf("%s: error: invalid number: %s%n", scriptName, value);
                    System.exit(1);
                }
            }
            else if (arg.equals("-y") || arg.equals("--y-offset"))
            {
                value = args[++i];
                try {
                    yOffset = Integer.parseInt(value);
                } catch (NumberFormatException e) {
                    System.err.printf("%s: error: invalid number: %s%n", scriptName, value);
                    System.exit(1);
                }
            }
            else if (arg.equals("-d") || arg.equals("--duration"))
            {
                value = args[++i];
                if (value.equals("forever"))
                {
                    loopDuration = -1;
                    continue;
                } else {
                    try {
                        loopDuration = Integer.parseInt(value);
                    } catch (NumberFormatException e) {
                        // Try to parse as a time string
                        try {
                            loopDuration = durationStringToSeconds(value);
                        } catch (NumberFormatException e2) {
                            System.err.printf("%s: error: invalid number: %s%n", scriptName, value);
                            System.exit(1);
                        }
                    }
                }

                // Validate that we have a positive number or -1
                if (loopDuration < -1 || loopDuration == 0)
                {
                    System.err.printf(
                        "%s: error: duration must be a positive integer: %s%n",
                        scriptName, value
                    );
                    System.exit(1);
                }
            }
            else if (arg.equals("-u") || arg.equals("--until"))
            {
                value = args[++i];
                loopDuration = timeStringToSeconds(value);
            }
            else
            {
                System.err.printf("%s: error: invalid option: %s%n", scriptName, arg);
                System.exit(1);
            }
        }

        // Debug information
        debug(
            String.format(
                "idleTime: %d, xOffset: %d, yOffset: %d, loopDuration: %d%n",
                idleTime, xOffset, yOffset, loopDuration
            )
        );

        // Set `runForever` to true if loopDuration is -1
        runForever = (loopDuration == -1) ? true : false;

        // Create an instance of the IdleMouse class
        idleMouse = new IdleMouse(idleTime, xOffset, yOffset);

        // Print the idle time and loop information
        String idleString = secondsToTimeString(idleTime);
        String loopStr = (loopDuration == -1) ? "forever" : secondsToTimeString(loopDuration);
        System.out.printf(
            "%sIdle time%s: %s%s%s,  %sRunning for%s: %s%s%s%n",
            C_KEY + S_DIM, S_RESET, C_VALUE, idleString, S_RESET, C_KEY, S_RESET, C_VALUE, loopStr, S_RESET
        );

        // Loop forever or for the specified duration
        startTime = System.currentTimeMillis();
        remainingTime = loopDuration;
        lastPointerInfo = MouseInfo.getPointerInfo();
        do {
            // Wait `idleTime` seconds for the mouse to move. If it doesn't move
            // in that time, `pointerInfo` will be null, and we'll jiggle the
            // mouse.
            pointerInfo = IdleMouse.waitForMouseMovement(idleTime);

            // If this is the first run, lastPointerInfo will be null, so set it
            // to the current pointer info and continue
            if (lastPointerInfo == null)
            {
                lastPointerInfo = pointerInfo;
                debug(String.format(
                    "Setting lastPointerInfo to: %s%n",
                    lastPointerInfo
                ));
                continue;
            }

            // Check if we got mouse coordinates or if the mouse was idle for
            // the entire idleTime
            remainingTime = (int) (loopDuration - (System.currentTimeMillis() - startTime) / 1000);
            remainingTimeStr = secondsToTimeString(remainingTime);
            if (pointerInfo == null)
            {
                // Mouse is idle! Print a message and do the jiggle wiggle
                if (!runForever) {
                    System.out.printf("[%s]  ", remainingTimeStr);
                }
                System.out.printf(
                    "%sMouse is idle, jiggling%s%n",
                    C_IDLE, S_RESET
                );
                idleMouse.jiggleMouse(xOffset, yOffset);
            } else {
                // The mouse moved! Print the coordinates and continue
                StringBuilder mouseMovementStr = new StringBuilder();
                if (!runForever) {
                    // Add some info about the remaining time
                    mouseMovementStr.append("[");
                    mouseMovementStr.append(remainingTimeStr);
                    mouseMovementStr.append("]  ");
                }
                mouseMovementStr.append(C_MOVE);
                mouseMovementStr.append("Mouse moved ");
                // If we have old pointer info, add a "from" location
                if (lastPointerInfo != null)
                {
                    mouseMovementStr.append("from ");
                    mouseMovementStr.append(S_RESET);
                    mouseMovementStr.append(C_COORDS);
                    mouseMovementStr.append("(");
                    mouseMovementStr.append(lastPointerInfo.getLocation().x);
                    mouseMovementStr.append(", ");
                    mouseMovementStr.append(lastPointerInfo.getLocation().y);
                    mouseMovementStr.append(")");
                    mouseMovementStr.append(S_RESET);
                    mouseMovementStr.append(C_MOVE);
                    mouseMovementStr.append(" ");
                }
                // Add the "to" location
                mouseMovementStr.append("to ");
                mouseMovementStr.append(S_RESET);
                mouseMovementStr.append(C_COORDS);
                mouseMovementStr.append("(");
                mouseMovementStr.append(pointerInfo.getLocation().x);
                mouseMovementStr.append(", ");
                mouseMovementStr.append(pointerInfo.getLocation().y);
                mouseMovementStr.append(")");
                mouseMovementStr.append(S_RESET);
                System.out.println(mouseMovementStr.toString());

                // Update the last pointer info
                lastPointerInfo = pointerInfo;
            }

            // Sleep for a bit before checking again
            try
            {
                Thread.sleep(IdleMouse.sleepTime);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            // Decrement the remaining time
            if (loopDuration != -1)
            {
                remainingTime = (int) (loopDuration - (System.currentTimeMillis() - startTime) / 1000);
            }

            // If the remaining time is less than the idle time, set the idle
            // time to the remaining time to avoid waiting past the given
            // duration
            if (remainingTime < idleTime)
            {
                idleTime = remainingTime;
            }
        } while (runForever || remainingTime > 0);
    }

    public static PointerInfo waitForMouseMovement(int timeout)
    {
        timeout *= 1000; // Convert seconds to milliseconds
        long endTime = System.currentTimeMillis() + timeout;
        PointerInfo pointerInfo = MouseInfo.getPointerInfo();
        // Sometimes pointerInfo is null or becomes null if the mouse is moved
        // offscreen, the mouse is disconnected, or the system is put to sleep
        if (pointerInfo == null)
        {
            try {
                Thread.sleep(IdleMouse.sleepTime);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            return null;
        }
        int x = pointerInfo.getLocation().x;
        int y = pointerInfo.getLocation().y;
        int xNew = 0;
        int yNew = 0;

        // Loop until the mouse moves or the timeout is reached
        debug("Waiting for mouse movement until " + endTime + "...");
        while (System.currentTimeMillis() < endTime)
        {
            debug(
                String.format(
                    "Waiting for mouse to move from (%d, %d) [%d < %d]...%n",
                    x, y, System.currentTimeMillis(), endTime
                )
            );
            // Update pointerInfo
            pointerInfo = MouseInfo.getPointerInfo();
            if (pointerInfo != null)
            {
                xNew = pointerInfo.getLocation().x;
                yNew = pointerInfo.getLocation().y;

                // If either updated coordinate is different, then return the
                // updated pointer info
                if (x != xNew || y != yNew)
                {
                    return pointerInfo;
                }
            }

            // Sleep for a bit before checking again
            try
            {
                Thread.sleep(IdleMouse.sleepTime);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }

        // If we get here, the mouse hasn't moved
        return null;
    }

    public static PointerInfo waitForMouseIdle(int idleTime)
    {
        idleTime *= 1000; // Convert seconds to milliseconds
        long lastTime = System.currentTimeMillis();
        PointerInfo pointerInfo = null;
        int x = -1;
        int y = -1;
        int xNew = 0;
        int yNew = 0;
        boolean mouseIdle = false;
    
        do
        {
            // Update the pointer info
            pointerInfo = MouseInfo.getPointerInfo();
            xNew = pointerInfo.getLocation().x;
            yNew = pointerInfo.getLocation().y;

            if (xNew != x || yNew != y)
            {
                lastTime = System.currentTimeMillis();
                x = pointerInfo.getLocation().x;
                y = pointerInfo.getLocation().y;
                mouseIdle = false;
            } else {
                mouseIdle = true;
            }

            try
            {
                Thread.sleep(IdleMouse.sleepTime);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        } while (System.currentTimeMillis() - lastTime < idleTime);

        if (mouseIdle)
        {
            return pointerInfo;
        } else {
            return null;
        }
    }

    public void jiggleMouse(int xOffset, int yOffset)
    {
        int x = MouseInfo.getPointerInfo().getLocation().x;
        int y = MouseInfo.getPointerInfo().getLocation().y;
        this.robot.mouseMove(x + xOffset, y + yOffset);
        this.robot.mouseMove(x - xOffset, y - yOffset);
        this.robot.mouseMove(x, y);
    }

    public void jiggleMouse(int offset)
    {
        jiggleMouse(offset, offset);
    }

    public void jiggleMouse()
    {
        jiggleMouse(this.xOffset, this.yOffset);
    }

    public static void debug(String... args)
    {
        // Check if the DEBUG environment variable or the static DEBUG is set
        // String debug = System.getenv("DEBUG");
        boolean debug = IdleMouse.DEBUG;
        if (!debug) {
            // Check the DEBUG environment variable
            String debugEnv = System.getenv("DEBUG");
            if (debugEnv != null && (debugEnv.equals("1") || debugEnv.equals("true")))
            {
                debug = true;
            }
        }
        if (debug)
        {
            for (String arg : args)
            {
                System.err.printf("[debug] ");
                System.err.println(arg);
            }
        }
    }

    /*
     * Parse a time string in the format "[[HH:]MM:]SS" or "[[1h ]2m ]3s" and
     * return the number of milliseconds.
     */
    public static int durationStringToSeconds(String timeString) throws NumberFormatException
    {
        int seconds = 0;
        // Valid patterns should return 3 groups: hours, minutes, seconds
        Pattern[] validPatterns = {
            // 1h 2m 3s, 1h2m3s, 1h 3s, 1h, 2m, 3s
            Pattern.compile(
                "(?:(\\d+)h ?)?(?:(\\d+)m ?)?(?:(\\d+)s)?(?<=.)"
            ),
            // 01:02:03 (1h 2m 3s), 02:03 (2m 3s), :03 (3s)
            Pattern.compile(
                "(?:(\\d+):)?(\\d+)?:(\\d+)"
            )
        };

        // Loop through the valid patterns and try to parse the time string
        for (Pattern pattern : validPatterns)
        {
            Matcher matcher = pattern.matcher(timeString);
            if (matcher.find() && ! matcher.group(0).isEmpty())
            {
                int matchHours = 0;
                int matchMinutes = 0;
                int matchSeconds = 0;

                // Validate that the pattern returns 3 groups
                if (matcher.groupCount() == 3)
                {
                    if (matcher.group(1) != null)
                    {
                        matchHours = Integer.parseInt(matcher.group(1));
                    }
                    if (matcher.group(2) != null)
                    {
                        matchMinutes = Integer.parseInt(matcher.group(2));
                    }
                    if (matcher.group(3) != null)
                    {
                        matchSeconds = Integer.parseInt(matcher.group(3));
                    }

                    // Put it all together
                    seconds = (
                        matchHours * 3600 + matchMinutes * 60 + matchSeconds
                    );
                    return seconds;
                }
            }
        }

        throw new NumberFormatException(
            String.format("error: invalid time string: %s", timeString)
        );
    }

    public static String secondsToTimeString(int seconds)
    {
        int hours = seconds / 3600;
        int minutes = (seconds % 3600) / 60;
        int secs = seconds % 60;
        return String.format("%02dh %02dm %02ds", hours, minutes, secs);
    }

    public static int timeStringToSeconds(String string)
    {
        int endEpoch = 0;
        int curEpoch = 0;
        int duration = 0;

        // Loop through the time patterns and try to parse the string
        for (String pattern : timePatterns)
        {
            LocalTime time = null;

            try {
                DateTimeFormatter formatter = DateTimeFormatter.ofPattern(pattern);
                time = LocalTime.parse(string.toUpperCase(), formatter);
            } catch (DateTimeParseException e) {
                continue;
            }

            // If we get here, the string was parsed successfully
            endEpoch = time.toSecondOfDay();
            curEpoch = LocalTime.now().toSecondOfDay();
            duration = endEpoch - curEpoch;
            if (duration < 0)
            {
                System.err.printf(
                    "error: cannot idle into the past: %s%n",
                    string
                );
                System.exit(1);
            } else {
                break;
            }
        }
        return duration;
    }

    public static LocalTime durationToLocalTime(int duration)
    {
        int hours = duration / 3600;
        int minutes = (duration % 3600) / 60;
        int seconds = duration % 60;
        return LocalTime.of(hours, minutes, seconds);
    }

    public String toString()
    {
        return String.format(
            "IdleMouse{idleTime=%d, xOffset=%d, yOffset=%d}",
            this.idleTime, this.xOffset, this.yOffset
        );
    }
}

