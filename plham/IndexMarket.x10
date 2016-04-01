package plham;
import x10.util.ArrayList;
import x10.util.List;
import plham.index.IndexScheme;

/**
 * IndexMarket is for a market (asset) associated with some underlying markets (assets).
 *
 * <p><ul>
 * <li> Call <code>addMarkets(List[Market])</code> to add underlying components.
 * <li> Specify its index calculation scheme ({@link plham.index.IndexScheme}) (unset by default).
 * </ul>  
 */
public class IndexMarket extends Market {

	/** The list of its underlying markets by their ids. */ 
	public var components:List[Long];

	public var marketIndices:List[Double];
	public var fundamentalIndices:List[Double];

	public var marketIndexScheme:IndexScheme;
	public var fundamentalIndexScheme:IndexScheme;

	public def this() {
		this.components = new ArrayList[Long]();
		this.marketIndices = new ArrayList[Double]();
		this.fundamentalIndices = new ArrayList[Double]();
	}

	public def addMarket(market:Market) {
		assert !this.components.contains(market.id);
		this.components.add(market.id);
	}

	public def addMarkets(markets:List[Market]) {
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
	public def getMarketIndex() = this.marketIndices(this.getTime());

	/**
	 * Get the market index at time <code>t</code>.
	 * Same as <code>getIndex(t)</code>.
	 * @param t
	 * @return the index value at time <code>t</code>
	 */
	public def getMarketIndex(t:Long) = this.marketIndices(t);

	/**
	 * Get the latest fundamental index value.
	 * @return the index value
	 */
	public def getFundamentalIndex() = this.fundamentalIndices(this.getTime());

	/**
	 * Get the fundamental index value at time <code>t</code>.
	 * @param t
	 * @return the index value at time <code>t</code>
	 */
	public def getFundamentalIndex(t:Long) = this.fundamentalIndices(t);

	/**
	 * Compute the latest market index value.
	 * @return the index value
	 */
	public def computeMarketIndex():Double {
		assert this.env != null : "Cannot call during the setup procedure";
		return this.marketIndexScheme.getIndex(this.env.markets, this.components);
	}

	/**
	 * Compute the latest fundamental index value.
	 * @return the index value
	 */
	public def computeFundamentalIndex():Double {
		assert this.env != null : "Cannot call during the setup procedure";
		return this.fundamentalIndexScheme.getIndex(this.env.markets, this.components);
	}

	/**
	 * Get this market index calculation scheme.
	 * @return the scheme
	 */
	public def getMarketIndexScheme() = this.marketIndexScheme;

	/**
	 * Set this market index calculation scheme.
	 * @param scheme
	 * @return the scheme
	 */
	public def setMarketIndexScheme(scheme:IndexScheme) = this.marketIndexScheme = scheme;

	public def getFundamentalIndexScheme() = this.fundamentalIndexScheme;

	public def setFundamentalIndexScheme(scheme:IndexScheme) = this.fundamentalIndexScheme = scheme;

	public def tickUpdateMarketPrice() {
		val t = this.getTime();
		super.tickUpdateMarketPrice();
		this.marketIndices(t) = this.computeMarketIndex();
	}

	public def updateMarketPrice(price:Double) {
		super.updateMarketPrice(price);
		this.marketIndices.add(this.computeMarketIndex());
	}

	public def updateFundamentalPrice(price:Double) {
		super.updateFundamentalPrice(price);
		this.fundamentalIndices.add(this.computeFundamentalIndex());
	}

	public def setInitialMarketIndex(index:Double) {
		this.marketIndices.add(index);
	}
	
	public def setInitialFundamentalIndex(index:Double) {
		this.fundamentalIndices.add(index);
	}
}
