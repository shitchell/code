public class Triangle {
private double a,b,c;
    @Override
    public String toString() {
        return "Triangle[" + a + ", " + b + ", " + c + ']';
    }

    public Triangle(double a, double b, double c) throws IllegalTriangleSideException {
        this.a = a;
        this.b = b;
        this.c = c;

        checkSides(a, b, c);

    }

    void checkSides(double a, double b, double c) throws IllegalTriangleSideException {

        if (a + b < c || b + c < a || a + c < b) {
            /*throw Exception*/
            throw new IllegalTriangleSideException(a, b, c);
        } else {
            System.out.println(String.format("Triangle[%.1f, %.1f, %.1f]", a, b, c));
        }
    }
}
