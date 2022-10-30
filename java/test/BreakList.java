import java.util.Arrays;
import java.util.ArrayList;
import java.util.Random;

class BreakList {
    // public void breakListGoddess() {
        // for (int i = 0; i < BIGARRAY.getList().size(); i++) {
            // if (i < 2000000) {
                // list1.add(i);
            // } else if (i < 4000000) {
                // list2.add(i);
            // } else if (i < 6000000) {
                // list3.add(i);
            // } else if (i < 8000000) {
                // list4.add(i);
            // } else {
                // list5.add(i);
            // }
        // }
    // }

    public static int[][] breakListGoddess(int[] arr) {
        ArrayList<Integer> list1 = new ArrayList<>();
        ArrayList<Integer> list2 = new ArrayList<>();
        ArrayList<Integer> list3 = new ArrayList<>();
        ArrayList<Integer> list4 = new ArrayList<>();
        ArrayList<Integer> list5 = new ArrayList<>();
        for (int i = 0; i < arr.length; i++) {
            // System.out.printf("[breakListGoddess] [%d/%d]\n", i, arr.length);
            if (i < 20) {
                list1.add(arr[i]);
            } else if (i < 40) {
                list2.add(arr[i]);
            } else if (i < 60) {
                list3.add(arr[i]);
            } else if (i < 80) {
                list4.add(arr[i]);
            } else {
                list5.add(arr[i]);
            }
        }
        // return all of the arrays in a single container array
        return new int[][] {
            list1.stream().mapToInt(i -> i).toArray(),
            list2.stream().mapToInt(i -> i).toArray(),
            list3.stream().mapToInt(i -> i).toArray(),
            list4.stream().mapToInt(i -> i).toArray(),
            list5.stream().mapToInt(i -> i).toArray()
        };
    }

    public static ArrayList<ArrayList<Integer>> breakListGoddess(ArrayList<Integer> list) {
        ArrayList<Integer> list1 = new ArrayList<>();
        ArrayList<Integer> list2 = new ArrayList<>();
        ArrayList<Integer> list3 = new ArrayList<>();
        ArrayList<Integer> list4 = new ArrayList<>();
        ArrayList<Integer> list5 = new ArrayList<>();
        for (int i = 0; i < list.size(); i++) {
            if (i < 20) {
                list1.add(list.get(i));
            } else if (i < 40) {
                list2.add(list.get(i));
            } else if (i < 60) {
                list3.add(list.get(i));
            } else if (i < 80) {
                list4.add(list.get(i));
            } else {
                list5.add(list.get(i));
            }
        }
        // return all of the sublists in a single container list
        return new ArrayList<>(Arrays.asList(
            list1, list2, list3, list4, list5
        ));
    }

    public static int[][] breakListGuy(int[] list, int count) {
        // determine how long each subarray should be
        int innerLength = (int) Math.ceil((float) list.length / count);
        // create the array which will hold the subarrays
        int[][] containerArray = new int[count][innerLength];
        // loop over each subarray adding each next item from the list.
        //   arr_i tracks which subarray we're adding items to
        //   cell_i tracks the index inside the subarray
        //   listIndex tracks each next item in `list` that we're copying
        // each for loop has a second condition to stop once `listIndex` is
        // larger than the size of `list`, meaning we've copied all of the items
        int listIndex = 0;
        for (int arr_i = 0; arr_i < count && listIndex < list.length; arr_i++) {
            for (int cell_i = 0; cell_i < innerLength && listIndex < list.length; cell_i++) {
                containerArray[arr_i][cell_i] = list[listIndex++];
            }
        }
        return containerArray;
    }

    public static ArrayList<ArrayList<Integer>> breakListGuy(ArrayList<Integer> list, int count) {
        // determine how long each subarray should be
        int innerSize = (int) Math.ceil((float) list.size() / count);
        ArrayList<ArrayList<Integer>> containerList = new ArrayList<>();
        // loop `count` times to create `count` sublists of size `innerSize`
        //   list_i tracks which sublist we're creating
        //   cell_i tracks the index inside the subarray
        //   listIndex tracks each next item in `list` that we're copying
        // each for loop has a second condition to stop once `listIndex` is
        // larger than the size of `list`, meaning we've copied all of the items
        int listIndex = 0;
        for (int list_i = 0; list_i < count && listIndex < list.size(); list_i++) {
            ArrayList<Integer> innerList = new ArrayList<>();
            for (int cell_i = 0; cell_i < innerSize && listIndex < list.size(); cell_i++) {
                innerList.add(list.get(listIndex++));
            }
            containerList.add(innerList);
        }
        return containerList;
    }

