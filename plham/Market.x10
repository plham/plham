package plham;
import x10.compiler.NonEscaping;
import x10.util.ArrayList;
import x10.util.Container;
import x10.util.Indexed;
import x10.util.List;
import x10.util.NoSuchElementException;
import x10.util.Random;
import plham.main.Simulator;
import plham.util.Itayose;
import plham.util.JSON;
import plham.util.JSONRandom;

/**
 * The base class for markets.
 * A continuous double auction mechanism is implemented.
 *
 * <p><ul>
 * <li> Override <code>handleOrders(List[Order])</code> and <code>handleOrder(Order)</code> to implement a matching mechanism.
 * <li> The price of every order will be rounded in increments of a tick size (in <code>handleOrder(Order)</code>).
 * <li> Market orders never be added onto the orderbooks (in the current implementation).
 * <li> Do not call <code>handleOrders(List[Order])</code> family in <code>Agent#submitOrders(List[Market])</code>.
 * <li> Do not access to the fields as much as possible; Use the corresponding methods if exist.
 * </ul>
 * 
 * <p>On events, it currently supports four places to register.
 * <p><ul>
 * <li> beforeSimulationStep: Called once before a simulation step (once each step)
 * <li>  afterSimulationStep: Called once  after a simulation step (once each step)
 * <li> beforeOrderHandling: Called every before handling an order (once per order)
 * <li>  afterOrderHandling: Called every  after handling an order (once per order)
 * </ul>
 */
public class Market {
	
	/** The id of this market assigned by the system. DON'T CHANGE IT. */
	public val id:Long;
	/** The JSON object name. DON'T CHANGE IT. */
	public val name:String;
	/** The RNG given by the system (DON'T CHANGE IT). */
	private val random:Random;

	/** @return An instance of Random (derived from the root). */
	public def getRandom():Random = this.random;

	public var _isRunning:Boolean;
	public var buyOrderBook:OrderBook;
	public var sellOrderBook:OrderBook;
	public var outstandingShares:Long;

	/** NOTE: Use <code>getTime()</code> instead. */
	private var time:Time;
//	public var tick:Long;

	/** Reference to a Env object (actually be a Simulator object in all cases), which represents the simulation environment. */
	public transient var env:Env;

	/**
	 * Market's tick size, the minimum unit of the price.
	 *
	 * Negative <code>tickSize</code> means that market has no tick size restriction.
	 */
	public var tickSize:Double; // E.g. 0.0001;  "tickSize <= 0.0" means no tick size.
	public val NO_TICKSIZE = -1.0;
	private static ROUND_UPPER = (price:Double, tickSize:Double) => (Math.ceil(price / tickSize)) * tickSize;
	private static ROUND_LOWER = (price:Double, tickSize:Double) => (Math.floor(price / tickSize)) * tickSize;

	//// Historical data (public) ////
	public var marketPrices:ArrayList[Double];
	public var fundamentalPrices:ArrayList[Double];

	public var fundamentalVolatility:Double;

	//// Historical data (hidden) ////
	public transient var lastExecutedPrices:List[Double];
	public transient var sumExecutedVolumes:List[Long];
	public transient var buyOrdersCounts:List[Long];
	public transient var sellOrdersCounts:List[Long];
	public transient var executedOrdersCounts:List[Long];

	public transient var executionLogs:List[List[ExecutionLog]] = new ArrayList[List[ExecutionLog]]();

	public static class ExecutionLog {
		/** true if the exchange price is determined by a sell order (seller); otherwise false means it's done by a buy order (buyer). */
		public var isSellMajor:Boolean;
		public var time:Long;
		public var buyAgentId:Long;
		public var sellAgentId:Long;
		public var exchangePrice:Double;
		public var exchangeVolume:Long;
	}

