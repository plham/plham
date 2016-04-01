package plham;
import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.List;
import x10.util.Map;
import x10.util.Random;

/**
 * The base class for agents.
 * 
 * <p><ul>
 * <li> Override <code>submitOrders(List[Market])</code> to implement a trading strategy.
 * <li> Only overriding <code>submitOrders(Market)</code> would not work expectedly.
 * <li> Do not call <code>Market#handleOrders(List[Order])</code> in <code>submitOrders(List[Market])</code> family.
 * <li> Call <code>setMarketAccessible(Market)</code> to tell the agent to enter that market.
 * <li> Without calling <code>setMarketAccessible(Market)</code>, <code>getAssetVolume(Market)</code> will raise an error.
 * <li> Use <code>getRandom()</code> and do NOT make <code>new Random()</code>.
 * </ul>
 */
public class Agent {
	
	/** The id of this agent assigned by the system (DON'T CHANGE IT). */
	public var id:Long;
	/** The JSON object name (DON'T CHANGE IT). */
	public var name:String;
	/** The RNG given by the system (DON'T CHANGE IT). */
	public var random:Random;

	/** For system use only. */
	public def setId(id:Long):Long = this.id = id;

	/** For system use only. */
	public def setName(name:String):String = this.name = name;

	/** @return An instance of Random (derived from the root). */
	public def getRandom():Random = this.random;

	/** For system use only. */
	public def setRandom(random:Random):Random = this.random = random;


	/** The amount of cash. */
	public var cashAmount:Double;
	/** A mapping from markets (id) to the volumes of the assets. */
	public var assetsVolumes:Map[Long,Long];

	public def this(id:Long) {
		this.id = id;
		this.cashAmount = 0.0;
		this.assetsVolumes = new HashMap[Long,Long]();
	}

	public def this() {
		this(-1);
	}

	/**
	 * Submit orders to the markets.
	 * This method will be invoked by the system.
	 * @param markets  a list of all markets (but some may not be up-to-date).
	 * @return a list of orders.
	 */
	public def submitOrders(markets:List[Market]):List[Order] {
		/* This implementation is to be a test-friendly base class. */
		val orders = new ArrayList[Order]();
		for (market in markets) {
			orders.addAll(this.submitOrders(market));
		}
		return orders;
	}

	/**
	 * Submit orders to the market.
	 * This method will <b>NOT</b> be invoked by the system; so override <code>submitOrders(List[Market])</code>.
	 * @param markets  a list of all markets (but some may not be up-to-date).
	 * @return a list of orders.
	 */
	public def submitOrders(market:Market):List[Order] {
		/* This implementation is to be a test-friendly base class. */
		val MARGIN_SCALE = 10.0;
		val VOLUME_SCALE = 100;
		val TIME_LENGTH_SCALE = 100;
		val BUY_CHANCE = 0.4;
		val SELL_CHANCE = 0.4;

		val orders = new ArrayList[Order]();
		
		if (this.isMarketAccessible(market)) {
			val random = getRandom();
			val marketTime = market.getTime();
			val price = market.getPrice() + (random.nextDouble() * 2 * MARGIN_SCALE - MARGIN_SCALE);
			val volume = random.nextLong(VOLUME_SCALE) + 1;
			val timeLength = random.nextLong(TIME_LENGTH_SCALE) + 10;
			val p = random.nextDouble();
			if (p < BUY_CHANCE) {
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this.id, market.id, price, volume, timeLength, marketTime));
			} else if (p < BUY_CHANCE + SELL_CHANCE) {
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this.id, market.id, price, volume, timeLength, marketTime));
			}
		}
		return orders;
	}

	public def isMarketAccessible(id:Long) = this.assetsVolumes.containsKey(id);

	public def isMarketAccessible(market:Market) = this.isMarketAccessible(market.id);

	public def setMarketAccessible(id:Long) = this.assetsVolumes(id) = 0;

	public def setMarketAccessible(market:Market) = this.setMarketAccessible(market.id);

	public def getCashAmount():Double = this.cashAmount;
	
	public def setCashAmount(cashAmount:Double):Double = this.cashAmount = cashAmount;
	
	public def updateCashAmount(delta:Double) = this.cashAmount += delta;

	public def getAssetVolume(id:Long):Long {
		assert this.isMarketAccessible(id);
		return this.assetsVolumes(id);
	}

	public def setAssetVolume(id:Long, assetVolume:Long) {
		assert this.isMarketAccessible(id);
		return this.assetsVolumes(id) = assetVolume;
	}

	/**
	 * @throws Exception  if <code>isMarketAccessible(market)</code> is false.
	 */
	public def getAssetVolume(market:Market) = this.getAssetVolume(market.id);
	
	/**
	 * @throws Exception  if <code>isMarketAccessible(market)</code> is false.
	 */
	public def setAssetVolume(market:Market, assetVolume:Long) = this.setAssetVolume(market.id, assetVolume);

	/**
	 * @throws Exception  if <code>isMarketAccessible(market)</code> is false.
	 */
	public def updateAssetVolume(id:Long, delta:Long) {
		assert this.isMarketAccessible(id);
		return this.assetsVolumes(id) = this.assetsVolumes(id) + delta;
	}

	public def updateAssetVolume(market:Market, delta:Long) = this.updateAssetVolume(market.id, delta);

	public def toString():String {
		return this.typeName() + [this.id, this.cashAmount, this.assetsVolumes.keySet()];
	}
}
