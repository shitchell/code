class Person {
    public String name;
    public int age;

    public Person(String name, int age) {
        this.name = name;
        this.age = age;
    }

    // setName() is an instance method -- it is only
    // meant to be used when you create an instance
    // of a Person via `Person joe = new Person("joe", 18)`
    public void setName(String name) {
        // "this" right here refers to the "joe"
        // instance / variable above. i.e.:
        // this.name is the same as joe.name
        this.name = name;
    }

    // We use "static" when a function isn't dependent
    // on any particular instance of the object
    public static String getScientificName() {
        return "Homo sapiens"
    }

    public String toString() {
        return "Person(" + this.name + " - " + Person.getScientificName());
    }
}

class Math {
    public final double PI = 3.13;

    public static double calcCircleArea(double radius) {
        return Math.PI * radius * radius;
    }
}

// `this` in the person class is only used by *instances* of an object. so above,
// we use it inside the `setName()` function to set the name of a particular
// person. you use it by creating a new instance ,e.g. `joe`, and then calling
// `joe.setName("Joseph")`
// 
// but you can also have functions that *don't* depend on any particular instance.
// e.g. for `getScientificName()`, that doesn't matter whether it's joe or sarah or
// whoever -- that will always be the same. for those functions, you call them
// directly with the class like `Person.getScientificName()` -- no instance
// ecessary. the Math library is a good example of this :slight_smile: `PI` will
// never require an instance of an object to have a value -- it's always the
// same -- just like formulas for calculating area and such
