package plham;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.HashSet;
import x10.util.Set;
import x10.util.Pair;
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
	public var time:Time;

	/** A cache for cancel management. */
	protected var cancelCache:Set[Key] = new HashSet[Key](); // Poor implimentation.
	
	public def this(comparator:(Order,Order)=>Int) {
		this.queue = new HeapQueue[Order](comparator);
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

	/** For system use only. */
	protected def popUntil() {
		val t = this.getTime();
		val q = this.queue;
		val n = q.size();
		while (q.size() > 0) {
			val order = q.peek();
			if (order.isExpired(t) || isCancelled(order)) {
				q.pop();
				cancelCache.remove(new Key(order));
			} else {
				break;
			}
		}
		//if (n - q.size() > 0) Console.OUT.println("#OrderBook#popUntil: " + (n - q.size()) + " were popped");
	}

	public def size():Long {
		this.popUntil();
		return this.queue.size();
	}

	public def add(order:Order) {
		this.queue.add(order);
	}
	
	public def remove(order:Order) {
		if (this.queue.remove(order)) {
			cancelCache.remove(new Key(order));
		}
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
	 * Remove all orders satisfying the condition <code>p</code>.
	 */
	public def removeAllWhere(p:(Order)=>Boolean):Boolean {
		//for (o in this.queue) { if (isCancelled(o)) Console.OUT.println("#isCancelled but isInQueue " + o); }
		val f = (order:Order) => { // A wrapper
			val b = p(order);
			if (b) cancelCache.remove(new Key(order));
			return b;
		};
		return this.queue.removeAllWhere(f);
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
	 * Cancel the order.
	 * This should not be called directly by agents.
	 * Use {@link plham.Cancel} instead.
	 * @param order  a cancel request
	 */
	public def cancel(order:Order) {
		assert order.orderId > 0 : "Cancel requests must have orderId > 0";
		if (order.orderId > 0) {
			cancelCache.add(new Key(order));
			//Console.OUT.println("#OrderBook#cancel: " + order);
		}
	}

	/**
	 * Test if the order (having <code>agentId</code> and <code>orderId</code>) is requested for cancel.
	 * @param order
	 * @return
	 * @see plham.Cancel
	 */
	public def isCancelled(order:Order):Boolean = cancelCache.contains(new Key(order));

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

	/** For system use only. */
	protected static struct Key {

		val agentId:Long;
		val orderId:Long;

		def this(order:Order) {
			this(order.agentId, order.orderId);
		}

		def this(agentId:Long, orderId:Long) {
			this.agentId = agentId;
			this.orderId = orderId;
		}
	}

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
