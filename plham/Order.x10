package plham;

/**
 * A data structure for orders.
 * 
 * <p>Specify<ul>
 * <li> Type (kind): {buy, sell} x {limit, market}
 * <li> Price
 * <li> Volume
 * <li> Expiry time (relative)
 * </ul>
 */
public class Order {
	
	static struct Kind(id:Long) {}
	public static KIND_BUY_MARKET_ORDER = Kind(1);
	public static KIND_SELL_MARKET_ORDER = Kind(2);
	public static KIND_BUY_LIMIT_ORDER = Kind(3);
	public static KIND_SELL_LIMIT_ORDER = Kind(4);

	/** Use if a market order */
	public static NO_PRICE = Double.MAX_VALUE;
	
	public var kind:Kind;
	public var agentId:Long;
	public var marketId:Long;
	public var price:Double;
	public var volume:Long;
	/** The relative term until the expiry time (due time). */
	public var timeLength:Long;
	/** The time when this order is placed. I.e. <code>market.getTime()</code>. */
	public var timePlaced:Long;
	/** The order id used for consulting and to notify its execution (set to 0 if unnecessary; this is by default). */
	public var orderId:Long;
	
	/** Do not use this. */
	public def this(kind:Kind, agentId:Long, marketId:Long, price:Double, volume:Long, timeLength:Long, timePlaced:Long, orderId:Long) {
		assert price >= 0;
		assert volume >= 0;
		this.kind = kind;
		this.agentId = agentId;
		this.marketId = marketId;
		this.price = price;
		this.volume = volume;
		this.timeLength = timeLength;
		this.timePlaced = timePlaced;
		this.orderId = orderId;
	}

	/** Do not use this. */
	public def this(kind:Kind, agentId:Long, marketId:Long, price:Double, volume:Long, timeLength:Long, timePlaced:Long) {
		this(kind, agentId, marketId, price, volume, timeLength, timePlaced, 0);
	}

	public def this(kind:Kind, agent:Agent, market:Market, price:Double, volume:Long, timeLength:Long) {
		this(kind, agent.id, market.id, price, volume, timeLength, market.getTime(), agent.nextOrderId());
	}

	/**
	 * Create a copy.
	 */
	public def this(other:Order) {
		this.kind = other.kind;
		this.agentId = other.agentId;
		this.marketId = other.marketId;
		this.price = other.price;
		this.volume = other.volume;
		this.timeLength = other.timeLength;
		this.timePlaced = other.timePlaced;
		this.orderId = other.orderId;
	}
	
	public def getPrice():Double = this.price;

	public def setPrice(price:Double):Double = this.price = price;
	
	public def getVolume():Long = this.volume;

	public def setVolume(volume:Long):Long = this.volume = volume;
	
	/**
	 * Update the volume of this order by adding <code>delta</code>.
	 */
	public def updateVolume(delta:Long) {
		this.volume += delta;
		assert this.volume >= 0;
	}
	
	public def isBuyOrder():Boolean {
		return this.kind == Order.KIND_BUY_MARKET_ORDER || this.kind == Order.KIND_BUY_LIMIT_ORDER;
	}
	
	public def isSellOrder():Boolean {
		return this.kind == Order.KIND_SELL_MARKET_ORDER || this.kind == Order.KIND_SELL_LIMIT_ORDER;
	}
	
	public def isLimitOrder():Boolean {
		return this.kind == Order.KIND_BUY_LIMIT_ORDER || this.kind == Order.KIND_SELL_LIMIT_ORDER;
	}
	
	public def isMarketOrder():Boolean {
		return this.kind == Order.KIND_BUY_MARKET_ORDER || this.kind == Order.KIND_SELL_MARKET_ORDER;
	}

	/**
	 * Test if this is a cancel request for an order.
	 * @return true if instanceof <code>Cancel</code>
	 */
	public def isCancel():Boolean = this instanceof Cancel;
	
	/**
	 * Test if this order has been expired.
	 * @param market
	 * @return true if expired
	 */
	public def isExpired(market:Market):Boolean {
		assert this.marketId == market.id;
		return this.isExpired(market.getTime());
	}
	
	/**
	 * Test if this order has been expired.
	 * @param t
	 * @return true if expired
	 */
	public def isExpired(t:Long):Boolean {
		return this.timePlaced + this.timeLength < t;
	}
	
	public def toString():String {
		return this.typeName() + [this.getKindName(), "agent:" + this.agentId, "market:" + this.marketId, this.price, this.volume, this.timeLength, this.timePlaced, "id:" + this.orderId];
	}

	public def getKindName():String {
		if (this.kind == KIND_BUY_MARKET_ORDER) {
			return "BUY_MARKET_ORDER";
		}
		if (this.kind == KIND_SELL_MARKET_ORDER) {
			return "SELL_MARKET_ORDER";
		}
		if (this.kind == KIND_BUY_LIMIT_ORDER) {
			return "BUY_LIMIT_ORDER";
		}
		if (this.kind == KIND_SELL_LIMIT_ORDER) {
			return "SELL_LIMIT_ORDER";
		}
		return "UNKNOWN_KIND";
	}
}
