import java.time.format.DateTimeFormatter;
import java.time.LocalDateTime;

@SafeVarargs 
public static <T extends Object> void log(int logLevel, T... objs) {
    int globalLogLevel;
    DateTimeFormatter timeFormatter;
    String timestamp;

    // If the DEBUG environment variable isn't an int, do nothing
    try {
        globalLogLevel = Integer.parseInt(System.getenv("DEBUG"));
    } catch (Exception e) {
        return;
    }

    // Only print log messages if DEBUG is >= the debug message's log level
    if (globalLogLevel >= logLevel) {
        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");
        timestamp = dtf.format(LocalDateTime.now());
        for (Object obj : objs) {
        	// Convert the object to a string
        	String objString = String.format("%s", obj);
            // Prefix each line with a timestamp
            for (String line : objString.split("\n")) {
                System.out.printf("[%s] %s\n", timestamp, line);
            }
        }
    }
}
