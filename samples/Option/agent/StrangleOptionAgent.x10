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
 * This implements the strangle strategy that trades a pair of call and put option having different strikes but the same maturity (and the same underlying). 
 */
public class StrangleOptionAgent extends OptionAgent {

	public var timeWindowSize:Long;

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):StrangleOptionAgent {
		super.setup(json, sim);
		this.timeWindowSize = new JSONRandom(this.getRandom()).nextRandom(json("timeWindowSize")) as Long;
		return this;
	}
	public static def register(sim:Simulator) {
		sim.addAgentInitializer("StrangleOptionAgent", (id:Long, name:String, random:Random, json:JSON.Value) => {
			return new StrangleOptionAgent(id, name, random).setup(json, sim);
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

		val histVolatility = computeVolatility(underlying, timeWindowSize, 0);
		val uncondVolatility = 0.2; // From Kawakubo (2015)
		val thresVolatility = uncondVolatility;

		// From Kawakubo (2015) based on the ask prices.
		var expectedCallPrice:Double = callOption.getBestSellPrice();
		var expectedPutPrice:Double = putOption.getBestSellPrice();

		if (!isFinite(expectedCallPrice) || !isFinite(expectedPutPrice)) {
			return orders; // Stop thinking.
		}

		var orderVolume:Long = 3; // From Kawakubo (2015)

		if (histVolatility > thresVolatility) {
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, callOption, expectedCallPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, putOption, expectedPutPrice, orderVolume, timeUnlimited));
		} else {
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, callOption, expectedCallPrice, orderVolume, timeUnlimited));
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, putOption, expectedPutPrice, orderVolume, timeUnlimited));
		}

		Console.OUT.println("# " + this.typeName()
			+ "{ callOption.id: " + callOption.id
			+ ", putOption.id: " + putOption.id
			+ ", isLongPosition: " + (histVolatility > thresVolatility)
			+ "}");

		return orders;
	}
}
