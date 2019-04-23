package samples.DarkPool;
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
 * Reference: Mizuta, Kosugi, Kusumoto, Matsumoto, Izumi (2014) Analysis of the impact of dark pool to the market efficiency using an artificial market (in Japanese).
 */
public class DarkPoolMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new DarkPoolMain();
		DarkPoolFCNAgent.register(sim);
		DarkPoolMarket.register(sim);
		new SequentialRunner(sim).run(args);
	}

	public def print(sessionName:String) {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");

		assert markets.size() == 2;
		val lit = getMarketByName("LitMarket"); // Name defined in JSON file.
		val dark = getMarketByName("DarkPoolMarket");
		var tradePrice:Double = Double.NaN;
		if (dark.getTradeVolume() > 0) {
			tradePrice = dark.getPrice();
		} else if (lit.getTradeVolume() > 0) {
			tradePrice = lit.getPrice();
		}

		for (market in markets) {
			val t = market.getTime();
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				//
				tradePrice,
				market.getTradeVolume(),
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}
}