    /*
     * Return an array of size `size` populated with random integers
     */
    public static int[] generateArray(int size) {
        int[] arr = new int[size];
        Random rand = new Random();
        for (int i = 0; i < size; i++) {
            arr[i] = rand.nextInt(10);
        }
        return arr;
    }

    public static ArrayList<Integer> generateList(int size, int randMax) {
        ArrayList<Integer> list = new ArrayList<>();
        Random rand = new Random();
        for (int i = 0; i < size; i++) {
            list.add(rand.nextInt(randMax));
        }
        return list;
    }
    public static ArrayList<Integer> generateList(int size) {
        return generateList(size, 10);
    }

    public static void print1dArray(int[] arr) {
        System.out.printf(
            "int[%d] -> %s\n",
            arr.length, Arrays.toString(arr));
    }

    public static void print2dArray(int[][] arr) {
        // get the number of subarrays
        int subArrayCount = arr.length;
        // get the size of each subarray
        int subArrayLength = arr[0].length;
        System.out.printf("int[%d][%d] -> [\n", subArrayCount, subArrayLength);
        // Print the contents of each subarray
        Arrays.stream(arr).forEach(a->System.out.printf("  %s\n", Arrays.toString(a)));
        System.out.println("]");
    }

    public static void print2dList(ArrayList<ArrayList<Integer>> list) {
        System.out.printf("ArrayList[%d] -> [\n", list.size());
        for (ArrayList<Integer> subList : list) {
            System.out.printf("  %s\n", subList);
        }
        System.out.println("]");
    }

    public static ArrayList<Integer> arrayToArrayList(int[] arr) {
        ArrayList<Integer> list = new ArrayList<>();
        for (int i : arr) {
            list.add(i);
        }
        return list;
    }
    
    public static double sumArray(int[] arr) {
        return Arrays.stream(arr).sum();
    }

    public static double sumList(ArrayList<Integer> list) {
        return list.stream().mapToDouble(i->i).sum();
    }

    public static int[] testArrays(int[] testArr) {
        System.out.println("--- Using arrays ---");
        System.out.println();

        // break it into 5 subarrays using each method
        int[][] dividedArrayGoddess = breakListGoddess(testArr);
        int[][] dividedArrayGuy = breakListGuy(testArr, 5);
        
        // print out each
        System.out.println("breakListGoddess():");
        print2dArray(dividedArrayGoddess);
        System.out.println("\nbreakListGuy():");
        print2dArray(dividedArrayGuy);
        return testArr;
    }
    public static int[] testArrays() {
        // create an array of size 100
        int[] testArr = generateArray(100);
        System.out.println("Generated array:");
        print1dArray(testArr);
        System.out.println();
        testArrays(testArr);
        return testArr;
    }

    public static ArrayList<Integer> testLists(ArrayList<Integer> testList) {
        System.out.println("--- Using ArrayLists ---");
        System.out.println();

        // break it into 5 subarrays using each method
        ArrayList<ArrayList<Integer>> dividedListGoddess = breakListGoddess(testList);
        ArrayList<ArrayList<Integer>> dividedListGuy = breakListGuy(testList, 5);
        
        // print out each
        System.out.println("breakListGoddess():");
        print2dList(dividedListGoddess);
        System.out.println("\nbreakListGuy():");
        print2dList(dividedListGuy);
        return testList;
    }
    public static ArrayList<Integer> testLists() {
        // create an array of size 100
        ArrayList<Integer> testList = generateList(100);
        System.out.println("Generated list:");
        System.out.println(testList);
        System.out.println();
        testLists(testList);
        return testList;
    }
   
    public static void main(String[] args) {
        // int[] testArr = testArrays();
        // // convert the generated array to an ArrayList
        // ArrayList<Integer> testList = arrayToArrayList(testArr);
        // System.out.println();
        // testLists(testList);
        
        // generate a list
        int listSize = 10_000_000;
        int subListCount = 5;
        int maxValue = 999_999;
        ArrayList<Integer> testList = generateList(listSize, maxValue);

        // break it into 5 smaller lists
        ArrayList<ArrayList<Integer>> containerList = breakListGuy(testList, subListCount);
        
        // print info about the list and its sublists
        System.out.println("Generated main list:");
        System.out.printf("  - size %,d\n  - values  0-%,d\n  - sum %,.0f\n",
                          testList.size(), maxValue, sumList(testList));
        System.out.printf("Divided into %d sublists:\n", containerList.size());
        for (ArrayList<Integer> subList : containerList) {
            System.out.printf("  ArrayList<Integer> size %,d, sum %,.0f\n", subList.size(), sumList(subList));
        }
    }
}