	public def this(id:Long, name:String, random:Random) {
		this.id = id;
		this.name = name;
		this.random = random;
		this._isRunning = true;
		this.buyOrderBook = new OrderBook(OrderBook.HIGHERS_FIRST);
		this.sellOrderBook = new OrderBook(OrderBook.LOWERS_FIRST);
		this.outstandingShares = 1;

		this.time = new Time(0);
//		this.tick = 0;
		this.buyOrderBook.setTime(this.time);  // Share the clock.
		this.sellOrderBook.setTime(this.time); // Share the clock.
		this.env = null;
		this.tickSize = NO_TICKSIZE;

		this.marketPrices = new ArrayList[Double]();
		this.fundamentalPrices = new ArrayList[Double]();

		this.lastExecutedPrices = new ArrayList[Double]();
		this.sumExecutedVolumes = new ArrayList[Long]();
		this.buyOrdersCounts = new ArrayList[Long]();
		this.sellOrdersCounts = new ArrayList[Long]();
		this.executedOrdersCounts = new ArrayList[Long]();
		this.fundamentalVolatility = 0.0;
	}

	public def this(id:Long) {
		this(id, "default", new Random());
	}
	public def this() {
		this(-1, "default", new Random());
	}

	public def setup(json:JSON.Value, sim:Simulator):Market {
		val jsonrandom = new JSONRandom(getRandom());
		setTickSize(jsonrandom.nextRandom(json("tickSize", "-1.0"))); // " tick-size <= 0.0 means no tick size.
		setInitialMarketPrice(jsonrandom.nextRandom(json("marketPrice")));
		setInitialFundamentalPrice(jsonrandom.nextRandom(json("marketPrice")));
		setFundamentalVolatility(jsonrandom.nextRandom(json("fundamentalVolatility", "0.0")));
		setOutstandingShares(jsonrandom.nextRandom(json("outstandingShares")) as Long);
		return this;
	}

	public static def register(sim:Simulator):void {
		val className = "Market";
		sim.addMarketsInitializer(className, (id:Long, name:String, random:Random, json:JSON.Value) => {
			val numMarkets = json.has("numMarkets") ? json("numMarkets").toLong() : 1;
			val markets = new ArrayList[Market](numMarkets) as List[Market];
			markets.add(new Market(id, name, random).setup(json, sim));
			sim.GLOBAL(markets(0).name) = markets as Any; // assuming 'numMarkets' is always set to 1.
			//TODO TKhack
			val r = new ArrayList[LongRange](); r.add(id..id);
			sim.marketName2Ranges(name)=r;
			return markets;
		});
	}

	/**
	 * Handle orders from some agents.
	 * This method will be invoked by the system.
	 * The list of orders may include those of other markets (please skip them).
	 * The primary task, order matching, should be done in <code>handleOrder(Order)</code>.
	 * @param orders  a list of orders.
	 */
	public def handleOrders(orders:Container[Order]) {
		for (order in orders) {
			if (order.marketId == this.id) {
				this.handleOrder(order);
			}
		}
	}

	/**
	 * Handle orders from some agents.
	 * This method will be invoked by the system.
	 * The primary task, order matching, should be done here.
	 * @param orders  an order to this market.
	 */
	public def handleOrder(order:Order) {
		assert order.marketId == this.id;
		val t = this.getTime();
		if (order.getPrice() < 0.0) {
			return;
		}
		if (order.getVolume() <= 0) {
			return;
		}

		this.roundPrice(order); // Do in the agent's place

		if (order.isCancel()) {
			if (order.isBuyOrder()) {
				this.cancelBuyOrder(order);
			}
			if (order.isSellOrder()) {
				this.cancelSellOrder(order);
			}
			return;
		}
		if (order.isBuyOrder()) {
			this.handleBuyOrder(order);
			this.buyOrdersCounts(t) += 1;
		}
		if (order.isSellOrder()) {
			this.handleSellOrder(order);
			this.sellOrdersCounts(t) += 1;
		}
	}

	protected def cancelBuyOrder(order:Order) {
		assert order.isBuyOrder();
		this.buyOrderBook.cancel(order);
	}

	protected def cancelSellOrder(order:Order) {
		assert order.isSellOrder();
		this.sellOrderBook.cancel(order);
	}
	
