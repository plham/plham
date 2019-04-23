package samples.ShockTransfer;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Event;
import plham.IndexMarket;
import plham.Main;
import plham.Market;
import plham.agent.FCNAgent;
import plham.event.FundamentalPriceShock;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;
import plham.util.*;

public class ShockTransferMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new ShockTransferMain();
		FCNAgent.register(sim);
		Market.register(sim);
		ArbitrageAgent.register(sim);
		IndexMarket.register(sim);
		SimpleMarketGenerator.register(sim);
		AgentGeneratorForEachMarket.register(sim);
		FundamentalPriceShock.register(sim);
		new SequentialRunner(sim).run(args);
	}

	public def print(sessionName:String) {
		val markets = getMarketsByName("markets");
		for (market in markets) {
			val t = market.getTime();
			var marketIndex:Double = Double.NaN;
			if (market instanceof IndexMarket) {
				marketIndex = (market as IndexMarket).getIndex(t);
			}
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				marketIndex,
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

}
