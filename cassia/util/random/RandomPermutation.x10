package cassia.util.random;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;

/**
 * Knuth-Fisher-Yates shuffle.
 * Reference: http://en.wikipedia.org/wiki/Fisher-Yates_shuffle
 */
public class RandomPermutation[T] implements Iterable[T] {
	
	public var array:List[T];
	public var random:Random;
	
	public def this(random:Random, array:List[T]) {
		this.random = random;
		this.array = array.clone() as List[T];
	}

	/**
	 * Randomize the array.
	 */
	public def shuffle() {
		val size = this.array.size();
		for (var i:Long = size - 1; i > 0; i--) {
			val j = this.random.nextLong(i + 1);
			val temp = this.array(j);
			this.array(j) = this.array(i);
			this.array(i) = temp;
		}
	}
	
	public def iterator():Iterator[T] {
		return this.array.iterator();
	}

	public def toString():String {
		return this.array.toString();
	}
	
	public static def main(Rail[String]) {
		val a = new ArrayList[Long]();
		a.add(1);
		a.add(2);
		a.add(3);
		a.add(100);
		a.add(999);
		
		val p = new RandomPermutation(new Random(), a); // MEMO: main()
		for (i in 0..10) {
			Console.OUT.println(p);
			p.shuffle();
		}
	}
}