	protected def handleBuyOrder(order:Order) {
		assert order.isBuyOrder();
		if (order.isLimitOrder()) {
			this.handleBuyLimitOrder(order);
		}
		if (order.isMarketOrder()) {
			this.handleBuyMarketOrder(order);
		}
	}

	protected def handleSellOrder(order:Order) {
		assert order.isSellOrder();
		if (order.isLimitOrder()) {
			this.handleSellLimitOrder(order);
		}
		if (order.isMarketOrder()) {
			this.handleSellMarketOrder(order);
		}
	}

	protected def handleBuyLimitOrder(buyOrder:Order) {
		assert buyOrder.isBuyOrder() && buyOrder.isLimitOrder();
		val t = this.getTime();
		if (this.isRunning()) {
			while (buyOrder.getVolume() > 0) {
				if (this.sellOrderBook.size() == 0) {
					break;
				}
				val sellOrder = this.sellOrderBook.getBestOrder();
				if (buyOrder.getPrice() >= sellOrder.getPrice()) {
					this.executeBuyOrders(buyOrder, sellOrder);
				} else {
					break;
				}
				if (sellOrder.getVolume() <= 0) {
					this.sellOrderBook.remove(sellOrder);
				}
			}
		}
		if (buyOrder.getVolume() > 0) {
			this.buyOrderBook.add(buyOrder);
		}
	}

	protected def handleSellLimitOrder(sellOrder:Order) {
		assert sellOrder.isSellOrder() && sellOrder.isLimitOrder();
		val t = this.getTime();
		if (this.isRunning()) {
			while (sellOrder.getVolume() > 0) {
				if (this.buyOrderBook.size() == 0) {
					break;
				}
				val buyOrder = this.buyOrderBook.getBestOrder();
				if (buyOrder.getPrice() >= sellOrder.getPrice()) {
					this.executeSellOrders(sellOrder, buyOrder);
				} else {
					break;
				}
				if (buyOrder.getVolume() <= 0) {
					this.buyOrderBook.remove(buyOrder);
				}
			}
		}
		if (sellOrder.getVolume() > 0) {
			this.sellOrderBook.add(sellOrder);
		}
	}

	protected def handleBuyMarketOrder(buyOrder:Order) {
		assert buyOrder.isBuyOrder() && buyOrder.isMarketOrder();
		val t = this.getTime();
		if (this.isRunning()) {
			while (buyOrder.getVolume() > 0) {
				if (this.sellOrderBook.size() == 0) {
					break;
				}
				val sellOrder = this.sellOrderBook.getBestOrder();
				//if (buyOrder.getPrice() >= sellOrder.getPrice()) {
					this.executeBuyOrders(buyOrder, sellOrder);
				//} else {
				//	break;
				//}
				if (sellOrder.getVolume() <= 0) {
					this.sellOrderBook.remove(sellOrder);
				}
			}
		}
		//if (buyOrder.getVolume() > 0) {
		//	this.buyOrderBook.add(buyOrder);
		//}
	}

	protected def handleSellMarketOrder(sellOrder:Order) {
		assert sellOrder.isSellOrder() && sellOrder.isMarketOrder();
		val t = this.getTime();
		if (this.isRunning()) {
			while (sellOrder.getVolume() > 0) {
				if (this.buyOrderBook.size() == 0) {
					break;
				}
				val buyOrder = this.buyOrderBook.getBestOrder();
				//if (buyOrder.getPrice() >= sellOrder.getPrice()) {
					this.executeSellOrders(sellOrder, buyOrder);
				//} else {
				//	break;
				//}
				if (buyOrder.getVolume() <= 0) {
					this.buyOrderBook.remove(buyOrder);
				}
			}
		}
		//if (sellOrder.getVolume() > 0) {
		//	this.sellOrderBook.add(sellOrder);
		//}
	}

	
	/**
	 * Remove all expired and no-volume orders.
	 */
	public def updateOrderBooks() {
        val isExpired = (order:Order) => order.isExpired(this);
		val isNoVolume = (order:Order) => order.getVolume() <= 0;
		this.buyOrderBook.removeAllWhere((order:Order) => isExpired(order) || isNoVolume(order));
		this.sellOrderBook.removeAllWhere((order:Order) => isExpired(order) || isNoVolume(order));
	}

//	/**
//	 * Remove all buy orders above the <code>basePrice</code> and all sell orders below the <code>basePrice</code>
//	 * as well as all expired and no-volume orders.
//	 */
//	public def cleanOrderBooks(basePrice:Double) {
//		val isExpired = (order:Order) => order.isExpired(this);
//		val isNoVolume = (order:Order) => order.getVolume() <= 0;
//		val isMoreThan = (order:Order) => order.getPrice() > basePrice;
//		val isLessThan = (order:Order) => order.getPrice() < basePrice;
//		this.buyOrderBook.removeAllWhere((order:Order) => isExpired(order) || isNoVolume(order) || isMoreThan(order));
//		this.sellOrderBook.removeAllWhere((order:Order) => isExpired(order) || isNoVolume(order) || isLessThan(order));
//	}

