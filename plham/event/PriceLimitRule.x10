package plham.event;
import plham.Market;
import plham.Order;

public class PriceLimitRule implements Market.OrderEvent {

	public var referenceMarketId:Long;
	public var referencePrice:Double;
	public var triggerChangeRate:Double;
	public var activationCount:Long;

	public def this() {
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
}
