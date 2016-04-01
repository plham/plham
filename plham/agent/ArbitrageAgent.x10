package plham.agent;
import x10.util.ArrayList;
import x10.util.List;
import plham.Agent;
import plham.HighFrequencyAgent;
import plham.IndexMarket;
import plham.Market;
import plham.Order;

public class ArbitrageAgent extends HighFrequencyAgent {

	/** The volume of orders to each spot market. */
	public var orderVolume:Long;
	/** Submit orders if the price gap is more than this threshold. */
	public var orderThresholdPrice:Double;
	/** As HFT, the time length of orders should be very short (&lt;= 2). */
	public var orderTimeLength:Long;

	public def this() {
		this.orderVolume = 1;
		this.orderThresholdPrice = 0.0;
		this.orderTimeLength = 2; // An order's lifetime; no rationale.
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();
		for (market in markets) {
			orders.addAll(this.submitOrders(market));
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
}
