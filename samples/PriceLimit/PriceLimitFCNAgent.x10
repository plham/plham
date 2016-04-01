package samples.PriceLimit;
import x10.util.List;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.event.PriceLimitRule;

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
}
