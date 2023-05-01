/**
 * Class: MyTestClass2
 * @author: Wei Jin
 * @version x.x
 * @course: ITEC 2150
 * Written: Month Date, 2023
 * Output based tests for program 2
 */

import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;

import static org.junit.Assert.assertEquals;

// Import anything else you need to run the tests, such as the students' classes

public class Test1_TriangleTest {
    private final double EPSILON = 0.00000000001;
    private String[] inputStrings = {"",
            "3.2\n4.1\n5.5\n",
            "a\n8.1\nb\n6.1\n1o\n10.2\n",
            "L\n1\n15\n2\n1\n1.5\n2\n"
    };
    private String[] outputStrings = {"",
            "Enter side 1:\n" +
                    "Enter side 2:\n" +
                    "Enter side 3:\n" +
                    "Triangle[3.2, 4.1, 5.5]",
            "Enter side 1:\n" +
                    "Not a value. Re-enter:\n" +
                    "Enter side 2:\n" +
                    "Not a value. Re-enter:\n" +
                    "Enter side 3:\n" +
                    "Not a value. Re-enter:\n" +
                    "Triangle[8.1, 6.1, 10.2]\n",
            "Enter side 1:\n" +
                    "Not a value. Re-enter:\n" +
                    "Enter side 2:\n" +
                    "Enter side 3:\n" +
                    "Sides 1.0, 15.0, and 2.0 cannot make a legal triangle.\n" +
                    "Enter side 1:\n" +
                    "Enter side 2:\n" +
                    "Enter side 3:\n" +
                    "Triangle[1.0, 1.5, 2.0]\n"
    };

    private void outputMatchingTest(String inputString, String outputString) {
        String teacherOutput = StringUtilities.trimEachLine(outputString);

        PrintStream stdOut = System.out;
        InputStream stdIn = System.in;

        ByteArrayOutputStream bos2 = new ByteArrayOutputStream();
        System.setOut(new PrintStream(bos2));
        System.setIn(new ByteArrayInputStream(inputString.getBytes(StandardCharsets.UTF_8)));
        TriangleTest.main(null); //students are expected to submit the file
        String studentOutput = StringUtilities.trimEachLine(bos2.toString());

        assertEquals(teacherOutput, studentOutput);

        System.setOut(stdOut);
        System.setIn(stdIn);
//        System.out.println(teacherOutput);
//        System.out.println(studentOutput);
    }

    @Test
    public void testTriangleTest1() { outputMatchingTest(inputStrings[1], outputStrings[1]); }
    @Test
    public void testTriangleTest2() { outputMatchingTest(inputStrings[2], outputStrings[2]); }
    @Test
    public void testTriangleTest3() { outputMatchingTest(inputStrings[3], outputStrings[3]); }
}
