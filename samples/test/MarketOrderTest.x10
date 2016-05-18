package samples.test;
import x10.util.Random;
import plham.Agent;
import plham.Env;
import plham.Market;
import plham.Order;
import plham.OrderBook;
import plham.util.RandomHelper;
import plham.util.RandomOrderGenerator;

public class MarketOrderTest {

	public static def main(args:Rail[String]) {

		val random = new RandomHelper(new Random()); // MEMO: main()

		val market = new Market(0);
		market.setInitialMarketPrice(300.0);
		market.setInitialFundamentalPrice(300.0);
		market.setOutstandingShares(10000);
//		market.updateTime();
		market.env = new Env();

		val agent = new Agent(0);
		agent.setMarketAccessible(market);

		market.env.agents.add(agent);
		
		val rog = new RandomOrderGenerator(
				(p:Double) => Math.max(0.0, p + random.nextGaussian() * 10),
				() => 1,
				() => random.nextLong(100) + 10);

		val orders = rog.get(market, () => agent, 100);
		market.handleOrders(orders);

		Console.OUT.println("######## SELL SIDE ########");
		market.getSellOrderBook().dump(OrderBook.HIGHERS_FIRST);
		Console.OUT.println("######## BUY  SIDE ########");
		market.getBuyOrderBook().dump(OrderBook.HIGHERS_FIRST);

		val N = 40;

		market.handleOrder(new Order(Order.KIND_BUY_MARKET_ORDER, agent, market, Order.NO_PRICE, N, 1));
		market.handleOrder(new Order(Order.KIND_SELL_MARKET_ORDER, agent, market, Order.NO_PRICE, N, 1));

		Console.OUT.println("######## SELL SIDE ########");
		market.getSellOrderBook().dump(OrderBook.HIGHERS_FIRST);
		Console.OUT.println("######## BUY  SIDE ########");
		market.getBuyOrderBook().dump(OrderBook.HIGHERS_FIRST);
		Console.OUT.println("# TOP " + (N + N) + "/100 ORDERS ARE EXECUTED BY MARKET ORDERS");
	}
}

