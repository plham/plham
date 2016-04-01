package samples.Parallel;
import x10.util.ArrayList;
import x10.util.List;
import plham.Agent;
import plham.Env;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.util.BlackScholes;

/**
 * An Agent class mimicking the burden of Monte Carlo simulations,
 * currently by solving the Black-Scholes equation.
 */
public class WorkloadFCNAgent extends FCNAgent {

	public var hasWorkload:Boolean;
	public var bsNSamples:Long;
	public var bsNSteps:Long;
	public var bsSum:Double;
	public var orderRate:Double;

	public def submitOrders(market:Market):List[Order] {
		val orders = new ArrayList[Order]();
		if (!this.isMarketAccessible(market)) {
			return orders;
		}
		if (this.hasWorkload) {
			val bs = new BlackScholes(getRandom(), 100.0, 100.0, 0.1, 0.3, 3);
			val price = bs.compute(this.bsNSamples, this.bsNSteps);
			this.bsSum += price;
		}
		if (random.nextDouble() > this.orderRate) {
			return orders; // No order
		}
		return this.submitOrders(market);
	}
}
