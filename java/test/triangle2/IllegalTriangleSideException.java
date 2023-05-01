/*TODO: define the class as a subclass of Exception. The error message stored in the
  Exception object should be of the following format: "s1, s2, and s3 cannot make a legal triangle."
  s1, s2, and s3 are valued for the three sides of the intended triangle.
 */
public class IllegalTriangleSideException extends Exception {
    /*call Exception*/
   public IllegalTriangleSideException(double a, double b, double c)
    {
        super ("Sides " + a + ", " + b + ", and" + c + " cannot make a legal triangle.");
    }
}
