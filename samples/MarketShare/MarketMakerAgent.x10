package samples.MarketShare;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.Random;
import plham.HighFrequencyAgent;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;

public class MarketMakerAgent extends HighFrequencyAgent {

	public var targetMarketId:Long;
	public var netInterestSpread:Double;
	public var orderTimeLength:Long;

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):MarketMakerAgent {
		super.setup(json, sim);
		val targetMarket = sim.getMarketByName(json("targetMarket"));
		val random = new JSONRandom(this.getRandom());
		this.targetMarketId = targetMarket.id;
		this.netInterestSpread = random.nextRandom(json("netInterestSpread"));
		this.orderTimeLength = random.nextRandom(json("orderTimeLength", "2")) as Long;
		return this;
	}
	public static def register(sim:Simulator):void {
		val className = "MarketMakerAgent";
		sim.addAgentInitializer(className,
			(
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				return new MarketMakerAgent(id, name, random).setup(json, sim);
			}
		);
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();

		val target = markets(this.targetMarketId);

		var basePrice:Double = getBasePrice(markets);
		if (!isFinite(basePrice)) {
			basePrice = target.getPrice(); // Use this instead.
		}

		val priceMargin = target.getFundamentalPrice() * this.netInterestSpread * 0.5;
		val orderVolume = 1;
		orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, target, basePrice - priceMargin, orderVolume, this.orderTimeLength));
		orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, target, basePrice + priceMargin, orderVolume, this.orderTimeLength));

		return orders;
	}

	// The simple market maker strategy.
	public def getBasePrice(markets:List[Market]):Double {
		var maxBuy:Double = Double.NEGATIVE_INFINITY;
		for (market in markets) {
			if (isMarketAccessible(market)) {
				maxBuy = Math.max(maxBuy, market.getBestBuyPrice());
			}
		}
		var minSell:Double = Double.POSITIVE_INFINITY;
		for (market in markets) {
			if (isMarketAccessible(market)) {
				minSell = Math.min(minSell, market.getBestSellPrice());
			}
		}
		return (maxBuy + minSell) / 2.0;
	}

	public static def isFinite(x:Double) {
		return !x.isNaN() && !x.isInfinite();
	}
}
