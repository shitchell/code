/*
 * IdleMouse.java
 * 
 * Detects when the mouse is idle and jiggle it by 1 pixel.
*/
import java.awt.event.*;
import java.awt.AWTException;
import java.awt.MouseInfo;
import java.awt.Robot;

public class IdleMouse
{
    public static void main(String[] args) throws AWTException
    {
        Robot robot = new Robot();
        // If an argument is passed, the idle time is set to that value in
        // seconds. Otherwise, the default value is 5 seconds.
        int idleTime = args.length > 0 ? Integer.parseInt(args[0]) * 1000 : 5000;

        // Wait for the mouse to be idle for the specified time
        System.out.printf("Waiting for the mouse to be idle for %d seconds...%n", idleTime / 1000);
        waitForIdleMouse(idleTime);

        // Jiggle the mouse by 1 pixel
        System.out.println("Jiggling the mouse...");
        int x = MouseInfo.getPointerInfo().getLocation().x;
        int y = MouseInfo.getPointerInfo().getLocation().y;
        robot.mouseMove(x + 1, y);
        robot.mouseMove(x - 1, y);
        // robot.mouseMove(x, y);
    }

    public static void waitForIdleMouse(int idleTime)
    {
        long lastTime = System.currentTimeMillis();
        int x = MouseInfo.getPointerInfo().getLocation().x;
        int y = MouseInfo.getPointerInfo().getLocation().y;
    
        do
        {
            int xNew = MouseInfo.getPointerInfo().getLocation().x;
            int yNew = MouseInfo.getPointerInfo().getLocation().y;

            if (xNew != x || yNew != y)
            {
                System.out.printf("Mouse moved from (%d, %d) to (%d, %d)%n", x, y, xNew, yNew);
                lastTime = System.currentTimeMillis();
                x = MouseInfo.getPointerInfo().getLocation().x;
                y = MouseInfo.getPointerInfo().getLocation().y;
            }

            try
            {
                Thread.sleep(1000);
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
            }
        } while (System.currentTimeMillis() - lastTime < idleTime);
    }
}

