package samples.CI2002;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Main;
import plham.Market;
import plham.agent.FCNAgent;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.main.SequentialRunner;

public class CI2002Main extends Main {

	public static def main(args:Rail[String]) {
		val sim = new CI2002Main();
		FCNAgent.register(sim);
		Market.register(sim);
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
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}
}
