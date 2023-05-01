import java.util.InputMismatchException;
import java.util.Scanner;

/**
 * Main method for exercise 3- chapter 4
 *
 * @author cjohns25, wjin
 *
 */
public class TriangleTest{

    /**
     * @param args
     */
    public static void main(String[] args) {

        //TODO: use exception handling and loop to make sure creating a valid triangle.
        /*make Scanner Object and variable declare*/
        Scanner sc = new Scanner(System.in);
        Triangle t;
        do {
            /*declare variable*/
            double side1, side2, side3;
            /*try catch for handle Exception*/
            try {
                /*take user input*/
                System.out.println("Enter side 1:");
                side1 = getADouble(sc);
                System.out.println("Enter side 2:");
                side2 = getADouble(sc);
                System.out.println("Enter side 3:");
                side3 = getADouble(sc);
                /*make Object of Triangle class*/
                t = new Triangle(side1, side2, side3);
            } catch (IllegalTriangleSideException e) {
                /*print Exception message*/
                System.out.println(e.getMessage());
            }
        } while (true);
    }


    public static double getADouble (Scanner input){
        //TODO: Define this method which can deal with exceptions if inputs are not double.
        //      Repeat until get a valid double value and return the value.
        double number;

        while (true) {
            String numberString = input.nextLine();

            try {
                number = Double.parseDouble(numberString);
                break;
            } catch (NumberFormatException ex) {
                System.out.println("Not an double. Reenter: ");
            }
        }
        return number;
    }
}
