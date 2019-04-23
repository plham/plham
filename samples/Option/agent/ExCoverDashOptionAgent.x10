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
import samples.Option.OptionAgent;
import samples.Option.OptionMarket;

/**
 * This implements an extension of the delta hedge strategy.
 * In addition, when the maturity (to exercise) is near, this trades strategically the underlying to hedge the risk.
 */
public class ExCoverDashOptionAgent extends DeltaHedgeOptionAgent {

	public var stepSize:Long = 1; // One day

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):ExCoverDashOptionAgent {
		super.setup(json, sim);
		val random = new JSONRandom(this.getRandom());
		this.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
		this.hedgeBaselineVolume = random.nextRandom(json("hedgeBaselineVolume")) as Long;
		this.hedgeDeltaThreshold = random.nextRandom(json("hedgeDeltaThreshold")) as Long;
		this.stepSize = random.nextRandom(json("stepSize")) as Long;
		return this;
	}
	public static def register(sim:Simulator) {
		sim.addAgentInitializer("ExCoverDashOptionAgent", (id:Long, name:String, random:Random, json:JSON.Value) => {
			return new ExCoverDashOptionAgent(id, name, random).setup(json, sim);
		});
	}

	public def isInTheMoneyOption(option:OptionMarket):Boolean {
		val underlying = option.getUnderlyingMarket();
		return (option.isCallOption() && underlying.getPrice() > option.getStrikePrice())
			|| (option.isPutOption() && underlying.getPrice() < option.getStrikePrice());
	}

	public def getInTheMoneyOptionMarkets(markets:List[Market], timeToExercise:Long):List[OptionMarket] {
		val options = new ArrayList[OptionMarket]();
		for (market in markets) {
			if (this.isMarketAccessible(market) && market instanceof OptionMarket) {
				val option = market as OptionMarket;
				if (isInTheMoneyOption(option) && option.getTimeToMaturity() <= timeToExercise) {
					options.add(option);
				}
			}
		}
		return options;
	}

	public def doExAction(markets:List[Market]):List[Order] {
		val timeToExercise = this.stepSize * 1; // In Kawakubo (2015) 0.0027 * 3 (For Black-Scholes, one year = 1.0)
		val orders = new ArrayList[Order]();
		val options = getInTheMoneyOptionMarkets(markets, timeToExercise);
		for (option in options) {
			val underlying = option.getUnderlyingMarket();
			val orderVolume = Math.abs(this.getAssetVolume(option));
			// MEMO: getAssetVolume() returns positive if buy long position; negative if sell short position.
			if (option.isCallOption() && this.getAssetVolume(option) > 0) {
				orders.add(new Order(Order.KIND_SELL_MARKET_ORDER, this, underlying, Order.NO_PRICE, orderVolume, timeUnlimited));
			}
			if (option.isPutOption() && this.getAssetVolume(option) > 0) {
				orders.add(new Order(Order.KIND_BUY_MARKET_ORDER, this, underlying, Order.NO_PRICE, orderVolume, timeUnlimited));
			}
		}
		return orders;
	}

	public def doExCover(markets:List[Market]):List[Order] {
		val timeToExercise = this.stepSize * 2; // In Kawakubo (2015) 0.0027 * 3 (For Black-Scholes, one year = 1.0)
		val orders = new ArrayList[Order]();
		val options = getInTheMoneyOptionMarkets(markets, timeToExercise);
		for (option in options) {
			val underlying = option.getUnderlyingMarket();
			val orderVolume = Math.abs(this.getAssetVolume(option));
			if (option.isCallOption() && this.getAssetVolume(option) < 0) {
				orders.add(new Order(Order.KIND_BUY_MARKET_ORDER, this, underlying, Order.NO_PRICE, orderVolume, timeUnlimited));
			}
			// MEMO: The below doesn't appear in Kawakubo (2015)
//			if (option.isPutOption() && this.getAssetVolume(option) > 0) {
//				orders.add(new Order(Order.KIND_SELL_MARKET_ORDER, this, underlying, Order.NO_PRICE, orderVolume, timeUnlimited));
//			}
		}
		return orders;
	}

	public def doExDash(markets:List[Market]):List[Order] {
		val timeToExercise = this.stepSize * 3; // In Kawakubo (2015) 0.0027 * 3 (For Black-Scholes, one year = 1.0)
		val orders = new ArrayList[Order]();
		val options = getInTheMoneyOptionMarkets(markets, timeToExercise);
		for (option in options) {
			val underlying = option.getUnderlyingMarket();
			val orderVolume = Math.abs(this.getAssetVolume(option));
			if (option.isCallOption() && this.getAssetVolume(option) > 0) {
				doDeltaHedge(markets, underlying);
			}
			if (option.isCallOption() && this.getAssetVolume(option) < 0) {
				orders.add(new Order(Order.KIND_SELL_MARKET_ORDER, this, underlying, Order.NO_PRICE, orderVolume, timeUnlimited));
			}
			if (option.isPutOption() && this.getAssetVolume(option) > 0) {
				doDeltaHedge(markets, underlying);
			}
			if (option.isPutOption() && this.getAssetVolume(option) < 0) {
				orders.add(new Order(Order.KIND_BUY_MARKET_ORDER, this, underlying, Order.NO_PRICE, orderVolume, timeUnlimited));
			}
		}
		return orders;
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = super.submitOrders(markets);
		val random = getRandom();
		val i = random.nextLong(3);
		if (i == 0) {
			orders.addAll(doExAction(markets));
		} else if (i == 1) {
			orders.addAll(doExCover(markets));
		} else if (i == 2) {
			orders.addAll(doExDash(markets));
		}

		Console.OUT.println("# " + this.typeName()
			+ "{type: " + ((i == 0) ? "ExAction" : (i == 1) ? "ExCover" : (i == 2) ? "ExDash" : "Unknown")
			+ "}");

		return orders;
	}
}
