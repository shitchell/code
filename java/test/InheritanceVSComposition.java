class Insect {
	private int size;
	private String color;
 
	public Insect(int size, String color) {
		this.size = size;
		this.color = color;
	}
 
	public int getSize() {
		return size;
	}
 
	public void setSize(int size) {
		this.size = size;
	}
 
	public String getColor() {
		return color;
	}
 
	public void setColor(String color) {
		this.color = color;
	}
 
	public void move() {
		System.out.println("Move");
	}
 
	public void attack() {
		move(); //assuming an insect needs to move before attacking
		System.out.println("Attack");
	}
}


class Bee extends Insect {
	public Bee(int size, String color) {
		super(size, color);
	}
 
	public void move() {
		System.out.println("Fly");
	}
 
	public void attack() {
		move();
		super.attack();
	}
}

public class InheritanceVSComposition {
	public static void main(String[] args) {
		Insect i = new Bee(1, "red");
		i.attack();
	}
}