package samples.DarkPool;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.Random;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.util.RandomHelper;

public class DarkPoolFCNAgent extends FCNAgent {

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):DarkPoolFCNAgent {
		super.setup(json, sim);
		this.darkPoolChance = new JSONRandom(this.getRandom()).nextRandom(json("darkPoolChance"));
		return this;
	}
	public static def register(sim:Simulator) {
		val className = "DarkPoolFCNAgent";
		sim.addAgentInitializer(className,
			(
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				return new DarkPoolFCNAgent(id, name, random).setup(json, sim);
			}
		);
	}

	public var darkPoolChance:Double;

	public def submitOrders(market:Market):List[Order] {
		val orders = new ArrayList[Order]();
		if (!this.isMarketAccessible(market)) {
			return orders;
		}
		if (!(market instanceof DarkPoolMarket)) {
			return orders;
		}

		val random = new RandomHelper(getRandom());

		val dark = market as DarkPoolMarket;
		val lit = dark.getLitMarket();

		orders.addAll(super.submitOrders(lit));
		for (order in orders) {
			if (!isFinite(dark.getMidPrice()) && random.nextBoolean(darkPoolChance)) {
				order.marketId = dark.id; // Change it from Lit to DarkPool
				order.setPrice(Order.NO_PRICE);
			}
		}
		return orders;
	}
}
