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

public class IdleMouse
{
    int idleTime = 5; // Default idle time in seconds
    int xOffset = 1; // Default x offset for jiggling the mouse
    int yOffset = 1; // Default y offset for jiggling the mouse
    Robot robot;

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
        // Set up defaults for:
        // - idle time: 5 seconds
        // - jiggle pixel offset: 1 pixel
        // - number of loops / duration of loops: 1
        int idleTime = 10;
        int xOffset = 1;
        int yOffset = 1;
        int loopDuration = -1;
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
                System.exit(0);
            }
            else if (arg.equals("-i") || arg.equals("--idle"))
            {
                value = args[++i];
                try {
                    idleTime = Integer.parseInt(value);
                } catch (NumberFormatException e) {
                    // Try to parse as a time string
                    try {
                        idleTime = timeStringToSeconds(value);
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
                            loopDuration = timeStringToSeconds(value);
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
        }

        // Debug information
        debug(
            String.format(
                "idleTime: %d, xOffset: %d, yOffset: %d, loopDuration: %d%n",
                idleTime, xOffset, yOffset, loopDuration
            )
        );

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
        // System.out.printf(
        //     "%sWaiting for the mouse to be idle for %d seconds...%s%n",
        //     S_DIM, idleTime, S_RESET
        // );
        do {
            // Wait `idleTime` seconds for the mouse to move. If it doesn't move
            // in that time, `pointerInfo` will be null, and we'll jiggle the
            // mouse.
            pointerInfo = IdleMouse.waitForMouseMovement(idleTime);

            // Check if we got mouse coordinates or if the mouse was idle for
            // the entire idleTime
            remainingTime = (int) (loopDuration - (System.currentTimeMillis() - startTime) / 1000);
            remainingTimeStr = secondsToTimeString(remainingTime);
            if (pointerInfo == null)
            {
                // Mouse is idle! Print a message and do the jiggle wiggle
                System.out.printf(
                    "[%s]  %sMouse is idle, jiggling%s%n",
                    remainingTimeStr, C_IDLE, S_RESET
                );
                idleMouse.jiggleMouse(xOffset, yOffset);
            } else {
                // The mouse moved! Print the coordinates and continue
                StringBuilder mouseMovementStr = new StringBuilder();
                mouseMovementStr.append("[");
                mouseMovementStr.append(remainingTimeStr);
                mouseMovementStr.append("]  ");
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

            // // Print a message about the remaining time
            // remainingTime = (int) (loopDuration - (System.currentTimeMillis() - startTime) / 1000);
            // if (loopDuration != -1 && remainingTime > 0)
            // {
            //     System.out.printf(
            //         "%sRemaining%s: %s%s%s%n",
            //         C_KEY, S_RESET, C_VALUE, secondsToTimeString(remainingTime), S_RESET
            //     );
            // }

            // Sleep for a bit before checking again
            try
            {
                Thread.sleep(500);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            // Decrement the remaining time
            if (loopDuration != -1)
            {
                remainingTime = (int) (loopDuration - (System.currentTimeMillis() - startTime) / 1000);
            }
        } while (loopDuration == -1 || remainingTime > 0);
    }

    public static PointerInfo waitForMouseMovement(int timeout)
    {
        timeout *= 1000; // Convert seconds to milliseconds
        long endTime = System.currentTimeMillis() + timeout;
        PointerInfo pointerInfo = MouseInfo.getPointerInfo();
        int x = pointerInfo.getLocation().x;
        int y = pointerInfo.getLocation().y;
        int xNew = 0;
        int yNew = 0;

        // Loop until the mouse moves or the timeout is reached
        while (System.currentTimeMillis() < endTime)
        {
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
                Thread.sleep(250);
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
                // System.out.printf("Mouse moved from (%d, %d) to (%d, %d)%n", x, y, xNew, yNew);
                lastTime = System.currentTimeMillis();
                x = pointerInfo.getLocation().x;
                y = pointerInfo.getLocation().y;
                mouseIdle = false;
            } else {
                mouseIdle = true;
            }

            try
            {
                Thread.sleep(250);
            }
            catch (InterruptedException e)
            {
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
        // Check if the DEBUG environment variable is set to 1 or true
        String debug = System.getenv("DEBUG");
        if (debug != null && (debug.equals("1") || debug.equals("true")))
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
    public static int timeStringToSeconds(String timeString)
    {
        int seconds = 0;
        boolean isColonSeparated = timeString.contains(":");

        // If the time string is in the format "HH:MM:SS"
        if (isColonSeparated)
        {
            String[] parts = timeString.split(":");
            int hours = 0;
            int minutes = 0;

            if (parts.length == 3)
            {
                try {
                    hours = Integer.parseInt(parts[0]);
                    minutes = Integer.parseInt(parts[1]);
                    seconds = Integer.parseInt(parts[2]);
                } catch (NumberFormatException e) {
                    System.err.printf("Invalid time string: %s%n", timeString);
                    System.exit(1);
                }
            } else if (parts.length == 2)
            {
                try {
                    minutes = Integer.parseInt(parts[0]);
                    seconds = Integer.parseInt(parts[1]);
                } catch (NumberFormatException e) {
                    System.err.printf("Invalid time string: %s%n", timeString);
                    System.exit(1);
                }
            } else if (parts.length == 1)
            {
                try {
                    seconds = Integer.parseInt(parts[0]);
                } catch (NumberFormatException e) {
                    System.err.printf("Invalid time string: %s%n", timeString);
                    System.exit(1);
                }
            } else {
                System.err.printf("Invalid time string: %s%n", timeString);
                System.exit(1);
            }

            seconds = (hours * 60 * 60 + minutes * 60 + seconds);
        } else {
            // If the time string is in the format "1h 2m 3s"
            String[] parts = timeString.split(" ");
            int partValue = 0;

            for (String part : parts)
            {
                partValue = Integer.parseInt(part.substring(0, part.length() - 1));
                if (part.endsWith("d")) {
                    seconds += partValue * 24 * 60 * 60;
                } else if (part.endsWith("h"))
                {
                    seconds += partValue * 60 * 60;
                } else if (part.endsWith("m"))
                {
                    seconds += partValue * 60;
                } else if (part.endsWith("s"))
                {
                    seconds += partValue;
                } else {
                    System.err.printf("Invalid time string: %s%n", timeString);
                    System.exit(1);
                }
            }
        }

        return seconds;
    }

    public static String secondsToTimeString(int seconds)
    {
        int hours = seconds / 3600;
        int minutes = (seconds % 3600) / 60;
        int secs = seconds % 60;
        return String.format("%02dh %02dm %02ds", hours, minutes, secs);
    }

    public String toString()
    {
        return String.format(
            "IdleMouse{idleTime=%d, xOffset=%d, yOffset=%d}",
            this.idleTime, this.xOffset, this.yOffset
        );
    }
}

