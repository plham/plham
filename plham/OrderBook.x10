package plham;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import cassia.util.HeapQueue;
import cassia.util.SortedQueue;

/**
 * A class for orderbooks for continuous double action mechanism.
 * Orders are arranged in the price/time priority basis.
 * Use HIGHERS_FIRST for buy side; Use LOWERS_FIRST for sell side.
 */
public class OrderBook {
	
	public var queue:SortedQueue[Order];
	public var cancels:ArrayList[Order]; // TODO: Poor implimentation.
	public var time:Time;
	
	public def this(comparator:(Order,Order)=>Int) {
		this.queue = new HeapQueue[Order](comparator);
		this.cancels = new ArrayList[Order]();
	}

	protected def setTime(time:Time) {
		this.time = time;
	}

	protected def getTime():Long {
		if (this.time == null) {
			return 0;
		}
		return this.time.t;
	}

	protected static CANCEL_SORTER = (one:Order, other:Order) => {
		if (one.agentId < other.agentId) {
			return -1n;
		}
		if (one.agentId > other.agentId) {
			return +1n;
		}
		if (one.price < other.price) {
			return -1n;
		}
		if (one.price > other.price) {
			return +1n;
		}
		if (one.timePlaced < other.timePlaced) {
			return -1n;
		}
		if (one.timePlaced > other.timePlaced) {
			return +1n;
		}
		return 0n;
	};

	/**
	 * Assume an order having ticksize-rounded price.
	 */
	public def cancel(order:Order) {
		val a = this.cancels;
		val i = a.binarySearch(order, CANCEL_SORTER);
		if (i >= 0) {
			a.addBefore(+i, order); // Keep sorted
		} else {
			a.addBefore(-i, order); // Keep sorted
		}
		//a.sort(CANCEL_SORTER);
	}

	public def isCancelled(order:Order):Boolean {
		val a = this.cancels;
		val i = a.binarySearch(order, CANCEL_SORTER);
		if (i >= 0) {
			//Console.OUT.println("#OrderBook#isCancelled: cancelled order found at " + i);
		}
		return i >= 0;
	}
	
	protected def popUntil() {
		val t = this.getTime();
		val q = this.queue;
		val n = q.size();
		while (q.size() > 0) {
			val order = q.peek();
			//if (isCancelled(order)) {
			if (order.isExpired(t) || isCancelled(order)) {
				q.pop();
			} else {
				break;
			}
		}
		if (n - q.size() > 0) {
			//Console.OUT.println("#OrderBook#popUntil: " + (n - q.size()) + " were popped");
		}
	}

	public def size():Long {
		this.popUntil();
		return this.queue.size();
	}
	
	public def add(order:Order) {
		this.queue.add(order);
	}
	
	public def remove(order:Order) {
		this.queue.remove(order);
	}

	/**
	 * Get the order at the best bid(buy)/ask(sell).
	 */
	public def getBestOrder():Order {
		this.popUntil();
		if (this.queue.size() > 0) {
			return this.queue.peek();
		}
		return null;
	}

	/**
	 * Get the price of the best bid(buy)/ask(sell) order.
	 */
	public def getBestPrice():Double {
		this.popUntil();
		if (this.queue.size() > 0) {
			return this.queue.peek().getPrice();
		}
		return Double.NaN;
	}

	/**
	 * Remove all orders satisfying the condition <code>p</code>.
	 */
	public def removeAllWhere(p:(Order)=>Boolean):Boolean {
		return this.queue.removeAllWhere(p);
	}

	public static LOWERS_FIRST = (one:Order, other:Order) => {
		if (one.price < other.price) {
			return -1n;
		}
		if (one.price > other.price) {
			return +1n;
		}
		if (one.timePlaced < other.timePlaced) {
			return -1n;
		}
		if (one.timePlaced > other.timePlaced) {
			return +1n;
		}
		return 0n;
	};
	
	public static HIGHERS_FIRST = (one:Order, other:Order) => {
		if (one.price > other.price) {
			return -1n;
		}
		if (one.price < other.price) {
			return +1n;
		}
		if (one.timePlaced < other.timePlaced) {
			return -1n;
		}
		if (one.timePlaced > other.timePlaced) {
			return +1n;
		}
		return 0n;
	};

	public static def dump(it:Iterator[Order], time:Long) {
		while (it.hasNext()) {
			val order = it.next();
			Console.OUT.println(StringUtil.formatArray([
				"#BOOK", time, order.kind.id, order.marketId, order.price, order.volume,
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

	public static def dump(orders:List[Order], time:Long) {
		dump(orders.iterator(), time);
	}

	/**
	 * Dump this orderbook with the time-stamp in an <i>undefined</i> order.
	 */
	public def dump() {
		dump(this.queue.iterator(), this.getTime());
	}

	/**
	 * Dump this orderbook with the time-stamp in the <i>specified</i> order.
	 */
	public def dump(comparator:(Order,Order)=>Int) {
		val orders = this.toList(comparator);
		dump(orders, this.getTime());
	}

	/**
	 * Get all orders in this orderbook sorted in an <i>undefined</i> order.
	 */
	public def toList():List[Order] {
		return this.queue.toList();
	}

	/**
	 * Get all orders in this orderbook sorted in the <i>specified</i> order.
	 */
	public def toList(comparator:(Order,Order)=>Int):List[Order] {
		val orders = this.toList();
		orders.sort(comparator);
		return orders;
	}

	public static def main(Rail[String]) {
		val agent = new Agent(0);
		val market = new Market(0);
		val book = new OrderBook(HIGHERS_FIRST);
		book.add(new Order(Order.KIND_BUY_LIMIT_ORDER, agent.id, market.id, 100.0, 10, 30, 1));
		book.add(new Order(Order.KIND_BUY_LIMIT_ORDER, agent.id, market.id, 50.0, 10, 30, 2));
		book.add(new Order(Order.KIND_BUY_LIMIT_ORDER, agent.id, market.id, 50.0, 40, 30, 3));
		book.add(new Order(Order.KIND_BUY_LIMIT_ORDER, agent.id, market.id, 100.0, 10, 30, 4));
		book.add(new Order(Order.KIND_BUY_LIMIT_ORDER, agent.id, market.id, 70.0, 10, 30, 4));

		Console.OUT.println("THE BEST: " + book.getBestOrder());

		Console.OUT.println("LOWERS-FIRST");
		book.dump(LOWERS_FIRST);

		Console.OUT.println("HIGHERS-FIRST");
		book.dump(HIGHERS_FIRST);
	}
}
