package plham;
import x10.util.ArrayList;
import x10.util.Container;
import x10.util.List;
import x10.util.Random;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.event.FundamentalPriceShock;

/**
 * A class for markets (assets) associated with some underlying markets (assets).
 *
 * <p><ul>
 * <li> Call <code>addMarkets(List[Market])</code> to add underlying components.
 * </ul>  
 */
public class IndexMarket extends Market {

	/** The list of its underlying markets by their ids. */ 
	public var components:List[Long];

	public def this(id:Long, name:String, random:Random) {
		super(id, name, random);
		this.components = new ArrayList[Long]();
	}
	public def this() {
		this(-1, "default", new Random());
	}

	public def addMarket(market:Market) {
		assert !this.components.contains(market.id);
		this.components.add(market.id);
	}

	public def addMarkets(markets:Container[Market]) {
		for (m in markets) {
			this.addMarket(m);
		}
	}

	/**
	 * Get a list of market ids, the components of the index.
	 * It can be helpful before setting market's <code>env</code> field.
	 */
	public def getComponents():List[Long] = this.components;

	/**
	 * Get a list of markets.
	 * It can be available after setting its <code>env</code> field.
	 */
	public def getMarkets():List[Market] {
		assert this.env != null : "Cannot call during the setup procedure";
		val m = new ArrayList[Market]();
		for (id in this.components) {
			m.add(this.env.markets(id));
		}
		return m;
	}

	public def isAllMarketsRunning() {
		assert this.env != null : "Cannot call during the setup procedure";
		for (id in this.components) {
			if (!this.env.markets(id).isRunning()) {
				return false;
			}
		}
		return this.isRunning();
	}

	// Override
	public def check() {
		val t = this.getTime();
		assert this.marketPrices.size() - 1 == t;
		//assert this.fundamentalPrices.size() - 1 == t;
		assert this.lastExecutedPrices.size() - 1 == t;
		assert this.sumExecutedVolumes.size() - 1 == t;
		assert this.buyOrdersCounts.size() - 1 == t;
		assert this.sellOrdersCounts.size() - 1 == t;
		assert this.executedOrdersCounts.size() - 1 == t;
		assert this.executionLogs.size() - 1 == t;
		assert this.agentUpdates.size() - 1 == t;
		Console.OUT.println("#MARKET CHECK PASSED");
	}

	/**
	 * Get the latest market index value.
	 * Same as <code>getMarketIndex()</code>.
	 * @return the index value
	 */
	public def getIndex() = this.getMarketIndex();

	/**
	 * Get the market index at time <code>t</code>.
	 * Same as <code>getMarketIndex(t)</code>.
	 * @param t
	 * @return the index value at time <code>t</code>
	 */
	public def getIndex(t:Long) = this.getMarketIndex(t);

	/**
	 * Get the latest market index value.
	 * Same as <code>getIndex()</code>.
	 * @return the index value
	 */
	public def getMarketIndex() = this.getMarketIndex(this.getTime());

	/**
	 * Get the market index at time <code>t</code>.
	 * Same as <code>getIndex(t)</code>.
	 * @param t
	 * @return the index value at time <code>t</code>
	 */
	public def getMarketIndex(t:Long) {
		return this.computeMarketIndex(t);
	}

	/**
	 * Returns the fundamental price of the index market.
	 * if the cache contains the fundamental price at the specified time, use the cache,
	 * otherwise calculates and returns the fundamental price and caches it.
	 */
	public def getFundamentalPrice(t:Long) {
		if (this.fundamentalPrices.size() <= t) {
			this.fundamentalPrices.resize(t + 1, Double.NaN);
		}
		if (this.fundamentalPrices(t).isNaN()) {
			this.fundamentalPrices(t) = this.computeFundamentalIndex(t);
		}
		return this.fundamentalPrices(t);
	}

	public def getFundamentalPrice() = this.getFundamentalPrice(this.getTime());

	/**
	 * Get the latest fundamental index value.
	 * @return the index value
	 */
	public def getFundamentalIndex() = this.getFundamentalPrice();

	/**
	 * Get the fundamental index value at time <code>t</code>.
	 * @param t
	 * @return the index value at time <code>t</code>
	 */
	public def getFundamentalIndex(t:Long) = this.getFundamentalPrice(t);

	public static struct WHICH_INDEX(id:Long) {}
	public static FUNDAMENTAL = WHICH_INDEX(0);
	public static MARKET = WHICH_INDEX(1);
	public def computeIndex(t:Long, which_type:WHICH_INDEX) {
		var total_value:Double = 0;
		var total_shares:Double = 0;
		for (component_id in this.components) {
			val m = this.env.markets(component_id);
			// Assuming that the number of markets' outstanding shares is always the same during a simulation.
			total_value += (which_type == FUNDAMENTAL ? m.getFundamentalPrice(t) : m.getMarketPrice(t)) * m.getOutstandingShares();
			total_shares += m.getOutstandingShares();
		}
		return total_value / total_shares;
	}

	/**
	 * Compute the latest market index value.
	 * @return the index value
	 */
	public def computeMarketIndex():Double {
		assert this.env != null : "Cannot call during the setup procedure";
		return this.computeIndex(this.getTime(), MARKET);
	}
	/**
	 * Compute the latest market index value.
	 * @return the index value
	 */
	public def computeMarketIndex(t:Long):Double {
		assert this.env != null : "Cannot call during the setup procedure";
		return this.computeIndex(t, MARKET);
	}

	public def computeFundamentalIndex():Double = this.computeFundamentalIndex(this.getTime());
	/**
	 * Compute the latest fundamental index value.
	 * @return the index value
	 */
	public def computeFundamentalIndex(t:Long):Double {
		assert this.env != null : "Cannot call during the setup procedure";
		return this.computeIndex(t, FUNDAMENTAL);
	}
	
	public def setup(json:JSON.Value, sim:Simulator) {
		val random = new JSONRandom(getRandom());
		val spots = sim.getMarketsByName(json("markets"));
		this.addMarkets(spots);

		// WARN: Market's methods access to market.env is not available here :WARN

		this.setOutstandingShares(random.nextRandom(json("outstandingShares")) as Long);
		
		// helper function for setInitialMarketPrice, setInitialFundamentalPrice
		val compute = (which_type:WHICH_INDEX) => {
			var total_value:Double = 0;
			var total_shares:Double = 0;
			for (m in spots) {
				total_value += (which_type == FUNDAMENTAL ? m.getFundamentalPrice() : m.getMarketPrice()) * m.getOutstandingShares();
				total_shares += m.getOutstandingShares();
			}
			return total_value / total_shares;
		};
		this.setInitialMarketPrice(compute(MARKET));
		this.setInitialFundamentalPrice(compute(FUNDAMENTAL));
		return this;
	}

	public static def register(sim:Simulator):void {
		val className = "IndexMarket";
		sim.addMarketsInitializer(className, (id:Long, name:String, random:Random, json:JSON.Value) => {
			val markets = new ArrayList[Market]();
			val market = new IndexMarket(id, name, random).setup(json, sim);
			markets.add(market);
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
			return markets;
		});
	}
}
