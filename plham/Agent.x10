package plham;
import x10.compiler.NonEscaping;
import x10.util.ArrayList;
import x10.util.Indexed;
import x10.util.HashMap;
import x10.util.List;
import x10.util.Map;
import x10.util.Random;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;

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
public abstract class Agent {
	
	/** The id of this agent assigned by the system. */
	public val id:Long;
	/** The JSON object name. */
	public val name:String;
	/** The RNG given by the system. */
	private val random:Random;

	/** @return An instance of Random (derived from the root). */
	protected def getRandom():Random = this.random;

	/** The amount of cash. */
	public var cashAmount:Double;
	/** A mapping from markets (id) to the volumes of the assets. */
	public var assetsVolumes:Map[Long,Long];

        /** Only used for proxy agent **/
        private def this(id:Long) {
	    this.id=id;
	    this.name = null;
	    this.random = null;
	    this.cashAmount = 0.0;
	    this.assetsVolumes = null;
	}
        static public class Proxy extends Agent {
	    protected def this(id:Long) { super(id); }
	    public def submitOrders(markets:List[Market]):List[Order] { throw new Error("should not called");}
        }

	public def this(id:Long, name:String, random:Random) {
		this.id = id;
		this.name = name;
		this.random = random;
		this.cashAmount = 0.0;
		this.assetsVolumes = new HashMap[Long,Long]();
	}

	/**
	 * Setup this agent using JSON.
	 * This method sets
	 * <ul>
	 * <li> cash amount </li>
	 * <li> initial assets amount </li>
	 * </ul>
	 * This method supposed to be called by AgentInitializers of child classes.
	 * See also: {@link plham.agent.FCNAgent#setup(JSON.Value, Simulator)}
	 */
	public def setup(json:JSON.Value, sim:Simulator):Agent {
		val jsonrandom = new JSONRandom(getRandom());
		this.assetsVolumes = new HashMap[Long, Long]();
		this.cashAmount = jsonrandom.nextRandom(json("cashAmount"));
		for (market in sim.getMarketsByName(json("markets"))) {
			this.assetsVolumes(market.id) = 0;
			this.assetsVolumes(market.id) = jsonrandom.nextRandom(json("assetVolume")) as Long;
		}
		return this;
	}

	/**
	 * Submit orders to the markets.
	 * This method will be invoked by the system.
	 * @param markets  a list of all markets (but some may not be up-to-date).
	 * @return a list of orders.
	 */
	public abstract def submitOrders(markets:List[Market]):List[Order];

	/**
	 * @return whether the specified market is accessible for this agent.
	 * 
	 * <p> You can make markets accessible for this agent using Agent#setMarketAccessible(Long) or Agent#setMarketAccessible(Market). </p>
	 */
	public def isMarketAccessible(id:Long) = this.assetsVolumes.containsKey(id);

	/**
	 * Same as {@link Agent#isMarketAccessible(Long)}.
	 * @return Agent#isMarketAccessible(market.id)
	 */
	public def isMarketAccessible(market:Market) = this.isMarketAccessible(market.id);

	/**
	 * Makes the specified market accessible for this agent.
	 */
	public def setMarketAccessible(id:Long) = this.assetsVolumes(id) = 0;

	public def setMarketAccessible(market:Market) = this.setMarketAccessible(market.id);

	/**
	 * @return cash amount of this agent
	 */
	public def getCashAmount():Double = this.cashAmount;
	
	/**
	 * Sets cash amount of this agent.
	 * You should use this method only when you are initializing agents.
	 */
	public def setCashAmount(cashAmount:Double):Double = this.cashAmount = cashAmount;
	
	/**
	 * Adds delta to this agent's cash amount .
	 */
	public def updateCashAmount(delta:Double) = this.cashAmount += delta;
    
	/**
	 * Updates this agent using update:Market.AgentUpdate.
	 */
        public def executeUpdate(update:Market.AgentUpdate) {
	    updateCashAmount(update.cashAmountDelta);
	    updateAssetVolume(update.marketId, update.assetVolumeDelta);
	    orderExecuted(update.marketId, update.orderId, update.price, update.cashAmountDelta, update.assetVolumeDelta);
	}

	/**
	 * @return the id-th asset volume this agent has.
	 * @throws Exception  if <code>isMarketAccessible(market)</code> is false.
	 */
	public def getAssetVolume(id:Long):Long {
		assert this.isMarketAccessible(id);
		return this.assetsVolumes(id);
	}

	/**
	 * Sets id-th asset volume of this agent to <code>assetVolume</code>
	 */
	public def setAssetVolume(id:Long, assetVolume:Long) {
		assert this.isMarketAccessible(id);
		return this.assetsVolumes(id) = assetVolume;
	}

	/**
	 * Same as Agent#getAssetVolume(Long).
	 * @throws Exception  if <code>isMarketAccessible(market)</code> is false.
	 */
	public def getAssetVolume(market:Market) = this.getAssetVolume(market.id);
	
	/**
	 * Same as Agent#setAssetVolume(Long, Long).
	 * @throws Exception  if <code>isMarketAccessible(market)</code> is false.
	 */
	public def setAssetVolume(market:Market, assetVolume:Long) = this.setAssetVolume(market.id, assetVolume);

	/**
	 * Adds delta to id-th asset volume of this agent.
	 * @throws Exception  if <code>isMarketAccessible(market)</code> is false.
	 */
	public def updateAssetVolume(id:Long, delta:Long) {
		assert this.isMarketAccessible(id);
		return this.assetsVolumes(id) = this.assetsVolumes(id) + delta;
	}

	public def updateAssetVolume(market:Market, delta:Long) = this.updateAssetVolume(market.id, delta);

	/**
	 * Callback when one's order is executed at the market.
	 * @param orderId  (0 if unspecified)
	 * @param market
	 * @param price  the price at which the order is executed
	 * @param cashAmountDelta  how much changed
	 * @param assetVolumeDelta  how much changed
	 */
	public def orderExecuted(marketId:Long, orderId:Long, price:Double, cashAmountDelta:Double, assetVolumeDelta:Long) {
		//Console.OUT.println("#Agent#orderExecuted: " + ["agent:" + this.id, "market:" + market.id, "order:" + orderId, "price:" + price, "cashAmountDelta:" + cashAmountDelta, "assetVolumeDelta:" + assetVolumeDelta]);
	}

	/**
	 * Get the next order id.
	 * This is called in the constructor of {@link plham.Order}.
	 * To enable automated order numbering, override this method and return unique integers.
	 * @return always 0 by default
	 * @see plham.OrderBook
	 */
	public def nextOrderId():Long = 0;

	public def toString():String {
		return this.typeName() + [this.id, this.cashAmount, this.assetsVolumes.keySet()];
	}
}
