package samples.PriceLimit;
import x10.util.List;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.event.PriceLimitRule;
import plham.main.Simulator;
import plham.util.JSON;
import plham.Agent;
import plham.util.JSONRandom;
import plham.Event;
import samples.PriceLimit.PriceLimitMain;
import x10.util.Random;

public class PriceLimitFCNAgent extends FCNAgent {

	public var priceLimit:PriceLimitRule;

	public def submitOrders(market:Market):List[Order] {
		val orders = super.submitOrders(market);
		if (orders.size() == 0) {
			return orders;
		}

		for (order in orders) {
			val oldPrice = order.getPrice();
			val newPrice = priceLimit.getLimitedPrice(order, market);
			if (newPrice != oldPrice) {
				order.setPrice(newPrice); // Adjust the price.
				// You may need replanning.
			}
		}
		return orders;
	}
	public static def register(sim:Simulator):void {
		val className = "PriceLimitFCNAgent";
		sim.addAgentInitializer(className,
			(
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				return new PriceLimitFCNAgent(id, name, random).setup(json, sim);
			}
		);
	}
	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):PriceLimitFCNAgent {
		super.setup(json, sim);
		this.priceLimit = new PriceLimitMain().createEvents(sim.CONFIG(json("priceLimit")))(0) as PriceLimitRule;
		return this;
	}
}