	/**
	 * Perform the itayose method for clearance of matched orders.
	 * The method <code>updateOrderBooks()</code> will be called after this method.
	 */
	public def itayoseOrderBooks() {
		Itayose.itayose(this);
		this.updateOrderBooks();
	}
	
	/**
	 * Whether this market is open or not (closed).
	 * If false (closed), this market does not execute orders;
     * just placing orders on the orderbooks.
	 */
	public def isRunning():Boolean = this._isRunning;
	
	@NonEscaping
	public final def setRunning(isRunning:Boolean) = this._isRunning = isRunning;

	/**
	 * See also <code>roundPrice()</code>.
	 */
	public def getTickSize() = this.tickSize;

	/**
	 * Note: <code>tickSize &lt;= 0.0</code> means no tick size.
	 */
	@NonEscaping
	public final def setTickSize(tickSize:Double) = this.tickSize = tickSize;

	/**
	 * Round the price of the order in increments of a tick size.
	 * Modify <code>order</code> in place and return it.
	 */
	public def roundPrice(order:Order):Order {
		if (this.tickSize <= 0.0) {
			return order;
		}
		if (order.getPrice() == Order.NO_PRICE) {
			return order;
		}
		if (order.isBuyOrder()) {
			order.setPrice(this.roundBuyPrice(order.getPrice()));
		}
		if (order.isSellOrder()) {
			order.setPrice(this.roundSellPrice(order.getPrice()));
		}
		return order;
	}

	public def roundBuyPrice(price:Double):Double = ROUND_LOWER(price, this.tickSize);

	public def roundSellPrice(price:Double):Double = ROUND_UPPER(price, this.tickSize);

	/**
	 * Return the next market price at t + 1.
	 * If some transactions occur, the last transaction price will be the next market price.
	 * Otherwise if the market has a mid price, it will be used.
	 * Otherwise, the last market price is used.
	 * This method does not change any internal state of this market;
	 * Use <code>updateMarketPrice()</code> for this purpose.
	 */
	public def getNextMarketPrice():Double {
		val lastPrice = this.marketPrices.getLast();
		var price:Double = lastPrice;
		if (this.isRunning()) {
			if (this.executedOrdersCounts.getLast() > 0) {
				price = this.lastExecutedPrices.getLast();
			} else if (this.buyOrderBook.size() > 0 && this.sellOrderBook.size() > 0) {
				price = this.getMidPrice();
			}
		}
		return price;
	}

	/* TODO: !!COMPLEX PROCEDURE!!
	 * val m = new Market();
	 * // t = 0, size() == 0
	 * m.setInitial()
	 * // t = 0, size() == 1  OK
	 * for (n in 0...) {
	 *     // t = n, size() = n + 1  OK
	 *     m.update()
	 *     // t = n, size() = n + 2
	 *     m.updateTime()
	 *     // t = n + 1, size() = n + 2  OK
	 * }
	 */

