package samples.CancelTest;
import x10.util.List;
import plham.Market;
import plham.Order;
import plham.Cancel;
import plham.agent.FCNAgent;

public class CancelFCNAgent extends FCNAgent {

	// This enables automated order numbering.
	// Use this hack if you wanna send cancel requests.
	public var orderId:Long = 1;
	public def nextOrderId():Long {
		return orderId++;
	}

	public def submitOrders(market:Market):List[Order] {
		val orders = super.submitOrders(market);
		if (orders.size() == 0) {
			return orders;
		}

		val CANCEL_RATE = 0.3;
		for (o in orders.clone()) {
			if (random.nextDouble() < CANCEL_RATE) {
				orders.add(new Cancel(o));
			}
		}
		return orders;
	}
}
