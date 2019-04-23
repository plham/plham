package plham.agent;

import x10.compiler.NonEscaping;
import x10.util.ArrayList;
import x10.util.Indexed;
import x10.util.HashMap;
import x10.util.List;
import x10.util.Map;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.OrderBook;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;

public class TestAgent extends Agent {
	public def this(id:Long) = super(id, "test-agent", new Random());
	public def submitOrders(markets:List[Market]) {
		val MARGIN_SCALE = 10.0;
		val VOLUME_SCALE = 100;
		val TIME_LENGTH_SCALE = 100;
		val BUY_CHANCE = 0.4;
		val SELL_CHANCE = 0.4;

		val orders = new ArrayList[Order]();
		
		for (market in markets) {
			if (this.isMarketAccessible(market)) {
				val random = getRandom();
				val marketTime = market.getTime();
				val price = market.getPrice() + (random.nextDouble() * 2 * MARGIN_SCALE - MARGIN_SCALE);
				val volume = random.nextLong(VOLUME_SCALE) + 1;
				val timeLength = random.nextLong(TIME_LENGTH_SCALE) + 10;
				val p = random.nextDouble();
				if (p < BUY_CHANCE) {
					orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this.id, market.id, price, volume, timeLength, marketTime));
				} else if (p < BUY_CHANCE + SELL_CHANCE) {
					orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this.id, market.id, price, volume, timeLength, marketTime));
				}
			}
		}
		return orders;
	}
}