	public def tickUpdateMarketPrice() {
		val t = this.getTime();
		val price = this.getNextMarketPrice();
		this.marketPrices(t) = price;
		//this.updateOrderBooks();
	}

	public def updateMarketPrice() {
		val price = this.getNextMarketPrice();
		this.updateMarketPrice(price);
	}

	public def updateMarketPrice(price:Double) {
		assert !price.isNaN() : "!price.isNaN()";
		assert price >= 0.0 : "price >= 0.0";
		this.marketPrices.add(price);
		// FIXME: The below should not come here.
		this.buyOrdersCounts.add(0);
		this.sellOrdersCounts.add(0);
		this.executedOrdersCounts.add(0);
		this.lastExecutedPrices.add(Double.NaN);
		this.sumExecutedVolumes.add(0);
		this.executionLogs.add(new ArrayList[ExecutionLog]());
		this.agentUpdates.add(new ArrayList[AgentUpdate]());
	}
	
	public def updateFundamentalPrice(price:Double) {
		assert !price.isNaN() : "!price.isNaN()";
		assert price >= 0.0 : "price >= 0.0";
		this.fundamentalPrices.add(price);
	}

	/**
	 * This is for system use.
	 * This method can be used when the next fundamental price is set(by calling updateFundamentalPrice), but time is not updated yes.
	 */
	public def getNextFundamentalPrice() {
		assert this.getTime() == this.fundamentalPrices.size() - 1;
		return this.fundamentalPrices.getLast();
	}

	
	public final def getInitialMarketPrice():Double {
		if (this.marketPrices.size() == 0) throw new NoSuchElementException();
		return this.marketPrices(0);
	}

	public final def getFundamentalVolatility():Double = this.fundamentalVolatility;

	@NonEscaping
	public final def setFundamentalVolatility(v:Double) {
		this.fundamentalVolatility = v;
	}

	@NonEscaping
	public final def setInitialMarketPrice(price:Double) {
		assert this.marketPrices.size() == 0;
		this.marketPrices.add(price); // t = 0
		this.fundamentalPrices.add(price); // t = 0
		// FIXME: The below should not come here.
		this.buyOrdersCounts.add(0);
		this.sellOrdersCounts.add(0);
		this.executedOrdersCounts.add(0);
		this.lastExecutedPrices.add(Double.NaN);
		this.sumExecutedVolumes.add(0);
		this.executionLogs.add(new ArrayList[ExecutionLog]());
		this.agentUpdates.add(new ArrayList[AgentUpdate]());
	}

	public final def getInitialFundamentalPrice():Double {
		if (this.fundamentalPrices.size() == 0) throw new NoSuchElementException();
		return this.fundamentalPrices(0);
	}
	
	@NonEscaping
	public final def setInitialFundamentalPrice(price:Double) {
		this.fundamentalPrices(0) = price;
	}
	
	public def getPrice() = this.getMarketPrice();

	public def getPrice(t:Long) = this.getMarketPrice(t);

	public def getMarketPrice() = this.marketPrices(this.getTime()); //this.marketPrices.getLast();

	public def getMarketPrice(t:Long) = this.marketPrices(t);

	public def getFundamentalPrice() = this.fundamentalPrices(this.getTime()); //this.fundamentalPrices.getLast();
	
	public def getFundamentalPrice(t:Long) = this.fundamentalPrices(t);

	public def getBuyOrderBook() = this.buyOrderBook;

	public def getSellOrderBook() = this.sellOrderBook;

	/**
	 * Get the best (highest) buy/bid price.  NaN if no order.
	 */
	public def getBestBuyPrice() = this.buyOrderBook.getBestPrice();

	/**
	 * Get the best (lowest) sell/ask price.  NaN if no order.
	 */
	public def getBestSellPrice() = this.sellOrderBook.getBestPrice();

	/**
	 * Get the mid price, the average (middle) of the best buy/bid and sell/ask prices.
	 */
	public def getMidPrice() = (this.getBestBuyPrice() + this.getBestSellPrice()) / 2.0;

	public def getOutstandingShares():Long = this.outstandingShares;

