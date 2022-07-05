import java.util.Scanner;

public class NextLineScannerExample
{
    public static void main(String[] args)
    {
        Scanner keyboard = new Scanner(System.in);

        System.out.print("Enter your age: ");
        int age = keyboard.nextInt();
        System.out.print("Enter your name: ");
        String name = keyboard.nextLine();
    }
}