package plham.event;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import plham.util.JSON;

import x10.util.Random;

public class PriceLimitRule implements Market.OrderEvent {

	public val id:Long;
	public val name:String;
	public val random:Random;
	public var referenceMarketId:Long;
	public var referencePrice:Double;
	public var triggerChangeRate:Double;
	public var activationCount:Long;

	public def this(id:Long, name:String, random:Random) {
		this.id = id;
		this.name = name;
		this.random = random;
//		this.referenceMarketId = market.id;
//		this.referencePrice = referencePrice;
//		this.triggerChangeRate = triggerChangeRate;
		this.activationCount = 0;
	}

	/** This is for Agents to calculate the modified price within the price limits. */
	public def getLimitedPrice(order:Order, market:Market):Double {
		assert this.referenceMarketId == market.id;
		val orderPrice = order.getPrice();
		val priceChange = orderPrice - this.referencePrice;
		val thresholdChange = this.referencePrice * this.triggerChangeRate;
		if (Math.abs(priceChange) >= Math.abs(thresholdChange)) {
			val maxPrice = this.referencePrice * (1 + this.triggerChangeRate);
			val minPrice = this.referencePrice * (1 - this.triggerChangeRate);
			val limitedPrice = Math.min(Math.max(orderPrice, minPrice), maxPrice);
			return limitedPrice;
		}
		return orderPrice;
	}

	/** This should be called only from the System. */
	public def update(market:Market, order:Order) {
		assert this.referenceMarketId == market.id;
		if (market.isRunning()) {
			// Mizuta etal (2014)'s implementation.
			val oldPrice = order.getPrice();
			val newPrice = this.getLimitedPrice(order, market);
			order.setPrice(newPrice);
			if (newPrice != oldPrice) {
				this.activationCount++;
			}
		}
	}

	public static def register(sim:Simulator):void {
		val name = "PriceLimitRule";
		sim.addEventInitializer(name, (id:Long, name:String, random:Random, json:JSON.Value)=>{
			return new PriceLimitRule(id, name, random).setup(json, sim);
		});
	}

	public def setup(json:JSON.Value, sim:Simulator):PriceLimitRule {
		val referenceMarket = sim.getMarketByName(json("referenceMarket"));
		this.referenceMarketId = referenceMarket.id;
		this.referencePrice = referenceMarket.getPrice();
		this.triggerChangeRate = json("triggerChangeRate").toDouble();
		referenceMarket.addBeforeOrderHandlingEvent(this);
		return this;
	}
}
