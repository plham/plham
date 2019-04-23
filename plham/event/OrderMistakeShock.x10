package plham.event;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import plham.util.JSON;

import x10.util.Random;

/**
 * This suddenly changes the market price as a consequence of a fat finger error,
 * e.g., caused by an huge amount of orders at an extremely cheap or expensive price.
 */
public class OrderMistakeShock implements Market.MarketEvent {
	
	public val id:Long;
	public val name:String;
	public val random:Random;
	public var marketId:Long;
	public var agentId:Long;
	public var triggerTime:Long;
	public var priceChangeRate:Double;
	public var orderVolume:Long;
	public var orderTimeLength:Long;

	public def this(id:Long, name:String, random:Random) {
		this.id = id;
		this.name = name;
		this.random = random;
	}

	public def update(market:Market):void {
		assert market.id == this.marketId;
		val env = market.env;
		val t = market.getTime();
		if (t == this.triggerTime) {
			val agent = env.agents(this.agentId);
			val basePrice = market.getPrice();
			val orderPrice = basePrice * (1 + this.priceChangeRate);
			val timeLength = orderTimeLength;
			val order:Order;
			if (this.priceChangeRate <= 0.0) {
				// Hit sell orders to the buy side.
				order = new Order(Order.KIND_SELL_LIMIT_ORDER, agent, market, orderPrice, orderVolume, timeLength);
			} else {
				// Hit buy orders to the sell side.
				order = new Order(Order.KIND_BUY_LIMIT_ORDER, agent, market, orderPrice, orderVolume, timeLength);
			}
			market.handleOrder(order);
			Console.OUT.println("# OrderMistakeShock: " + order + "(volume " + order.getVolume() + ")");
		}
	}

	public static def register(sim:Simulator) {
		val name = "OrderMistakeShock";
		sim.addEventInitializer(name, (id:Long, name:String, random:Random, json:JSON.Value)=>{
			return new OrderMistakeShock(id, name, random).setup(json, sim);
		});
	}

	public def setup(json:JSON.Value, sim:Simulator):OrderMistakeShock {
		val market = sim.getMarketByName(json("target"));
		val agent = sim.getAgentsByName("agents")(0); // Use the first one.
		val t = market.getTime();
		this.marketId = market.id;
		this.agentId = agent.id;
		this.triggerTime = t + json("triggerTime").toLong();
		this.priceChangeRate = json("priceChangeRate").toDouble();
		this.orderVolume = json("orderVolume").toLong();
		this.orderTimeLength = json("orderTimeLength").toLong();
		market.addBeforeSimulationStepEvent(this);
		return this;
	}
}
