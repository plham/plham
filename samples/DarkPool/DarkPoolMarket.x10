package samples.DarkPool;
import x10.util.List;
import x10.util.Random;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import plham.util.JSON;

public class DarkPoolMarket extends Market {

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):DarkPoolMarket {
		assert json("markets").size() == 1;
		super.setup(json, sim);
		val lit = sim.getMarketByName(json("markets")(0));
		this.setLitMarket(lit);
		return this;
	}
	public static def register(sim:Simulator):void {
		val className = "DarkPoolMarket";
		sim.addMarketInitializer(className, (id:Long, name:String, random:Random, json:JSON.Value) => {
			return new DarkPoolMarket(id, name, random).setup(json, sim);
		});
	}

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
