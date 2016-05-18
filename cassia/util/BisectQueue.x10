package cassia.util;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;

/**
 * An implementation of internal order-preserving array (queue).
 * The bisect algorithm is imported from Python 2.7.
 */
public class BisectQueue[T] implements SortedQueue[T] {

	public var list:List[T];
	public var comparator:(T,T)=>Int;
	
	public def this(comparator:(T,T)=>Int) {
		this.list = new ArrayList[T]();
		this.comparator = comparator;
	}

	public def push(x:T):Boolean {
		val i = this.bisect(x);
		this.list.addBefore(i, x);
		return true;
	}

	public def pop():T {
		val x = this.list.removeAt(0); // Tail-based array is probably better.
		return x;
	}

	public def peek():T = this.list(0);

	public def add(x:T):Boolean {
		return this.push(x);
	}

	public def remove(x:T):Boolean {
		return this.list.remove(x);
	}

	public def removeAllWhere(p:(T)=>Boolean):Boolean {
		val a = this.list;
		val n = a.size();
		var i:Long = 0;
		while (i < a.size()) {
			if (p(a(i))) {
				val last = a.removeLast();
				if (i < a.size()) {
					a(i) = last;
				}
			} else {
				i++;
			}
		}
		if (i < n) {
			this.list.sort(this.comparator);
		}
		return i < n;
	}

	public def size() = this.list.size();

	public def contains(x:T) = this.list.contains(x);

	public def iterator() = this.list.iterator();

	public def toList():List[T] = this.list.clone() as List[T];

	public operator this(i:Long) = this.list(i);

	public def subList(begin:Long, end:Long) = this.list.subList(begin, end);

	public def bisect(x:T):Long {
		var lo:Long = 0;
		var hi:Long = this.list.size();

		while (lo < hi) {
			val mid = (lo + hi) / 2;
			val p = this.list(mid);
			val cmp = this.comparator(x, p);
			if (cmp < 0) {
				hi = mid;
			} else {
				lo = mid + 1;
			}
		}
		return lo;
	}

	public static def main(Rail[String]) {
		var last:Long;
		var q:SortedQueue[Long];
		val random = new Random(); // MEMO: main()

		// Test a min-heap.
		Console.OUT.println("# MIN-QUEUE");
		q = new BisectQueue[Long]((x:Long, y:Long)=> Math.signum(x - y) as Int); // min-heap
		for (i in 0..10) {
			q.push(random.nextLong(10) - 5);
		}
		last = Long.MIN_VALUE;
		for (i in 0..10) {
			Console.OUT.println(q.toList());
			val x = q.pop();
			Console.OUT.println(x);
			assert last <= x;
			last = x;
		}

		// Test a max-heap.
		Console.OUT.println("# MAX-QUEUE");
		q = new BisectQueue[Long]((x:Long, y:Long)=> Math.signum(y - x) as Int); // max-heap
		for (i in 0..10) {
			q.push(random.nextLong(10) - 5);
		}
		last = Long.MAX_VALUE;
		for (i in 0..10) {
			Console.OUT.println(q.toList());
			val x = q.pop();
			Console.OUT.println(x);
			assert last >= x;
			last = x;
		}

		// Test for the remove operation.
		Console.OUT.println("# remove()");
		q = new BisectQueue[Long]((x:Long, y:Long)=> Math.signum(x - y) as Int);
		q.push(-5);
		q.push(0);
		q.push(0);
		q.push(+5);
		Console.OUT.println(q.toList());
		q.remove(0);
		Console.OUT.println(q.toList());
		q.remove(0);
		Console.OUT.println(q.toList());
		q.remove(+5);
		Console.OUT.println(q.toList());
		q.remove(-5);
		Console.OUT.println(q.toList());

		// Test for removeAllWhere().
		Console.OUT.println("# removeAllWhere()");
		q = new BisectQueue[Long]((x:Long, y:Long)=> Math.signum(y - x) as Int); // max-heap
		for (i in 0..10) {
			q.push(random.nextLong(10) - 5);
		}
		Console.OUT.println(q.toList());
		q.removeAllWhere((i:Long) => i < 0);
		Console.OUT.println(q.toList());
	}
}

