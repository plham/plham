package samples.MarketShare;
import x10.util.List;
import x10.util.ArrayList;
import plham.Market;
import plham.Order;
import plham.agent.FCNAgent;
import plham.util.Statistics;

public class MarketShareFCNAgent extends FCNAgent {

	public def submitOrders(markets:List[Market]):List[Order] {
		val M = filterMarkets(markets);
		val weights = new ArrayList[Double]();
		for (m in M) {
			weights.add(getSumTradeVolume(m));
		}
		val k = Statistics.roulette(getRandom(), weights);
		val market = M(k);
		return super.submitOrders(market);
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
