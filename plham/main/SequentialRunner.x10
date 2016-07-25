package plham.main;
import x10.util.List;
import x10.util.ArrayList;
import cassia.util.random.RandomPermutation;
import plham.Agent;
import plham.HighFrequencyAgent;
import plham.Env;
import plham.Fundamentals;
import plham.IndexMarket;
import plham.Market;
import plham.Order;

/**
 * A Runner class for sequential execution.
 */
public class SequentialRunner[B]{B <: Simulator} extends Runner[B] {
	
	public def this(sim:B) {
		super(sim);
	}
	
	public def updateMarkets(maxNormalOrders:Long, maxHifreqOrders:Long, diffPass:Boolean) { 
		val orders = collectOrders(maxNormalOrders);
		handleOrders(orders, maxHifreqOrders);
	}
	
	public def collectOrders(MAX_NORMAL_ORDERS:Long):List[List[Order]] {
		val env = this.env();
		val markets = env.markets;
		val agents = env.normalAgents;
		
		val beginTime = System.nanoTime();
		val allOrders = new ArrayList[List[Order]]();

		val random = sim.getRandom();
		val randomAgents = new RandomPermutation[Agent](random, agents);

		var k:Long = 0;
		randomAgents.shuffle();
		for (agent in randomAgents) {
			if (k >= MAX_NORMAL_ORDERS) {
				break;
			}
			val orders = agent.submitOrders(markets);
			if (orders.size() > 0) {
				allOrders.add(orders);
				k++;
			}
		}
		val endTime = System.nanoTime();
		if (_PROFILE) {
			Console.OUT.println("#PROFILE ORDER-MAKE TOTAL " + ((endTime - beginTime) / 1e+9) + " sec");
			Console.OUT.println("#PROFILE MAX-NORMAL-ORDERS " + MAX_NORMAL_ORDERS);
			Console.OUT.println("#PROFILE NUM-NORMAL-ORDERS " + allOrders.size());
		}
		return allOrders;
	}
}
