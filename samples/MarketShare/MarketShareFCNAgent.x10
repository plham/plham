package samples.MarketShare;
import x10.util.Indexed;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.Random;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.main.Simulator;
import plham.util.Statistics;
import plham.util.JSON;

public class MarketShareFCNAgent extends FCNAgent {

	public def this(id:Long, name:String, random:Random) = super(id, name, random);
	public def setup(json:JSON.Value, sim:Simulator):MarketShareFCNAgent = super.setup(json, sim) as MarketShareFCNAgent;
	public static def register(sim:Simulator):void {
		val className = "MarketShareFCNAgent";
		sim.addAgentInitializer(className,
			(
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				return new MarketShareFCNAgent(id, name, random).setup(json, sim);
			}
		);
	}

	public def submitOrders(var markets:List[Market]):List[Order] {
		markets = filterMarkets(markets);
		val weights = new ArrayList[Double]();
		for (m in markets) {
			weights.add(getSumTradeVolume(m));
		}
		val k = Statistics.roulette(getRandom(), weights);
		return super.submitOrders(markets(k));
	}

	public def getSumTradeVolume(market:Market):Long {
		val t = market.getTime();
		val timeWindowSize = Math.min(t, this.timeWindowSize);
		var volume:Long = 0;
		for (d in 1..timeWindowSize) {
			volume += market.getTradeVolume(t - d);
		}
		return volume;
	}

	public def filterMarkets(markets:List[Market]):List[Market] {
		val a = new ArrayList[Market]();
		for (market in markets) {
			if (this.isMarketAccessible(market)) {
				a.add(market);
			}
		}
		return a;
	}
}
