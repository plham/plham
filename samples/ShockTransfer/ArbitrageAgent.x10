package samples.ShockTransfer;
import x10.util.ArrayList;
import x10.util.Indexed;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.HighFrequencyAgent;
import plham.IndexMarket;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;

public class ArbitrageAgent extends HighFrequencyAgent {

	/** The volume of orders to each spot market. */
	public var orderVolume:Long;
	/** Submit orders if the price gap is more than this threshold. */
	public var orderThresholdPrice:Double;
	/** As HFT, the time length of orders should be very short (&lt;= 2). */
	public var orderTimeLength:Long;

	public def this(id:Long, name:String, random:Random) {
		super(id, name, random);
		this.orderVolume = 1;
		this.orderThresholdPrice = 0.0;
		this.orderTimeLength = 2; // An order's lifetime; no rationale.
	}
	public def this() {
		this(-1, "default", new Random());
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();
		for (market in markets) {
			if (this.isMarketAccessible(market)) {
				orders.addAll(this.submitOrders(market));
			}
		}
		return orders;
	}

	public def submitOrders(market:Market):List[Order] {
		val orders = new ArrayList[Order]();
		if (!(market instanceof IndexMarket)) {
			return orders;
		}
		if (!this.isMarketAccessible(market)) {
			return orders;
		}

		val index = market as IndexMarket;
		val spots = index.getMarkets();
		if (!index.isRunning() || !index.isAllMarketsRunning()) {
			return orders; // Stop thinking.
		}

		val marketIndex = index.getIndex();
		val marketPrice = index.getPrice();

		if (marketPrice < marketIndex && marketIndex - marketPrice > this.orderThresholdPrice) {
			val n = this.orderVolume;
			val N = spots.size() * n;

			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, index, index.getPrice(), N, this.orderTimeLength));
			for (m in spots) {
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, m, m.getPrice(), n, this.orderTimeLength));
			}
		}
		if (marketPrice > marketIndex && marketPrice - marketIndex > this.orderThresholdPrice) {
			val n = this.orderVolume;
			val N = spots.size() * n;

			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, index, index.getPrice(), N, this.orderTimeLength));
			for (m in spots) {
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, m, m.getPrice(), n, this.orderTimeLength));
			}
		}
		return orders;
	}

	public def setupArbitrageAgent(json:JSON.Value, sim:Simulator) {
		val random = new JSONRandom(getRandom());
		this.orderVolume = json("orderVolume").toLong();
		this.orderThresholdPrice = json("orderThresholdPrice").toDouble();

		assert json("markets").size() == 1 : "ArbitrageAgents suppose only one IndexMarket";
		assert sim.getMarketByName(json("markets")(0)) instanceof IndexMarket : "ArbitrageAgents suppose only one IndexMarket";
		val market = sim.getMarketByName(json("markets")(0)) as IndexMarket;
		this.setMarketAccessible(market);
		for (id in market.getComponents()) {
			this.setMarketAccessible(id);
		}

		this.setAssetVolume(market, random.nextRandom(json("assetVolume")) as Long);
		for (id in market.getComponents()) {
			this.setAssetVolume(id, random.nextRandom(json("assetVolume")) as Long);
		}
		this.setCashAmount(random.nextRandom(json("cashAmount")));
		return this;
	}

	public static def register(sim:Simulator):void {
		val className = "ArbitrageAgent";
		sim.addAgentsInitializer(className, (name:String, randoms:Indexed[Random], range:LongRange, json:JSON.Value, container:Settable[Long, Agent]) => {
			for (i in range) {
				container(i) = createArbitrageAgent(i, name, randoms(i), json, sim);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		});
	}

	public static def createArbitrageAgent(id:Long, name:String, random:Random, json:JSON.Value, sim:Simulator):ArbitrageAgent {
		return new ArbitrageAgent(id, name, random).setupArbitrageAgent(json, sim);
	}
}