	@NonEscaping
	public final def setOutstandingShares(outstandingShares:Long) = this.outstandingShares = outstandingShares;

	public def getTime() = this.time.t;

	public def setTime(time:Long) = this.time.t = time;

	public def updateTime() = this.time.t++; // Call this explicitly!
	
	public def check() {
		val t = this.getTime();
		assert this.marketPrices.size() - 1 == t;
		assert this.fundamentalPrices.size() - 1 == t;
		assert this.lastExecutedPrices.size() - 1 == t;
		assert this.sumExecutedVolumes.size() - 1 == t;
		assert this.buyOrdersCounts.size() - 1 == t;
		assert this.sellOrdersCounts.size() - 1 == t;
		assert this.executedOrdersCounts.size() - 1 == t;
		assert this.executionLogs.size() - 1 == t;
		assert this.agentUpdates.size() - 1 == t;
		Console.OUT.println("#MARKET CHECK PASSED");
	}

	protected def executeBuyOrders(buyOrder:Order, sellOrder:Order) {
		this.executeOrders(sellOrder.getPrice(), buyOrder, sellOrder, true); // If a buy order, use the best sell price.
	}
	
	protected def executeSellOrders(sellOrder:Order, buyOrder:Order) {
		this.executeOrders(buyOrder.getPrice(), buyOrder, sellOrder, false); // If a sell order, use the best buy price.
	}

	/**
	 * Exchange the cash and assets between the buyer and seller.
	 * The 1st argument <code>price</code> is used to exchange.
	 * @param isSellMajor is an aux information:
	 *        true if the exchange price is determined by an order on the sell orderbook (seller).
	 * @return execution price (maybe <code>price</code>)
	 */
	protected def executeOrders(price:Double, buyOrder:Order, sellOrder:Order, isSellMajor:Boolean) {
		assert buyOrder.marketId == this.id;
		assert sellOrder.marketId == this.id;

		val exchangePrice = price;
		val exchangeVolume = Math.min(buyOrder.getVolume(), sellOrder.getVolume());
		assert exchangePrice >= 0.0 : ["Market#executeOrders(), " + (isSellMajor ? "sell major" : "buy major") + ": exchangePrice >= 0.0 but ", exchangePrice];
		assert exchangeVolume >= 0  : ["Market#executeOrders(), " + (isSellMajor ? "sell major" : "buy major") + ": exchangeVolume >= 0  but ", exchangeVolume];

		val cashAmountDelta = exchangePrice * exchangeVolume;
		val assetVolumeDelta = exchangeVolume;

		val t = this.getTime();

		val buyUpdate = new AgentUpdate();
		buyUpdate.agentId = buyOrder.agentId;
		buyUpdate.marketId = buyOrder.marketId;
		buyUpdate.orderId = buyOrder.orderId;
		buyUpdate.price = exchangePrice;
		buyUpdate.cashAmountDelta = -cashAmountDelta;   // A buyer pays cash
		buyUpdate.assetVolumeDelta = +assetVolumeDelta; // and gets stocks
		this.handleAgentUpdate(buyUpdate);

		val sellUpdate = new AgentUpdate();
		sellUpdate.agentId = sellOrder.agentId;
		sellUpdate.marketId = sellOrder.marketId;
		sellUpdate.orderId = sellOrder.orderId;
		sellUpdate.price = exchangePrice;
		sellUpdate.cashAmountDelta = +cashAmountDelta;   // A seller gets cash
		sellUpdate.assetVolumeDelta = -assetVolumeDelta; // and gives stocks
		this.handleAgentUpdate(sellUpdate);

		val EXECUTION_LOG = false;
		if (EXECUTION_LOG) {
			val log = new ExecutionLog();
			log.isSellMajor = isSellMajor;
			log.time = t;
			log.buyAgentId = buyOrder.agentId;
			log.sellAgentId = sellOrder.agentId;
			log.exchangePrice = exchangePrice;
			log.exchangeVolume = exchangeVolume;
			this.executionLogs(t).add(log);
		}

		buyOrder.updateVolume(-exchangeVolume);
		sellOrder.updateVolume(-exchangeVolume);

		this.executedOrdersCounts(t) += 1;
		this.lastExecutedPrices(t) = exchangePrice;
		this.sumExecutedVolumes(t) = sumExecutedVolumes(t) + exchangeVolume;

		val DEBUG = false;
		if (DEBUG) {
			Console.OUT.println("exchangePrice: " + exchangePrice);
			Console.OUT.println("exchangeVolume: " + exchangeVolume);
			Console.OUT.println("buyOrder.getVolume(): " + buyOrder.getVolume());
			Console.OUT.println("sellOrder.getVolume(): " + sellOrder.getVolume());
		}
	}

