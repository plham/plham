package samples.InvestDiv;
import x10.util.List;
import x10.util.ArrayList;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;

/** The regulation for investment diversification. */
public class InvestDivFCNAgent extends FCNAgent {

	public var leverageRatio:Double;
	public var diversityRatio:Double;

	public def filterMarkets(markets:List[Market]):List[Market] {
		val a = new ArrayList[Market]();
		for (market in markets) {
			if (this.isMarketAccessible(market)) {
				a.add(market);
			}
		}
		return a;
	}

	public def getAssetValue(market:Market):Double {
		return market.getPrice() * getAssetVolume(market);
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val leverageRatio = 1.0;
		val m = filterMarkets(markets);
		var nav:Double = getCashAmount(); // netAssetValue
		var tavAbs:Double = 0.0; // totalAssetValueAbs
		for (market in m) {
			val av = getAssetValue(market);
			nav += av;
			tavAbs += Math.abs(av);
		}

		val orders = new ArrayList[Order]();

		//** The leverage constraint (wait utill the prices recover) **//
		if (tavAbs > leverageRatio * nav) {
			return orders;
		}

		//** A simple reaction for the diversity constraint **//
		val temp = super.submitOrders(m);
		for (order in temp) {
			val id = order.marketId;
			val market = markets(id);
			assert market.id == id;

			val avAbs = Math.abs(getAssetValue(market));
			if (avAbs <= diversityRatio * nav) {
				orders.add(order);
			} else {
				val timeLength = 10; // No effect (any value > 0 okay)
				val orderPrice = Order.NO_PRICE;
				val orderVolume = 1; // No optimization
				if (getAssetVolume(market) < 0) {
					orders.add(new Order(Order.KIND_BUY_MARKET_ORDER, this, market, orderPrice, orderVolume, timeLength));
				}
				if (getAssetVolume(market) > 0) {
					orders.add(new Order(Order.KIND_SELL_MARKET_ORDER, this, market, orderPrice, orderVolume, timeLength));
				}
			}
		}
		return orders;
	}
}
