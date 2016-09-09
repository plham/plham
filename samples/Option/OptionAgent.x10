package samples.Option;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.util.Statistics;

public class OptionAgent extends Agent {

	public val timeUnlimited = 1e+10 as Long; // Very long future

	public def chooseUnderlyingMarket(markets:List[Market]):Market {
		return getRandomUnderlyingMarket(this, markets, getRandom());
	}

	public def chooseOptionMarket(markets:List[Market]):OptionMarket {
		return getRandomOptionMarket(this, markets, getRandom());
	}

	//** Utility functions **//

	public static def isFinite(x:Double) {
		return !x.isNaN() && !x.isInfinite();
	}

	public static def filterOptionMarkets(markets:List[Market], underlying:Market):List[OptionMarket] {
		return filterOptionMarkets(markets, (option:OptionMarket) => option.getUnderlyingMarket().id == underlying.id);
	}

	public static def filterOptionMarkets(markets:List[Market], p:(option:OptionMarket)=>Boolean):List[OptionMarket] {
		val options = new ArrayList[OptionMarket]();
		for (market in markets) {
			if (market instanceof OptionMarket && p(market as OptionMarket)) {
				options.add(market as OptionMarket);
			}
		}
		return options;
	}

	/**
	 * Return a list of option markets accessible by this agent.
	 * @param markets
	 * @return a list of option markets
	 */
	public def filterOptionMarkets(markets:List[Market]):List[OptionMarket] {
		return filterOptionMarkets(markets, (option:OptionMarket) => this.isMarketAccessible(option));
	}

	/**
	 * Return an option market accessible by the agent randomly taken.
	 * @param agent
	 * @param markets
	 * @param random
	 * @return an option market
	 */
	public static def getRandomOptionMarket(agent:Agent, markets:List[Market], random:Random):OptionMarket {
		val options = new ArrayList[Long]();
		for (market in markets) {
			if (agent.isMarketAccessible(market) && market instanceof OptionMarket) {
				options.add(market.id);
			}
		}
		assert options.size() > 0;
		val i = options(random.nextLong(options.size()));
		return markets(i) as OptionMarket;
	}
	
	/**
	 * Return an underlying market accessible by the agent randomly taken.
	 * @param agent
	 * @param markets
	 * @param random
	 * @return an underlying market
	 */
	public static def getRandomUnderlyingMarket(agent:Agent, markets:List[Market], random:Random):Market {
		val options = new ArrayList[Long]();
		for (market in markets) {
			if (agent.isMarketAccessible(market) && market instanceof OptionMarket) {
				val id = (market as OptionMarket).getUnderlyingMarket().id;
				if (!options.contains(id)) {
					options.add(id);
				}
			}
		}
		assert options.size() > 0;
		val i = options(random.nextLong(options.size()));
		return markets(i) as Market;
	}

	/**
	 * Compute a volatility of the market using the timeseries from <code>start</code>
	 * back to <code>start - timeWindowSize</code> with time delay, <code>delay</code>,
	 * which is used to calculate log returns (negative indices will be ignored).
	 * @param market
	 * @param timeWindowSize
	 * @param delay
	 * @return the volatility
	 */
	public static def computeVolatility(market:Market, timeWindowSize:Long, start:Long, delay:Long):Double {
		assert timeWindowSize >= 0;
		assert delay >= 0;
		assert start <= market.getTime();
		val t = start;
		val d = delay;
		val logReturns = new ArrayList[Double]();
		for (u in 0..(timeWindowSize - 1)) {
			if (t - d - u > 0) {
				logReturns.add(Math.log(market.getPrice(t - u) / market.getPrice(t - d - u - 1)));
			}
		}
		val volatility = Math.sqrt(Statistics.variance(logReturns));
		return volatility;
	}

	/**
	 * Compute a volatility of the market from the latest time point (<code>market.getTime()</code>).
	 */
	public static def computeVolatility(market:Market, timeWindowSize:Long, delay:Long):Double {
		return computeVolatility(market, timeWindowSize, market.getTime(), delay);
	}

	/**
	 * Compute a volatility of the market from the latest time point (<code>market.getTime()</code>) with no delay.
	 */
	public static def computeVolatility(market:Market, timeWindowSize:Long):Double {
		return computeVolatility(market, timeWindowSize, market.getTime(), 0);
	}

	/**
	 * Compute the average volatility of the market using volatility timeseries from the latest time point.
	 * @param market
	 * @param timeWindowSize
	 * @param delay
	 * @param numSamples  the number of volatility time points
	 * @return the average volatility
	 */
	public static def computeAverageVolatility(market:Market, timeWindowSize:Long, delay:Long, numSamples:Long):Double {
		val t = market.getTime();
		val vols = new ArrayList[Double]();
		for (n in 0..(numSamples - 1)) {
			vols.add(computeVolatility(market, timeWindowSize, t - n, delay));
		}
		return Statistics.mean(vols);
	}
}
