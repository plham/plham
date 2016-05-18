package samples.DarkPool;
import x10.util.List;
import x10.util.ArrayList;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.util.RandomHelper;

public class DarkPoolFCNAgent extends FCNAgent {

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
