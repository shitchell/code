for (int i = 0; i < 5; i++) {
  System.out.println("loop " + i);
}

int i = 0;
while (i < 5) {
  System.out.println("loop " + i);
  i++;
}

Scanner stdin = new Scanner(System.in);
System.out.println("Enter 5 numbers:");

// the sane person's while loop solution
ArrayList<Integer> ints = new ArrayList<>();
while (ints.size() < 5) {
  int nextInt = stdin.nextInt();
  ints.add(nextInt);
}

// or a for loop with no body because why not
for (ArrayList<Integer> ints = new ArrayList<>();
     ints.size() < 5;
     ints.add(stdin.nextInt());
