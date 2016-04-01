package samples.CancelTest;
import x10.util.List;
import plham.Market;
import plham.Order;
import plham.Cancel;
import plham.agent.FCNAgent;

public class CancelFCNAgent extends FCNAgent {

	public def submitOrders(market:Market):List[Order] {
		val orders = super.submitOrders(market);
		if (orders.size() == 0) {
			return orders;
		}

		val CANCEL_RATE = 0.3;
		for (o in orders) {
			if (random.nextDouble() < CANCEL_RATE) {
				orders.add(new Cancel(o));
			}
		}
		return orders;
	}
}
