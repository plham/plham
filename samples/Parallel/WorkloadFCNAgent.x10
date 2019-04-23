package samples.Parallel;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.Env;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.main.Simulator;
import plham.util.BlackScholes;
import plham.util.JSON;
import plham.util.JSONRandom;

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

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):WorkloadFCNAgent {
		super.setup(json, sim);
		this.hasWorkload = Boolean.parse(Env.getenvOrElse("BS_WORKLOAD", "false"));
		this.bsNSamples = Long.parse(Env.getenvOrElse("BS_NSAMPLES", "0"));
		this.bsNSteps = Long.parse(Env.getenvOrElse("BS_NSTEPS", "0"));
		this.orderRate = Double.parse(Env.getenvOrElse("ORDER_RATE", "0.1"));
		return this;
	}

	public def submitOrders(market:Market):List[Order] {
		if (!this.isMarketAccessible(market)) {
			return new ArrayList[Order](0);
		}
		if (this.hasWorkload) {
			val bs = new BlackScholes(getRandom(), 100.0, 100.0, 0.1, 0.3, 3);
			val price = bs.compute(this.bsNSamples, this.bsNSteps);
			this.bsSum += price;
		}
		if (getRandom().nextDouble() > this.orderRate) {
			return new ArrayList[Order](0); // No order
		}
		return super.submitOrders(market);
	}

/*	public def setupWorkloadFCNAgent(json:JSON.Value, random:JSONRandom, sim:Simulator) {
		setupFCNAgent(json, random, sim);
		this.hasWorkload = Boolean.parse(Env.getenvOrElse("BS_WORKLOAD", "false"));
		this.bsNSamples = Long.parse(Env.getenvOrElse("BS_NSAMPLES", "0"));
		this.bsNSteps = Long.parse(Env.getenvOrElse("BS_NSTEPS", "0"));
		this.orderRate = Double.parse(Env.getenvOrElse("ORDER_RATE", "0.1"));
		return this;
	}*/

	static public def register(sim:Simulator) {
		val className = "WorkloadFCNAgent";
		sim.addAgentInitializer(className,
			(
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				return new WorkloadFCNAgent(id, name, random).setup(json, sim);
			}
		);
	}

/*	public static def createWorkloadFCNAgent(json:JSON.Value, sim:Simulator):WorkloadFCNAgent {
		val random = new JSONRandom(sim.getRandom());
		return new WorkloadFCNAgent().setupWorkloadFCNAgent(json, random, sim);
	}*/
}
