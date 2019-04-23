package samples.Option.agent;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.Random;
import plham.Market;
import plham.Order;
import plham.Agent;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.util.RandomHelper;
import samples.Option.OptionMarket;
import samples.Option.OptionAgent;
import samples.Option.util.OptionMatrix;

/**
 * This implements the synthetic strategy that exploits the opportunity of arbitrage between a synthetic position, composed of call and put options, and the underlying position.
 */
public class SyntheticOptionAgent extends OptionAgent {

	public var timeWindowSize:Long;

	// http://money.infobank.co.jp/contents/S200385.htm
	// http://money.infobank.co.jp/contents/K500177.htm
	// http://money.infobank.co.jp/contents/R200023.htm

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):SyntheticOptionAgent {
		super.setup(json, sim);
		this.timeWindowSize = new JSONRandom(this.getRandom()).nextRandom(json("timeWindowSize")) as Long;
		return this;
	}
	public static def register(sim:Simulator) {
		sim.addAgentInitializer("SyntheticOptionAgent", (id:Long, name:String, random:Random, json:JSON.Value) => {
			return new SyntheticOptionAgent(id, name, random).setup(json, sim);
		});
	}
	
	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();

		val random = new RandomHelper(getRandom());

		val underlying = chooseUnderlyingMarket(markets);

		val optionMatrix = new OptionMatrix(underlying);
		optionMatrix.setup(markets);
		val om = optionMatrix;

		val sATM = om.toStrikePriceIndex(underlying.getPrice()); // Find strikePrice == underlyingPrice.
		val sLen = om.numStrikePrices(); // max + 1
		val uLen = om.numMaturityTimes(); // max + 1
		// TODO: Currently ATM inclusive, so there always is one OptionMarket.
		val sCall = sATM + random.nextLong(sLen - sATM); // OTM(Call) if strikePrice > underlyingPrice
		val sPut = random.nextLong(sATM + 1); // OTM(Put) if strikePrice < underlyingPrice
		val u = random.nextLong(uLen);
		val callOption = om.getCallOptionMarket(markets, sCall, u);
		val putOption = om.getPutOptionMarket(markets, sPut, u);

		val strikePrice = callOption.getStrikePrice();

		var expectedCallPrice:Double;
		var expectedPutPrice:Double;
		if (random.nextBoolean(0.5)) {
			// Bullish  (up)  if CALL_BUY and PUT_SELL (synthetic long/buy position)
			expectedCallPrice = callOption.getBestBuyPrice();
			expectedPutPrice = putOption.getBestSellPrice();
		} else {
			// Bearish (down) if CALL_SELL and PUT_BUY (synthetic short/sell position)
			expectedCallPrice = callOption.getBestSellPrice();
			expectedPutPrice = putOption.getBestBuyPrice();
		}

		if (!isFinite(expectedCallPrice) || !isFinite(expectedPutPrice)) {
			return orders; // Stop thinking.
		}

		var orderVolume:Long = 3; // From Kawakubo (2015)

		val syntheticPrice = strikePrice + expectedCallPrice - expectedPutPrice;
		val underlyingPrice = underlying.getPrice();
		if (syntheticPrice > underlyingPrice) {
			// Conversion: sell synthetic, buy underlying
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, callOption, expectedCallPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, putOption, expectedPutPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_BUY_MARKET_ORDER, this, underlying, underlyingPrice, orderVolume, timeUnlimited));
		} else {
			// Reversal: buy synthetic, sell underlying
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, callOption, expectedCallPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, putOption, expectedPutPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_SELL_MARKET_ORDER, this, underlying, underlyingPrice, orderVolume, timeUnlimited));
		}

		Console.OUT.println("# " + this.typeName()
			+ "{ callOption.id: " + callOption.id
			+ ", putOption.id: " + putOption.id
			+ ", isConversion: " + (syntheticPrice > underlyingPrice)
			+ "}");

		return orders;
	}
}
