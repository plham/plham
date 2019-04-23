package samples.MarketShare;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Market;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;

/**
 * Reference: Kusada, Mizuta, Hayakawa, Izumi, Yoshimura (2014) Analysis of the market makers spread's impact to markets volume shares using an artificial market (in Japanese).
 */
public class MarketShareMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new MarketShareMain();
		MarketMakerAgent.register(sim);
		MarketShareFCNAgent.register(sim);
		new SequentialRunner(sim).run(args);
	}

	public def print(sessionName:String) {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");
		for (market in markets) {
			val t = market.getTime();
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				market.getTradeVolume(t),
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

}
