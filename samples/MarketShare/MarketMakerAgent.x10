package samples.MarketShare;
import x10.util.List;
import x10.util.ArrayList;
import plham.HighFrequencyAgent;
import plham.Market;
import plham.Order;

public class MarketMakerAgent extends HighFrequencyAgent {

	public var targetMarketId:Long;
	public var netInterestSpread:Double;
	public var orderTimeLength:Long;

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
