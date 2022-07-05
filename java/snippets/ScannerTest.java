import java.io.FileWriter;
import java.io.IOException;
import java.util.Scanner;

public class ScannerTest
{
    
    public static void main(String[] args)
    {
        // create a log file so that we can see what each
        // Scanner.next___() method is returning without
        // printing it to the screen and messing up the flow
        Logger logger = new Logger("ScannerTest.log");
        Scanner keyboard = new Scanner(System.in);

        // test
        System.out.print("Enter a number and a word\n> ");
        int num = keyboard.nextInt();
        keyboard.skip("o");
        String word = keyboard.nextLine();
        logger.log("nextInt:num", num);
        logger.log("nextLine:word", word);
        
        // get the user's name
        System.out.print("Enter your first and last name\n> ");
        String firstName = keyboard.next();
        String lastName = keyboard.next();
        logger.log("nextLine:firstName", firstName);
        logger.log("nextLine:lastName", lastName);

        System.out.print("How old are you?\n> ");
        int age = keyboard.nextInt();
        logger.log("nextInt:age", age);

        System.out.print("What is your birth month?\n> ");
        String birthMonth = keyboard.nextLine();
        logger.log("nextLine:birthMonth", birthMonth);
        logger.log("birthMonth:empty", birthMonth.equals(""));
        logger.log("birthMonth:newline", birthMonth.equals("\n"));
        
        System.out.print("How many classes are you taking this semester?\n> ");
        int classNum = keyboard.nextInt();
        logger.log("nextInt:classNum", classNum);
        
        System.out.print("Enter two numbers:\n> ");
        int num1 = keyboard.nextInt();
        int num2 = keyboard.nextInt();
        logger.log("nextInt:num1", num1);
        logger.log("nextInt:num2", num2);
        
        System.out.print("Enter a string:\n> ");
        String someString = keyboard.nextLine();
        logger.log("nextLine:someString", someString);
    }
}

class Logger
{
    FileWriter logFile;
    
    Logger(String filepath)
    {
        setLogFile(filepath);
    }
    Logger()
    {
        this("log.txt");
    }

    public void setLogFile(String filepath) {
        if (this.logFile != null)
        {
            // close the last log file if it exists
            try
            {
                this.logFile.close();
            } catch (IOException e) {}
        }
        
        try
        {
            this.logFile = new FileWriter(filepath);
        } catch (IOException e) {}
    }

    public void log(String subject, Object... objects)
    {
        for (Object object : objects)
        {
            // replace newlines with \n so you can see the newline
            String objectString = object.toString().replace("\n", "\\n");
            String line = String.format("[%s] %s\n", subject, object.toString());
            try
            {
                this.logFile.write(line);
                this.logFile.flush();
            } catch (IOException e) {
                System.err.println("failed to write to logfile!");
            }
        }
    }
}