public class IllegalTriangleSideException extends Exception {
  public IllegalTriangleSideException(double side1, double side2, double side3) {
    super(side1 + ", " + side2 + ", " + side3 + " cannot make a legal triangle");
  }
}
