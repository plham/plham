package samples.DarkPool;
import x10.util.List;
import plham.Market;
import plham.Order;

public class DarkPoolMarket extends Market {

	public var litMarketId:Long;

	public def handleOrders(orders:List[Order]) {
		if (isRunning()) { // Accept only if market is open.
			super.handleOrders(orders);
		}
	}

	public def handleOrder(order:Order) {
		if (isRunning()) { // Accept only if market is open.
			super.handleOrder(order);
		}
	}

	protected def executeBuyOrders(buyOrder:Order, sellOrder:Order) {
		assert buyOrder.getPrice() == Order.NO_PRICE : "The price must be Order.NO_PRICE"; // Check it now (easy impl)
		assert sellOrder.getPrice() == Order.NO_PRICE : "The price must be Order.NO_PRICE";
		executeOrders(roundSellPrice(getLitMidPrice()), buyOrder, sellOrder, true); // Always use the mid price.
	}
	
	protected def executeSellOrders(sellOrder:Order, buyOrder:Order) {
		assert buyOrder.getPrice() == Order.NO_PRICE : "The price must be Order.NO_PRICE"; // Check it now (easy impl)
		assert sellOrder.getPrice() == Order.NO_PRICE : "The price must be Order.NO_PRICE";
		executeOrders(roundBuyPrice(getLitMidPrice()), buyOrder, sellOrder, false); // Always use the mid price.
	}

	public def getLitMarket():Market = this.env.markets(this.litMarketId);

	public def setLitMarket(market:Market):Long = this.litMarketId = market.id;

	public def getLitMidPrice():Double {
		val lit = getLitMarket();
		var litPrice:Double = lit.getMidPrice();
		if (litPrice.isNaN()) { // If the lit's orderbooks are empty.
			litPrice = getLitMarket().getPrice();
		}
		return litPrice;
	}
}
