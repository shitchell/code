import java.util.function.BiFunction;
import java.util.HashMap;

public class CalcExamples
{
    private int calc(int operand1, int operand2, String operator)
    throws InvalidOperatorException
    {
        return switch (operator)
        {
            case "+" -> operand1 + operand2;
            case "-" -> operand1 - operand2;
            case "/" -> operand1 / operand2;
            case "*" -> operand1 * operand2;
            default -> throw new InvalidOperatorException(
                "'" + operator + "' is not a supported mathematical operator"
            );
        }
    }

    private int calc(int operand1, int operand2, String operator)
    throws InvalidOperatorException
    {
        Map<String, BiFunction<Integer, Integer, Integer>> operations = Map.of(
            "+", (a, b) -> a + b,
            "-", (a, b) -> a - b,
            "/", (a, b) -> a / b,
            "*", (a, b) -> a * b
        );
        if (operations.containsKey(operator))
        {
            return operations.get(operator).apply(operand1, operand2);
        } else {
            String errMsg = String.format(
                "'%s' is not one of %s",
                operator, operations.keySet()
            );
            throw new InvalidOperatorException(errMsg);
        }
    }

    private <T extends Number> T calc(T operand1, T operand2, String operator)
    throws InvalidOperatorException
    {
        double o1 = (double) operand1;
        double o2 = (double) operand2;
        Map<String, BiFunction<Double, Double, Double>> operations = Map.of(
            "+", (a, b) -> a + b,
            "-", (a, b) -> a - b,
            "/", (a, b) -> a / b,
            "*", (a, b) -> a * b
        );
        if (operations.containsKey(operator))
        {
            return (T) operations.get(operator).apply(o1, o2);
        } else {
            String errMsg = String.format(
                "'%s' is not one of %s",
                operator, operations.keySet()
            );
            throw new InvalidOperatorException(errMsg);
        }
    }
}

class InvalidOperatorException extends RuntimeException
{
    public InvalidOperatorException(String msg)
    {
        super(msg);
    }
}
