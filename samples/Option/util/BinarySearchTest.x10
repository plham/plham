import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;

public class BinarySearchTest {

	public static def main(Rail[String]) {
		val random = new Random();

		val n = 10;

		val prices = new ArrayList[Double]();
		for (t in 1..n) {
			prices.add(300 + random.nextDouble() * 50);
		}
		prices.sort();

		for (t in 0..(n - 1)) {
			Console.OUT.printf("%03d %f\n", t, prices(t));
		}

		for (price in prices) {
			val j = prices.binarySearch(price);
			val i = (j >= 0) ? j : -j - 1; // Insertion point
			Console.OUT.println("Searching " + price + " gets " + j);
			Console.OUT.println("  Insert point: " + i);
			if (i > 0) {
				Console.OUT.println("  After  " + prices(i - 1));
			}
			if (i < n - 1) {
				Console.OUT.println("  Before " + prices(i + 0));
			}
			Console.OUT.println("  Nearest " + ListUtils.binarySearchNearest(prices, price));
		}
		for (t in 1..10) {
			val price = 300 + random.nextDouble() * 100 - 50;
			val j = prices.binarySearch(price);
			val i = (j >= 0) ? j : -j - 1; // Insertion point
			Console.OUT.println("Searching " + price + " gets " + j);
			Console.OUT.println("  Insert point: " + i);
			if (i > 0) {
				Console.OUT.println("  After  " + prices(i - 1));
			}
			if (i < n - 1) {
				Console.OUT.println("  Before " + prices(i + 0));
			}
			Console.OUT.println("  Nearest " + ListUtils.binarySearchNearest(prices, price));
		}
	}
}
