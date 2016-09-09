package samples.Option.agent;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.HashSet;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.util.RandomHelper;
import plham.util.Statistics;
import samples.Option.OptionAgent;
import samples.Option.OptionMarket;
import samples.Option.pricer.OptionPricer;
import samples.Option.pricer.BlackScholesOptionPricer;

/**
 * A FCNAgent for option markets based on the model depeloped by Frijns etal (2010).
 * To make orders, it estimates his expected volatility by combining a fundamentalist and chartist components with noise.
 */
public class FCNOptionAgent extends OptionAgent {

	public var fundamentalWeight:Double;
	public var chartWeight:Double;
	public var noiseWeight:Double;
	public var timeWindowSize:Long;
	public var numSamples:Long;
	/** Fundamental mean reversion.  Frijns (2010) Table 2: mu = 0.957, sigma = 0.023. */
	public var alpha:Double = 0.957;
	/** How much the chartist incorporates positive shocks in prediction. Frijns (2010) Table 2: mu = -0.242, sigma = 0.101. */
	public var betaPos:Double = -0.242;
	/** How much the chartist incorporates negative shocks in prediction. Frijns (2010) Table 2: mu =  0.240, sigma = 0.075. */
	public var betaNeg:Double =  0.240;
	/** Noise scale parameter. */
	public var sigma:Double; //public var noiseScale:Double;

	public var optionPricer:OptionPricer = new BlackScholesOptionPricer(); // This may not be used.

	public def getOptionPricer():OptionPricer = optionPricer;

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();

		val option = this.chooseOptionMarket(markets);
		val underlying = option.getUnderlyingMarket();

		val t = option.getTime();
		assert t == underlying.getTime();

		val expectedVolatility = computeExpectedVolatility(underlying);

		val underlyingPrice = underlying.getPrice();
		val strikePrice = option.getStrikePrice();
		val volatility = expectedVolatility;
		val timeToMaturity = option.getTimeToMaturity();
		val rateToMaturity = option.getRateToMaturity();
		val riskFreeRate = option.getRiskFreeRate();
		val dividendYield = option.getDividendYield();

		var expectedFuturePrice:Double = 0.0;
		if (option.isCallOption()) {
			expectedFuturePrice = getOptionPricer().premiumCall(underlyingPrice, strikePrice, volatility, rateToMaturity, riskFreeRate, dividendYield);
		} else { // if (option.isPutOption())
			expectedFuturePrice = getOptionPricer().premiumPut(underlyingPrice, strikePrice, volatility, rateToMaturity, riskFreeRate, dividendYield);
		}
		if (expectedFuturePrice <= 0.0) {
			expectedFuturePrice = 0.0001; // From Kawakubo (2015)
		}

		Console.OUT.println("# " + this.typeName()
			+ "{option.id: " + option.id
			+ ",expectedFuturePrice: " + expectedFuturePrice
			+ ",isBuy: " + (expectedFuturePrice < option.getPrice())
			+ "}");

		val orderPrice = expectedFuturePrice;
		val orderVolume = 3;// From Kawakubo (2015)
		if (expectedFuturePrice < option.getPrice()) {
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, option, orderPrice, orderVolume, timeUnlimited));
		}
		if (expectedFuturePrice > option.getPrice()) {
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, option, orderPrice, orderVolume, timeUnlimited));
		}
		return orders;
	}

	public def computeExpectedVolatility(underlying:Market):Double {
		val fundamentalVolatility = (this.fundamentalWeight == 0.0 ? 0.0 : computeFundamentalVolatility(underlying));
		assert fundamentalVolatility >= 0.0 : "fundamentalVolatility >= 0.0";

		val chartVolatility = (this.chartWeight == 0.0 ? 0.0 : computeChartVolatility(underlying));
		assert chartVolatility >= 0.0 : "chartVolatility >= 0.0";

		val noiseVolatility = (this.noiseWeight == 0.0 ? 0.0 : computeNoiseVolatility(underlying));
		assert noiseVolatility >= 0.0 : "noiseVolatility >= 0.0";

		// Chiarella & Iori (2002) style.
		val expectedVolatility = (1.0 / (this.fundamentalWeight + this.chartWeight + this.noiseWeight))
				* (this.fundamentalWeight * fundamentalVolatility
					+ this.chartWeight * chartVolatility
					+ this.noiseWeight * noiseVolatility);
		assert isFinite(expectedVolatility) : "isFinite(expectedVolatility)";
		assert expectedVolatility >= 0.0 : "expectedVolatility >= 0.0";
		return expectedVolatility;
	}

	public def computeFundamentalVolatility(market:Market):Double {
		val t = market.getTime();
		val timeWindowSize = Math.min(t, this.timeWindowSize);

		val histVolatility = computeVolatility(market, timeWindowSize, 0);
		val uncondVolatility = 0.2; // From Kawakubo (2015)
		return Math.max(0.0, histVolatility - (1.0 - this.alpha) * (histVolatility - uncondVolatility));
	}

	public def computeChartVolatility(market:Market) {
		val t = market.getTime();
		val timeWindowSize = Math.min(t, this.timeWindowSize);

		val histVolatility = computeVolatility(market, timeWindowSize, 0);

		val random = new RandomHelper(getRandom());
		var epsilonPos:Double = 0.0; // The past positive shock in the volatility.
		var epsilonNeg:Double = 0.0; // The past negative shock in the volatility.

		var epsilon:Double = 1.0;

		val isRandomWalk = false;
		val isTrendFollowing = true;
		if (isTrendFollowing) {
			val meanHistVolatility = computeAverageVolatility(market, timeWindowSize, 0, numSamples);
			epsilon = histVolatility - meanHistVolatility;
		} else if (isRandomWalk) {
			epsilon = random.nextNormal(-0.05, 0.1); // From Kawakubo (2015)
		}
		if (epsilon == 0.0) {
			epsilon = random.nextNormal(-0.05, 0.1); // From Kawakubo (2015)
		}

		if (epsilon > 0.0) {
			epsilonPos = epsilon;
			epsilonNeg = 0.0;
		} else {
			epsilonPos = 0.0;
			epsilonNeg = epsilon;
		}

		assert (epsilonPos != 0.0) ^ (epsilonNeg != 0.0);
		// Eq.(4.5) in Kawakubo (2015) has a misprint (cf Frijns etal 2010).
		return Math.max(0.0, histVolatility
			+ betaPos * Math.pow(Math.sqrt(histVolatility) * epsilonPos, 2.0)
			+ betaNeg * Math.pow(Math.sqrt(histVolatility) * epsilonNeg, 2.0));
	}

	public def computeNoiseVolatility(market:Market):Double {
		val random = new RandomHelper(getRandom());
		val t = market.getTime();
		val timeWindowSize = Math.min(t, this.timeWindowSize);

		val histVolatility = computeVolatility(market, timeWindowSize, 0);
		return Math.max(0.0, histVolatility + random.nextNormal(0, sigma)); // isRandomWalk in Kawakubo (2015)
	}
}
