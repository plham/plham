package samples.Option.agent;
import x10.util.List;
import x10.util.ArrayList;
import plham.Market;
import plham.Order;
import plham.Agent;
import plham.util.RandomHelper;
import samples.Option.OptionAgent;
import samples.Option.OptionMarket;
import samples.Option.util.OptionMatrix;

/**
 * This implements a strategy that exploits the opportunity of arbitrage implied by the breaking of put-call parity relation.
 */
public class PutCallParityOptionAgent extends OptionAgent {

	public var timeWindowSize:Long;
	public var numSamples:Long; // For average volatility.

	public def getLastClosingPrice(market:OptionMarket, n:Long):Double {
		assert n >= 1;
		val u = market.getMaturityInterval();
		val du = market.getTimeToMaturity();
		assert u >= du;
		val t = market.getTime();
		val dt = (u - du) + (n - 1) * u;
		return market.getPrice(t - dt); // TODO: Check
	}

	public def getLastClosingPrice(market:OptionMarket):Double = getLastClosingPrice(market, 1);

	public def getLastPutCallParityError(underlying:Market, callOption:OptionMarket, putOption:OptionMarket):Double {
		// NOTE: Assuming callOption and putOption share the properties except for the closing price.
		val riskFreeRate = callOption.getRiskFreeRate();
		val dividendYield = callOption.getDividendYield();
		// Put-call parity: P - C = K exp(-r T) - S
		val P = getLastClosingPrice(putOption);
		val C = getLastClosingPrice(callOption);
		val S = underlying.getPrice();
		val K = callOption.getStrikePrice();
		val T = callOption.getTimeToMaturity();
		val r = riskFreeRate;
		return Math.abs((P - C) - (K * Math.exp(-r * T) - S));
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();

		val random = new RandomHelper(getRandom());

		val underlying = chooseUnderlyingMarket(markets);

		val optionMatrix = new OptionMatrix(underlying);
		optionMatrix.setup(markets);
		val om = optionMatrix;

		val sLen = om.numStrikePrices(); // max + 1
		val uLen = om.numMaturityTimes(); // max + 1

		val s = random.nextLong(sLen);
		val u = random.nextLong(uLen);
		val callOption = om.getCallOptionMarket(markets, s, u);
		val putOption = om.getPutOptionMarket(markets, s, u);
		val option = callOption;

		val underlyingPrice = underlying.getPrice();
		val strikePrice = option.getStrikePrice();
		//val volatility = expectedVolatility;
		val timeToMaturity = option.getTimeToMaturity();
		val rateToMaturity = option.getRateToMaturity();
		val riskFreeRate = option.getRiskFreeRate();
		val dividendYield = option.getDividendYield();

		var expectedFuturePrice:Double = 0.0;
		val tol = 1e-1;
		if (getLastPutCallParityError(underlying, callOption, putOption) > tol) {
			val isCallBasis = random.nextBoolean(0.5);
			if (isCallBasis) {
				expectedFuturePrice = callOption.getPrice() + underlyingPrice - strikePrice * Math.exp(-riskFreeRate * rateToMaturity);
			} else {
				expectedFuturePrice = putOption.getPrice() - underlyingPrice + strikePrice * Math.exp(-riskFreeRate * rateToMaturity);
			}
		} else {
			return orders; // No opportunity of arbitrage
		}

		Console.OUT.println("# " + this.typeName()
			+ "{expectedFuturePrice: " + expectedFuturePrice
			+ ",callOption.id: " + callOption.id
			+ ",putOption.id: " + putOption.id
			+ "}");

		if (expectedFuturePrice <= 0.0) {
			return orders; // Stop thinking.
		}

		val orderPrice = expectedFuturePrice;
		val orderVolume = 3;// From Kawakubo (2015)

		val volatilityThreshold = computeAverageVolatility(underlying, timeWindowSize, 0, numSamples);
		val histVolatility = computeVolatility(underlying, timeWindowSize, 0);

		if (histVolatility > volatilityThreshold) {
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, callOption, orderPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, putOption, orderPrice, orderVolume, timeUnlimited));
		} else {
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, callOption, orderPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, putOption, orderPrice, orderVolume, timeUnlimited));
		}
		return orders;
	}
}