	public def getTradeVolume():Long = getTradeVolume(this.getTime());

	public def getTradeVolume(t:Long):Long = this.sumExecutedVolumes(t);

	public def setTradeVolume(t:Long, tradeVolume:Long):Long = this.sumExecutedVolumes(t) = tradeVolume;

	public static class AgentUpdate {
		public var agentId:Long;
		public var marketId:Long;
		public var orderId:Long;
		public var price:Double;
		public var cashAmountDelta:Double;
		public var assetVolumeDelta:Long;

		public def isBuySide():Boolean = this.assetVolumeDelta > 0;
		public def isSellSide():Boolean = this.assetVolumeDelta < 0;
		public def toString():String = "[Update agentId:"+agentId+", marketId:"+marketId+", orderId"+orderId+", price:"+price+", cashAmountDelta"+cashAmountDelta+", assetVolumeDelta"+assetVolumeDelta+"]";
	}

	public transient var agentUpdates:List[List[AgentUpdate]] = new ArrayList[List[AgentUpdate]]();

	public def handleAgentUpdate(update:AgentUpdate) {
		val t = this.getTime();
		// Console.OUT.println("DBGM update@"+t+", update:"+update);
		try {
		    this.executeAgentUpdate(this.env.agents, update); // Process
		} catch (e:IndexOutOfBoundsException) {
		    this.agentUpdates(t).add(update); // Keep
		}
	}
    
	public def executeAgentUpdate(agents:Indexed[Agent], update:AgentUpdate) {
		val id = update.agentId;
		val agent = agents(id);
		if (agent != null) {
		    agent.executeUpdate(update);
		}
	}

	public static interface MarketEvent extends Event {
		public def update(market:Market):void;
	}

	public static interface OrderEvent extends Event {
		public def update(market:Market, order:Order):void;
	}

	public var beforeOrderHandlingEvents:List[OrderEvent] = new ArrayList[OrderEvent]();

	public var afterOrderHandlingEvents:List[OrderEvent] = new ArrayList[OrderEvent]();

	public var beforeSimulationStepEvents:List[MarketEvent] = new ArrayList[MarketEvent]();

	public var afterSimulationStepEvents:List[MarketEvent] = new ArrayList[MarketEvent]();

	public def addBeforeOrderHandlingEvent(e:OrderEvent) = this.beforeOrderHandlingEvents.add(e);

	public def addAfterOrderHandlingEvent(e:OrderEvent) = this.afterOrderHandlingEvents.add(e);

	public def addBeforeSimulationStepEvent(e:MarketEvent) = this.beforeSimulationStepEvents.add(e);

	public def addAfterSimulationStepEvent(e:MarketEvent) = this.afterSimulationStepEvents.add(e);

	public def triggerBeforeOrderHandlingEvents(order:Order) {
		for (e in this.beforeOrderHandlingEvents) {
			e.update(this, order);
		}
	}

	public def triggerAfterOrderHandlingEvents(order:Order) {
		for (e in this.afterOrderHandlingEvents) {
			e.update(this, order);
		}
	}

	public def triggerBeforeSimulationStepEvents() {
		for (e in this.beforeSimulationStepEvents) {
			e.update(this);
		}
	}

	public def triggerAfterSimulationStepEvents() {
		for (e in this.afterSimulationStepEvents) {
			e.update(this);
		}
	}
}
