import java.util.Scanner;
import java.util.InputMismatchException;

public class TriangleTest {
  public static void main(String[] args) throws IllegalTriangleSideException {
    System.out.println("Raising IllegalTriangleSideException");
    Scanner stdin = new Scanner(System.in);
    double foo = getDouble(stdin);
    System.out.println("You entered " + foo);
    throw new IllegalTriangleSideException(1, 2, 3);
  }

  public static double getDouble(Scanner input) {
    System.out.print("Enter a double: ");
    while (!input.hasNextDouble()) {
      System.out.print("Invalid number, please re-enter: ");
      // Consume the newline from the user hitting enter
      input.nextLine();
    }

    return input.nextDouble();
  }
}