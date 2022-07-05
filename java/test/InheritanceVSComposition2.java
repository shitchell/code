interface Attack {
	public void move();
	public void attack();
}

class AttackImpl implements Attack {
	private String move;
	private String attack;
 
	public AttackImpl(String move, String attack) {
		this.move = move;
		this.attack = attack;
	}
 
	@Override
	public void move() {
		System.out.println(move);
	}
 
	@Override
	public void attack() {
		move();
		System.out.println(attack);
	}
}

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
}

class Bee extends Insect implements Attack {
	private Attack attack;
 
	public Bee(int size, String color, Attack attack) {
		super(size, color);
		this.attack = attack;
	}
 
	public void move() {
		attack.move();
	}
 
	public void attack() {
		attack.attack();
	}
}

public class InheritanceVSComposition2 {
	public static void main(String[] args) {
		Bee a = new Bee(1, "black", new AttackImpl("fly", "move"));
		a.attack();
 
		// if you need another implementation of move()
		// there is no need to change Insect, we can quickly use new method to attack
 
		Bee b = new Bee(1, "black", new AttackImpl("fly", "sting"));
		b.attack();
	}
}