package samples.CancelTest;
import x10.util.List;
import x10.util.Random;
import plham.Market;
import plham.Order;
import plham.Cancel;
import plham.agent.FCNAgent;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;

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
			if (this.getRandom().nextDouble() < CANCEL_RATE) {
				orders.add(new Cancel(o));
			}
		}
		return orders;
	}

	public def this(id:Long, name:String, random:Random) = super(id, name, random);

	public def setup(json:JSON.Value, sim:Simulator):CancelFCNAgent {
		return super.setup(json, sim) as CancelFCNAgent;
	}

	public static def register(sim:Simulator):void {
		val className = "CancelFCNAgent";
		sim.addAgentInitializer(className,
			(
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				return new CancelFCNAgent(id, name, random).setup(json, sim);
			}
		);
	}
}
