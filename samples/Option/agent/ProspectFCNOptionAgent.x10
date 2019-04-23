package samples.Option.agent;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.HashSet;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.util.RandomHelper;
import plham.util.Statistics;
import plham.util.Newton;
import samples.Option.OptionAgent;
import samples.Option.OptionMarket;

/**
 * This implements a strategy that pricing is based on a modified prospect theory developed by Kimura (2006) "An option pricing method using prospect theory" (in Japanese).
 */
public class ProspectFCNOptionAgent extends FCNOptionAgent {

	public var probabilityWeight:Double = 0.91; // From Kimura (2006): probabilityWeight in decision weight pi(p)
	public var riskSensitivity:Double = 0.00055; // From Kimura (2006): riskSensitivity (> 0);
	public var lossAversion:Double = 2.3; // From Kimura (2006): lossAversion (> 1)
	/** The probability of loss; Set to chance level.  It is better if empirically estimated. */
	public var lossProbability:Double = 0.5;

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator) {
		super.setup(json, sim);
		val random = new JSONRandom(this.getRandom());
		this.probabilityWeight = random.nextRandom(json("probabilityWeight", "0.91"));
		this.riskSensitivity = random.nextRandom(json("riskSensitivity", "0.00055"));
		this.lossAversion = random.nextRandom(json("lossAversion", "2.3"));
		this.lossProbability = random.nextRandom(json("lossProbability", "0.5"));
		return this;
	}
	public static def register(sim:Simulator) {
		sim.addAgentInitializer("ProspectFCNOptionAgent", (id:Long, name:String, random:Random, json:JSON.Value) => {
			return new ProspectFCNOptionAgent(id, name, random).setup(json, sim);
		});
	}
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
		// PROSPECT THEORY //
		{
			// A single asset version of Kimura (2006)'s prospect theory model
			val tau = rateToMaturity;
			val r = riskFreeRate;
			val gamma = this.probabilityWeight; 
			val beta = this.riskSensitivity;
			val lambda = this.lossAversion;
			// 
			val p = this.lossProbability;
			//
			val w = (p:Double) => Math.pow(p, gamma) / Math.pow(Math.pow(p, gamma) + Math.pow(1 - p, gamma), 1 / gamma);
			// The Kahnemann's original:
			// val v = (x:Double) => (x >= 0.0) ? Math.pow(x, -beta) : -lambda * Math.pow(-x, -beta);
			// Kimura (2016) version:
			val v = (x:Double) => (x >= 0.0) ? 1 - Math.exp(-beta * x) : -lambda * (1 - Math.exp(beta * x));
			val vprime = (x:Double) => (x >= 0.0) ? beta * Math.exp(-beta * x) : lambda * beta * Math.exp(beta * x); // The derivative of v
			val pi = w(p);
			val V = (x:Double) => pi * v(x); // The value function for single asset
			
			val CT = Math.abs(strikePrice - underlyingPrice); // The return at maturity
			val f = (Ct:Double) => {
				val g = CT - Math.exp(-r * tau) * Ct; // Return
				val dv = vprime(g);
				var Vdv:Double = V(dv);
				return Ct - Math.exp(-r * tau) * V(CT * (dv / Vdv)); // Eq.(11) in Kimura (2006): option price equation
			};
			val Ct0 = option.getPrice();
			val Ct = Newton.optimize(f, Ct0);

			expectedFuturePrice = Ct;
			if (expectedFuturePrice <= 0.0) {
				expectedFuturePrice = 0.0001; // From Kawakubo (2015)
			}
		}
		// END PROSPECT THEORY //

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
}
