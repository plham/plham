package samples.Option.agent;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.HashMap;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.util.RandomHelper;
import plham.util.Statistics;
import samples.Option.OptionAgent;
import samples.Option.OptionMarket;

/**
 * This implements a strategy that depends on its <q>leveraged</q> utility function.
 * It may trade all the assets or only the one has the max utility.
 */
public class LeverageFCNOptionAgent extends FCNOptionAgent {
	
	/** <code>true</code> if trading only the one having the maximum utility. */
	public var isUtilityMax:Boolean = true;
	/** The probability of buy orders. */
	public var leverageBuyRate:Double = 0.5; // In Kawakubo (2015), 0.0 or 1.0.

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();

		val utilities = new HashMap[OptionMarket,Double]();
		val expectedPrices = new HashMap[OptionMarket,Double]();
		val isBuyOrder = new HashMap[OptionMarket,Boolean]();
		var maxUtility:Double = Double.MIN_VALUE;
		var maxUtilityOption:OptionMarket = null;

		val options = filterOptionMarkets(markets);
		for (option in options) {
			val underlying = option.getUnderlyingMarket();
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
			expectedPrices(option) = expectedFuturePrice;

			isBuyOrder(option) = (random.nextDouble() < this.leverageBuyRate);
			// MEMO: In Kawakubo (2015) this is completely determined by the config: 100% buy or 100% sell.
			// It should be chosen like FCNOptionAgent in comparison with option.getPrice().
			// E.g. isBuyOrder(option) = (expectedFuturePrice < option.getPrice());

			val utility = Math.abs(underlyingPrice - strikePrice) / expectedFuturePrice;
			utilities(option) = utility;

			if (utility > maxUtility) {
				maxUtility = utility;
				maxUtilityOption = option;
			}
		}

		Console.OUT.println("# " + this.typeName()
			+ "{maxUtility: " + maxUtility
			+ ",maxUtilityOption: " + maxUtilityOption.id
			+ "}");

		if (this.isUtilityMax) {
			options.clear();
			options.add(maxUtilityOption);
		}

		for (option in options) {
			val orderPrice = expectedPrices(option);
			val orderVolume = Math.ceil(utilities(option)) as Long;
			if (isBuyOrder(option)) {
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, option, orderPrice, orderVolume, timeUnlimited));
			} else {
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, option, orderPrice, orderVolume, timeUnlimited));
			}
		}
		return orders;
	}
}
