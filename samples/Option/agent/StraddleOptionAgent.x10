package samples.Option.agent;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.Random;
import plham.Market;
import plham.Order;
import plham.Agent;
import plham.util.RandomHelper;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.main.Simulator;
import samples.Option.OptionMarket;
import samples.Option.OptionAgent;
import samples.Option.util.OptionMatrix;

/**
 * This implements the straddle strategy that trades a pair of call and put option having the same strike and maturity (and the same underlying). 
 */
public class StraddleOptionAgent extends OptionAgent {

	public var timeWindowSize:Long;
	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public static def register(sim:Simulator) {
		sim.addAgentInitializer("StraddleOptionAgent", (id:Long, name:String, random:Random, json:JSON.Value) => {
			return new StraddleOptionAgent(id, name, random).setup(json, sim);
		});
	}
	public def setup(json:JSON.Value, sim:Simulator):StraddleOptionAgent {
		super.setup(json, sim);
		this.timeWindowSize = new JSONRandom(this.getRandom()).nextRandom(json("timeWindowSize")) as Long;
		return this;
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
