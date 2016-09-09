package samples.Option.agent;
import x10.util.List;
import x10.util.ArrayList;
import plham.Market;
import plham.Order;
import plham.Agent;
import plham.util.RandomHelper;
import samples.Option.OptionAgent;
import samples.Option.OptionMarket;
import samples.Option.pricer.OptionPricer;
import samples.Option.pricer.BlackScholesOptionPricer;

/**
 * This implements the delta hedge strategy that manages the risk (measured by the greek, delta) in the underlying by offsetting positions.
 */
public class DeltaHedgeOptionAgent extends OptionAgent {

	public var timeWindowSize:Long;
	public var hedgeBaselineVolume:Long;
	public var hedgeDeltaThreshold:Double = 0.1;

	public var optionPricer:OptionPricer = new BlackScholesOptionPricer(); // This may not be used.

	public def getOptionPricer():OptionPricer = optionPricer;

	public def computeDelta(underlying:Market, options:List[OptionMarket]):Double {
		val underlyingVolatility = computeVolatility(underlying, timeWindowSize, 0);
		val underlyingPrice = underlying.getPrice();

		var delta:Double = 0.0;
		for (option in options) {
			val strikePrice = option.getStrikePrice();
			val volatility = underlyingVolatility;
			val timeToMaturity = option.getTimeToMaturity();
			val rateToMaturity = option.getRateToMaturity();
			val riskFreeRate = option.getRiskFreeRate();
			val dividendYield = option.getDividendYield();

			var d:Double = 0.0;
			if (option.isCallOption()) {
				d = getOptionPricer().deltaCall(underlyingPrice, strikePrice, volatility, rateToMaturity, riskFreeRate, dividendYield);
			}
			if (option.isPutOption()) {
				d = getOptionPricer().deltaPut(underlyingPrice, strikePrice, volatility, rateToMaturity, riskFreeRate, dividendYield);
			}
			delta += d * this.getAssetVolume(option); // getAssetVolume() returns positive if buy long position; negative if sell short position.
		}
		return delta;
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val underlying = chooseUnderlyingMarket(markets);
		return doDeltaHedge(markets, underlying);
	}
	
	public def doDeltaHedge(markets:List[Market], underlying:Market):List[Order] {
		val orders = new ArrayList[Order]();

		val options = filterOptionMarkets(markets, underlying);
		if (options.size() == 0) {
			return orders;
		}

		val delta = computeDelta(underlying, options);
		val volume = Math.abs(delta) as Long + this.getAssetVolume(underlying);

		Console.OUT.println("# " + this.typeName()
			+ "{delta: " + delta
			+ ",volume: " + volume
			+ "}");

		if (Math.abs(delta) < this.hedgeDeltaThreshold) {
			return super.submitOrders(markets);
		}

		val hedgeBaseline = this.hedgeBaselineVolume;
		assert this.hedgeBaselineVolume >= 0 : "hedgeBaselineVolume >= 0";

		val orderBuyPrice = underlying.getBestBuyPrice();
		val orderSellPrice = underlying.getBestSellPrice();
		val orderVolume = Math.abs(volume);

		// No order has been submitted to the underlying.
		if (!isFinite(orderBuyPrice) || !isFinite(orderSellPrice)) {
			return orders; // Stop thinking.
		}

		if (delta > 0.0) {
			if (volume > +hedgeBaseline) {
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, underlying, orderSellPrice, orderVolume, timeUnlimited));
			}
			if (volume < -hedgeBaseline) {
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, underlying, orderBuyPrice, orderVolume, timeUnlimited));
			}
		}
		if (delta < 0.0) {
			if (volume > +hedgeBaseline) {
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, underlying, orderBuyPrice, orderVolume, timeUnlimited));
			}
			if (volume < -hedgeBaseline) {
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, underlying, orderSellPrice, orderVolume, timeUnlimited));
			}
		}
		return orders;
	}
}
